// PSRAM test, run from PSRAM itself (load.py memtest.img). It tests everything
// above its own image up to the program bundle (top 1 MB, see boot.c); its own
// few KB and the bundle stay untested. A key returns to the bootloader after a pass.
#include <stdint.h>

#define IO_BASE      0x400000
#define IO_LEDS      4
#define IO_COUNTER   32
#define IO_UART_RX   1024

#define IO_IN(port)       *(volatile uint32_t *)(IO_BASE + port)
#define IO_OUT(port, val) *(volatile uint32_t *)(IO_BASE + port) = (val)

#define PSRAM_END  0xF00000u      // BUNDLE in boot.c
#define CLK_KHZ    (CPU_MHZ * 1000)

int printf(const char *fmt, ...);
int putchar(int c);

extern char _end[];                                 // end of this program (psram.ld)
#define BASE (((uint32_t)_end + 0xFFF) & ~0xFFFu)   // first tested byte

#define psram32  ((volatile uint32_t *)BASE)
#define psram16  ((volatile uint16_t *)BASE)
#define psram16s ((volatile int16_t  *)BASE)
#define psram8   ((volatile uint8_t  *)BASE)
#define psram8s  ((volatile int8_t   *)BASE)

static uint32_t errors;

static void check(const char *what, uint32_t got, uint32_t want)
{
    if (got != want) {
        if (errors < 8) printf("\r\n  %s: got %x want %x", what, got, want);
        ++errors;
    }
}

// Unique per word, and exercises the high bits even for low addresses; k is
// 0xA5C3F00F, inverted on odd passes.
#define PATTERN(a, k) ((a) << 8 ^ (a) ^ (k))

// Byte/halfword stores write only their own bytes, little-endian;
// signed loads sign-extend.
static void test_subword(void)
{
    for (uint32_t w = 0; w < 64; ++w) psram32[w] = 0xFFFFFFFFu;

    for (uint32_t i = 0; i < 64; ++i) psram8[i] = i;             // bytes 0..63   = words 0..15
    for (uint32_t i = 32; i < 64; ++i) psram16[i] = 0x8000 | i;   // bytes 64..127 = words 16..31

    for (uint32_t w = 0; w < 16; ++w) {
        uint32_t b = 4 * w;
        check("sb", psram32[w], (b + 3) << 24 | (b + 2) << 16 | (b + 1) << 8 | b);
    }
    for (uint32_t w = 16; w < 32; ++w) {
        uint32_t h = 2 * w;
        check("sh", psram32[w], (0x8000 | (h + 1)) << 16 | (0x8000 | h));
    }
    check("untouched", psram32[32], 0xFFFFFFFFu);

    check("lb  -1",  (uint32_t)(int32_t)psram8s[128], 0xFFFFFFFFu);
    check("lbu 255", psram8[128], 0xFFu);
    check("lb  5",   (uint32_t)(int32_t)psram8s[5], 5);
    check("lh",      (uint32_t)(int32_t)psram16s[32], 0xFFFF8020u);
    check("lhu",     psram16[33], 0x8021u);
}

// Instruction fetch from PSRAM: addi a0,a0,1 ; ret
static void test_exec(void)
{
    volatile uint32_t *code = psram32 + 0x400;
    code[0] = 0x00150513u;
    code[1] = 0x00008067u;
    int (*fn)(int) = (int (*)(int))(code);
    check("exec", fn(41), 42);
}

int main()
{
    printf("\r\nPSRAM test %x..%x, %d KB (key: stop after the pass)\r\n", BASE, PSRAM_END, (PSRAM_END - BASE) >> 10);

    for (uint32_t pass = 0;; ++pass) {
        uint32_t k = (pass & 1) ? ~0xA5C3F00Fu : 0xA5C3F00Fu;

        errors = 0;
        test_subword();
        test_exec();

        uint32_t t0 = IO_IN(IO_COUNTER);
        // Word loops unrolled a cache line at a time; a dot per 512 KB, outside them.
        for (uint32_t a = BASE; a < PSRAM_END; putchar('.')) {
            uint32_t end = (a | 0x7FFFF) + 1;
            #pragma GCC unroll 4
            for (; a < end; a += 4) *(volatile uint32_t *)a = PATTERN(a, k);
        }
        uint32_t t1 = IO_IN(IO_COUNTER);

        for (uint32_t a = BASE; a < PSRAM_END; putchar('.')) {
            uint32_t end = (a | 0x7FFFF) + 1;
            #pragma GCC unroll 4
            for (; a < end; a += 4) {
                uint32_t v = *(volatile uint32_t *)a;
                if (v != PATTERN(a, k)) check("word", v, PATTERN(a, k));
            }
        }
        uint32_t t2 = IO_IN(IO_COUNTER);

        printf("\r\npass %d: %d errors (subword, exec, words), write %d ms, read %d ms\r\n",
               pass, errors, (t1 - t0) / CLK_KHZ, (t2 - t1) / CLK_KHZ);
        IO_OUT(IO_LEDS, errors ? 0x1F : pass);
        if (IO_IN(IO_UART_RX) & 0x100) return 0;
    }
}
