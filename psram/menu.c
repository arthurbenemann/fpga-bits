// Boot menu (bundle program 0; see boot.c): up/down + Enter (or the item's number)
// picks a program, which boot_entry() (fixed BRAM address, entry.s) copies over this
// menu and runs. Last item: Doom from flash.
// Bytes 1 and 2 on the UART are load.py uploads (single image / bundle): passed to
// boot_entry() as they are, like the raw bootloader does.
#include <stdint.h>
#include "fbcon.h"
#include "cpuhz.h"
#include "boot_entry.h"

int printf(const char *fmt, ...);

#define IO_BASE       0x400000
#define IO_FLASH_ADDR (*(volatile uint32_t *)(IO_BASE + 8192))
#define IO_FLASH_DATA (*(volatile uint32_t *)(IO_BASE + 16384))
#define IO_FLASH_END  (*(volatile uint32_t *)(IO_BASE + 32768))

#define BUNDLE      0xF00000u
#define BUNDLE_END  0x1000000u
#define FLASH_DOOM_ADDR  0x200000u
#define FLASH_DOOM_MAGIC 0x4D4F4F44u  // "DOOM"

struct entry { uint32_t len; char name[12]; };

static struct entry *next(struct entry *e)
{
    return (struct entry *)((char *)(e + 1) + ((e->len + 3) & ~3u));
}

static void put(const char *s) { while (*s) con_putc(*s++); }

static void putn(uint32_t n, int width)
{
    char b[12];
    int i = 11;
    b[i] = 0;
    do b[--i] = '0' + n % 10; while (n /= 10);
    for (int w = 11 - i; w < width; ++w) con_putc(' ');
    put(b + i);
}

static struct { const char *name; uint32_t kb; } item[12];
static int n, nprog, doom = -1;

static uint32_t flash_doom_kb(void)
{
    IO_FLASH_ADDR = FLASH_DOOM_ADDR;
    while (!(IO_FLASH_ADDR & 1));
    uint32_t magic = IO_FLASH_DATA;
    while (!(IO_FLASH_ADDR & 1));
    uint32_t len = IO_FLASH_DATA;
    IO_FLASH_END = 0;
    return magic == FLASH_DOOM_MAGIC ? (len + 1023) >> 10 : 0;
}

static void draw(int sel)
{
    int turbo = CPU_HZ > 20000000;
    con_at(0, 0);
    put("iCEBreaker RISC-V\n\n");
    for (int i = 0; i < n; ++i) {
        con_at(0, 2 + i);
        put("                                        ");
        con_at(0, 2 + i);
        con_putc(i == sel ? '>' : ' ');
        con_putc(' '); putn(i + 1, 0); con_putc(' ');
        put(item[i].name);
        if (item[i].kb) { con_at(31, 2 + i); putn(item[i].kb, 4); put(" KB"); }
    }
    con_at(0, 3 + n);
    put(turbo ? "CPU 25 MHz (turbo)\n" : "CPU 12.5 MHz (safe)\n");
    con_at(0, 24);
    put("up/down + Enter, or the number");
}

int main(void)
{
    con_init();
    printf("iCEBreaker RISC-V -- pick a program\r\n\r\n");
    struct entry *e = (struct entry *)(BUNDLE + 4);
    for (e = next(e); e->len && (uint32_t)next(e) < BUNDLE_END && n < 9; e = next(e), ++n) {
        item[n].name = e->name;
        item[n].kb = (e->len + 1023) >> 10;
        printf("%d %s (%d KB)\r\n", n + 1, e->name, item[n].kb);
    }
    nprog = n;
    uint32_t dkb = flash_doom_kb();
    if (dkb) {
        doom = n;
        item[n].name = "doom (flash)";
        item[n].kb = dkb;
        printf("%d doom (flash, %d KB)\r\n", ++n, dkb);
    }
    printf("\r\nboot: menu ready\r\n");
    int sel = 0;
    draw(sel);

    for (;;) {
        int k = con_waitkey();
        if (k == 1 || k == 2) ((void (*)(uint32_t))BOOT_ENTRY)(k);
        if (k == K_UP && sel) draw(--sel);
        else if (k == K_DOWN && sel < n - 1) draw(++sel);
        else if (k >= '1' && k <= '9' && k - '1' < n) sel = k - '1', k = 13;
        if (k == 13 || k == ' ') {
            ((void (*)(uint32_t))BOOT_ENTRY)(sel == doom ? 'd' : '1' + sel);
        }
    }
}
