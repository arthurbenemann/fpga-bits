// Framebuffer test (load.py fbtest.img). Checks CPU word/halfword/byte access
// to the whole 64 KB, then draws the Mandelbrot set (the accelerator) under a
// cyclic palette inside a white border, and rotates the palette once a frame.
// A key returns to the bootloader.
#include <stdint.h>

#define IO_BASE        0x400000
#define IO_COUNTER     32
#define IO_MANDEL_CTRL 64
#define IO_MANDEL_CR   128
#define IO_MANDEL_CI   256
#define IO_MANDEL_IT   512
#define IO_UART_RX     1024
#define IO_VIDEO       2048     // W palette entry {index << 16 | 0xRGB}, R frames shown

#define IO_IN(port)       *(volatile uint32_t *)(IO_BASE + port)
#define IO_OUT(port, val) *(volatile uint32_t *)(IO_BASE + port) = (val)

#define W    320
#define H    200
#define FB   0x200000
#define fb32 ((volatile uint32_t *)FB)
#define fb16 ((volatile uint16_t *)FB)
#define fb8  ((volatile uint8_t  *)FB)
#define fb8s ((volatile int8_t   *)FB)
#define WORDS 16384             // 64 KB: the 64000-byte screen and 1536 spare bytes

int printf(const char *fmt, ...);

static uint32_t errors;

static void check(const char *what, uint32_t i, uint32_t got, uint32_t want)
{
    if (got != want) {
        if (errors < 8) printf("  %s %d: got %x want %x\r\n", what, i, got, want);
        ++errors;
    }
}

static uint32_t hash(uint32_t i) { return i * 0x9E3779B1u ^ i >> 3; }

static void test_memory(void)
{
    uint32_t t0 = IO_IN(IO_COUNTER);
    for (uint32_t i = 0; i < WORDS; ++i) fb32[i] = hash(i);
    uint32_t t1 = IO_IN(IO_COUNTER);
    for (uint32_t i = 0; i < WORDS; ++i) check("word", i, fb32[i], hash(i));
    uint32_t t2 = IO_IN(IO_COUNTER);
    printf("fb words: write %d, read+check %d cycles per word\r\n", (t1 - t0) / WORDS, (t2 - t1) / WORDS);

    for (uint32_t i = 0; i < 2 * WORDS; ++i) fb16[i] = hash(i) >> 7;
    for (uint32_t i = 0; i < WORDS; ++i)
        check("half", i, fb32[i], (hash(2 * i) >> 7 & 0xFFFF) | hash(2 * i + 1) >> 7 << 16);
    for (uint32_t i = 0; i < 4 * WORDS; ++i) fb8[i] = hash(i) >> 11;
    for (uint32_t i = 0; i < 4 * WORDS; ++i) check("byte", i, fb8[i], hash(i) >> 11 & 0xFF);
    for (uint32_t i = 0; i < 4 * WORDS; ++i) check("lb", i, fb8s[i], (int8_t)(hash(i) >> 11));
    printf("fb test: %d errors\r\n", errors);
}

// Period-64 colour cycle: red, green and blue triangle waves a third apart.
static uint32_t tri(uint32_t k) { k &= 63; return (k < 32 ? k : 63 - k) >> 1; }
static uint32_t colour(uint32_t k) { return tri(k) << 8 | tri(k + 21) << 4 | tri(k + 42); }

static void palette(uint32_t k)     // 0 black (in the set), 1..254 cycled, 255 white
{
    IO_OUT(IO_VIDEO, 0);
    for (uint32_t i = 1; i < 255; ++i) IO_OUT(IO_VIDEO, i << 16 | colour(i + k));
    IO_OUT(IO_VIDEO, 255 << 16 | 0xFFF);
}

#define ONE  (1 << 27)          // Q4.27, as in the accelerator
#define STEP (7 * ONE / 640)    // 3.5 wide over 320 pixels

static void mandel(void)
{
    IO_OUT(IO_MANDEL_IT, 254);
    int ci = -STEP * H / 2;
    for (uint32_t y = 0; y < H; ++y, ci += STEP) {
        int cr = -ONE * 5 / 2;
        for (uint32_t x = 0; x < W; ++x, cr += STEP) {
            IO_OUT(IO_MANDEL_CR, cr);
            IO_OUT(IO_MANDEL_CI, ci);
            IO_OUT(IO_MANDEL_CTRL, 0);
            while (!IO_IN(IO_MANDEL_CTRL));
            uint32_t left = IO_IN(IO_MANDEL_IT);        // 0: in the set
            fb8[y * W + x] = left ? 255 - left : 0;     // 1..254 by iterations
        }
    }
    for (uint32_t x = 0; x < W; ++x) fb8[x] = fb8[(H - 1) * W + x] = 255;
    for (uint32_t y = 0; y < H; ++y) fb8[y * W] = fb8[y * W + W - 1] = 255;
}

int main()
{
    // fb words 0-3 are whatever the previous program (e.g. the menu) left there;
    // the bootloader no longer draws a fixed test pattern.
    printf("\r\nframebuffer test: frames %d, fb words 0-3 %x %x %x %x\r\n",
           IO_IN(IO_VIDEO), fb32[0], fb32[1], fb32[2], fb32[3]);
    test_memory();

    palette(0);
    uint32_t t0 = IO_IN(IO_COUNTER);
    mandel();
    printf("mandel: %d kcycles; rotating the palette (key: quit)\r\n", (IO_IN(IO_COUNTER) - t0) >> 10);

    uint32_t f = IO_IN(IO_VIDEO), t = IO_IN(IO_COUNTER);
    for (uint32_t k = 1;; ++k) {
        while (IO_IN(IO_VIDEO) == f)
            if (IO_IN(IO_UART_RX) & 0x100) return 0;
        f = IO_IN(IO_VIDEO);
        palette(k);
        if (k % 256 == 0) {
            uint32_t now = IO_IN(IO_COUNTER);
            printf("%d frames, %d mHz\r\n", f, (uint32_t)(256ull * CPU_HZ * 1000 / (now - t)));
            t = now;
        }
    }
}
