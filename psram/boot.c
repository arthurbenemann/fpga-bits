// UART bootloader (BRAM image): receives <length: 4 bytes LE><length bytes>,
// stores them at PSRAM_BASE and jumps there. Programs built with psram.ld
// jump back here when main() returns. Host side: load.py.
#include <stdint.h>

#define IO_BASE      0x400000
#define IO_UART_DAT  8
#define IO_UART_CNTL 16
#define IO_UART_RX   1024

#define IO_IN(port)       *(volatile uint32_t *)(IO_BASE + port)
#define IO_OUT(port, val) *(volatile uint32_t *)(IO_BASE + port) = (val)

#define PSRAM_BASE 0x800000u

static void tx(uint32_t c)
{
    while (IO_IN(IO_UART_CNTL) & (1 << 9));
    IO_OUT(IO_UART_DAT, c);
}

static void tx_str(const char *s)
{
    while (*s) tx(*s++);
}

static void tx_hex(uint32_t v)
{
    for (int i = 28; i >= 0; i -= 4) tx("0123456789ABCDEF"[(v >> i) & 15]);
}

// Must keep up with 3 Mbaud: a byte every 40 CPU cycles.
static uint32_t rx(void)
{
    uint32_t c;
    while (!((c = IO_IN(IO_UART_RX)) & 0x100));
    return c & 0xFF;
}

int main()
{
    volatile uint8_t *dst = (volatile uint8_t *)PSRAM_BASE;

    tx_str("\r\nboot: waiting for image\r\n");

    uint32_t n = 0;
    for (int i = 0; i < 32; i += 8) n |= rx() << i;

    uint32_t sum = 0;
    for (uint32_t i = 0; i < n; ++i) {
        uint32_t b = rx();
        dst[i] = b;
        sum += b;
    }
    tx_str("boot: ");
    tx_hex(n);
    tx_str(" bytes, sum ");
    tx_hex(sum);
    tx_str("\r\n");

    ((void (*)(void))PSRAM_BASE)();
    return 0;
}
