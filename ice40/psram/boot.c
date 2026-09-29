// UART bootloader (BRAM image). Host side: load.py. Commands:
//   0x01 <length: 4 bytes LE><bytes>  store at PSRAM_BASE and run it
//   0x02 <length: 4 bytes LE><bytes>  store a program bundle at BUNDLE, then
//                                     run its first image (the menu)
//   'd'                               copy the Doom image from flash to
//                                     PSRAM_BASE and run it (see menu.c)
// On reset, and whenever a program returns (by jumping to address 0, see
// psram.ld/crt_psram.s), runs the bundle's first image if one is stored;
// else tries loading one from flash (see flash_load_bundle()); else waits
// for a UART upload.
//
// The menu (bundle program 0; see menu.c) lists the bundle's other programs
// and runs the one picked. It also reads the UART itself, so a byte it reads
// there might be a fresh 0x01/0x02/'d' command rather than a keypress: it
// hands that byte to boot_entry() below through entry.s, a small fixed BRAM
// entry point, without losing it or the bytes after it. This has to go
// through BRAM code because the menu runs at PSRAM_BASE (like every bundled
// program), and copying a new image there would overwrite the very code
// that's doing the copying.
#include <stdint.h>

#define IO_BASE       0x400000
#define IO_UART_DAT   8
#define IO_UART_CNTL  16
#define IO_UART_RX    1024
#define IO_FLASH_ADDR 8192    // W: (re)start a streamed read at a byte addr;
                              // R: bit 0 is set once a word is ready
#define IO_FLASH_DATA 16384   // R: pops the ready word (see flash_spi.v)
#define IO_FLASH_END  32768   // W: raise CS (any value)

#define IO_IN(port)       *(volatile uint32_t *)(IO_BASE + port)
#define IO_OUT(port, val) *(volatile uint32_t *)(IO_BASE + port) = (val)

#define PSRAM_BASE   0x800000u
#define BUNDLE       0xF00000u      // top 1 MB of PSRAM
#define BUNDLE_END   0x1000000u
#define BUNDLE_MAGIC 0x4C444E42u    // "BNDL"

// Flash layout (see psram/Makefile flash-bundle, doom/Makefile flash):
//   0x100000  1 MB  program bundle, same format as BUNDLE/load.py's bundle()
//   0x200000  up to 14 MB: "DOOM" magic, 4-byte LE length, then the raw image
#define FLASH_BUNDLE_ADDR 0x100000u
#define FLASH_DOOM_ADDR   0x200000u
#define FLASH_DOOM_MAGIC  0x4D4F4F44u  // "DOOM"

static uint32_t flash_word(void)
{
    while (!(IO_IN(IO_FLASH_ADDR) & 1));
    return IO_IN(IO_FLASH_DATA);
}

// Bundle: magic, then per program an entry followed by its bytes padded to 4,
// then an entry with len 0. Program 0 is the menu.
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

// Must keep up with the UART: a byte every 40 CPU cycles (10 bits, 4 clocks each).
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

static int valid_bundle(void)
{
    return *(volatile uint32_t *)BUNDLE == BUNDLE_MAGIC;
}

// Copies bundle program idx to PSRAM_BASE and jumps to it (never returns);
// idx 0 is the menu. Falls back to idx 0 if that program doesn't exist.
static void run_bundle(uint32_t idx)
{
    struct entry *e = (struct entry *)(BUNDLE + 4);
    for (uint32_t i = 0; i < idx && e->len && (uint32_t)next(e) < BUNDLE_END; ++i)
        e = next(e);
    if (idx && !e->len) e = (struct entry *)(BUNDLE + 4);
    uint32_t *src = (uint32_t *)(e + 1), *dst = (uint32_t *)PSRAM_BASE;
    for (uint32_t i = 0; i < (e->len + 3) >> 2; ++i) dst[i] = src[i];
    ((void (*)(void))PSRAM_BASE)();
}

// Reads the bundle at FLASH_BUNDLE_ADDR into BUNDLE (1 MB, always -- the
// bundle format itself says how much of it is used). No-op if flash doesn't
// have a valid one there.
static void flash_load_bundle(void)
{
    IO_OUT(IO_FLASH_ADDR, FLASH_BUNDLE_ADDR);
    uint32_t magic = flash_word();
    if (magic != BUNDLE_MAGIC) { IO_OUT(IO_FLASH_END, 0); return; }
    volatile uint32_t *dst = (volatile uint32_t *)BUNDLE;
    dst[0] = magic;
    for (uint32_t i = 1; i < (BUNDLE_END - BUNDLE) >> 2; ++i) dst[i] = flash_word();
    IO_OUT(IO_FLASH_END, 0);
}

// Copies the Doom image from flash to PSRAM_BASE and jumps to it (never
// returns), or just returns if flash doesn't have a valid image there.
static void flash_load_doom(void)
{
    IO_OUT(IO_FLASH_ADDR, FLASH_DOOM_ADDR);
    uint32_t magic = flash_word();
    if (magic != FLASH_DOOM_MAGIC) { IO_OUT(IO_FLASH_END, 0); return; }
    uint32_t len = flash_word();
    volatile uint32_t *dst = (volatile uint32_t *)PSRAM_BASE;
    for (uint32_t i = 0; i < (len + 3) >> 2; ++i) dst[i] = flash_word();
    IO_OUT(IO_FLASH_END, 0);
    ((void (*)(void))PSRAM_BASE)();
}

// Called through entry.s's fixed BRAM address: cmd is a byte already read
// off the UART, by boot.c's own loop below or by the menu. Never returns,
// except when cmd is none of these (the caller, the menu, just keeps going).
void boot_entry(uint32_t cmd)
{
    if (cmd == 1) {
        receive((volatile uint8_t *)PSRAM_BASE);
        ((void (*)(void))PSRAM_BASE)();
    } else if (cmd == 2) {
        receive((volatile uint8_t *)BUNDLE);
        run_bundle(0);
    } else if (cmd >= '1' && cmd <= '9' && valid_bundle()) {
        run_bundle(cmd - '0');
    } else if (cmd == 'd') {
        flash_load_doom();
    }
}

int main(void)
{
    for (;;) {
        if (!valid_bundle()) flash_load_bundle();
        if (valid_bundle()) run_bundle(0);
        tx_str("\r\nboot: waiting for image\r\n");
        boot_entry(rx());
    }
}
