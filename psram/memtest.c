#include <stdint.h>

#define IO_BASE      0x400000
#define IO_LEDS      4
#define IO_COUNTER   32
#define IO_PSRAM_CMD 64
#define IO_PSRAM_DAT 128

#define IO_IN(port)       *(volatile uint32_t *)(IO_BASE + port)
#define IO_OUT(port, val) *(volatile uint32_t *)(IO_BASE + port) = (val)

#define CMD_WRITE 0x02
#define CMD_READ  0x03
#define CMD_ID    0x9F

#define PSRAM_SIZE (8u << 20)
#define CLK_KHZ    12000

int printf(const char *fmt, ...);
int putchar(int c);

static uint32_t psram_xfer(uint32_t cmd, uint32_t addr)
{
    IO_OUT(IO_PSRAM_CMD, (cmd << 24) | addr);
    while (IO_IN(IO_PSRAM_CMD) & 1);
    return IO_IN(IO_PSRAM_DAT);
}

static void psram_write(uint32_t addr, uint32_t v)
{
    IO_OUT(IO_PSRAM_DAT, v);
    psram_xfer(CMD_WRITE, addr);
}

static uint32_t psram_read(uint32_t addr)
{
    return psram_xfer(CMD_READ, addr);
}

// Unique per word, and exercises the high bits even for low addresses.
static uint32_t pattern(uint32_t addr)
{
    return (addr << 8) ^ addr ^ 0xA5C3F00Fu;
}

int main()
{
    printf("\r\nPSRAM memtest, %d KB\r\n", PSRAM_SIZE >> 10);
    printf("ID: %x (expect 0D5D....)\r\n", psram_xfer(CMD_ID, 0));

    for (uint32_t pass = 0;; ++pass) {
        uint32_t invert = (pass & 1) ? 0xFFFFFFFFu : 0;

        uint32_t t0 = IO_IN(IO_COUNTER);
        for (uint32_t a = 0; a < PSRAM_SIZE; a += 4) {
            if ((a & 0x7FFFF) == 0) putchar('.');
            psram_write(a, pattern(a) ^ invert);
        }
        uint32_t t1 = IO_IN(IO_COUNTER);

        uint32_t errors = 0;
        for (uint32_t a = 0; a < PSRAM_SIZE; a += 4) {
            if ((a & 0x7FFFF) == 0) putchar('.');
            uint32_t want = pattern(a) ^ invert;
            uint32_t got = psram_read(a);
            if (got != want) {
                if (errors < 8) printf("\r\n  %x: got %x want %x", a, got, want);
                ++errors;
            }
        }
        uint32_t t2 = IO_IN(IO_COUNTER);

        printf("\r\npass %d: %d errors, write %d ms, read %d ms\r\n",
               pass, errors, (t1 - t0) / CLK_KHZ, (t2 - t1) / CLK_KHZ);
        IO_OUT(IO_LEDS, errors ? 0x1F : pass);
    }
}
