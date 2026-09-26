// UART bootloader (BRAM image). Host side: load.py. Commands:
//   0x01 <length: 4 bytes LE><bytes>  store at PSRAM_BASE and jump there
//   0x02 <length: 4 bytes LE><bytes>  store a program bundle at BUNDLE
//   '1'..'9'                          copy that bundle program to PSRAM_BASE, jump
//   any other byte                    list the bundle again
// Programs built with psram.ld jump back here when main() returns.
#include <stdint.h>

#define IO_BASE      0x400000
#define IO_UART_DAT  8
#define IO_UART_CNTL 16
#define IO_UART_RX   1024

#define IO_IN(port)       *(volatile uint32_t *)(IO_BASE + port)
#define IO_OUT(port, val) *(volatile uint32_t *)(IO_BASE + port) = (val)

#define PSRAM_BASE   0x800000u
#define BUNDLE       0xF00000u      // top 1 MB of PSRAM
#define BUNDLE_END   0x1000000u
#define BUNDLE_MAGIC 0x4C444E42u    // "BNDL"

// Bundle: magic, then per program an entry followed by its bytes padded to 4,
// then an entry with len 0.
struct entry { uint32_t len; char name[12]; };  // name NUL-terminated

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

static void receive(volatile uint8_t *dst)
{
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
}

static struct entry *next(struct entry *e)
{
    return (struct entry *)((char *)(e + 1) + ((e->len + 3) & ~3u));
}

// Lists the bundle; returns its program count (0: no bundle).
static uint32_t menu(void)
{
    if (*(volatile uint32_t *)BUNDLE != BUNDLE_MAGIC) return 0;
    uint32_t n = 0;
    for (struct entry *e = (struct entry *)(BUNDLE + 4);
         n < 9 && e->len && (uint32_t)next(e) < BUNDLE_END; e = next(e)) {
        tx(' '); tx('1' + n++); tx(' ');
        tx_str(e->name);
        tx_str("\r\n");
    }
    if (n) { tx_str("boot: key 1-"); tx('0' + n); tx_str(" runs a program\r\n"); }
    return n;
}

int main()
{
    tx_str("\r\nboot: waiting for image\r\n");
    for (uint32_t n = menu();; n = menu()) {
        uint32_t c = rx();
        if (c == 1) break;
        if (c == 2) receive((volatile uint8_t *)BUNDLE);
        if (c - '1' < n) {
            struct entry *e = (struct entry *)(BUNDLE + 4);
            while (c-- > '1') e = next(e);
            uint32_t *src = (uint32_t *)(e + 1), *dst = (uint32_t *)PSRAM_BASE;
            for (uint32_t i = 0; i < (e->len + 3) >> 2; ++i) dst[i] = src[i];
            tx_str("boot: run ");
            tx_str(e->name);
            tx_str("\r\n");
            ((void (*)(void))PSRAM_BASE)();
        }
    }
    receive((volatile uint8_t *)PSRAM_BASE);
    ((void (*)(void))PSRAM_BASE)();
    return 0;
}
