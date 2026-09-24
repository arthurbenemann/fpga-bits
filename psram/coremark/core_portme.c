/* CoreMark port for the PSRAM SoC. Timer: the SoC's free-running 12 MHz
   cycle counter. Output: the SoC UART. Based on barebones/core_portme.c. */
#include "coremark.h"
#include "core_portme.h"

#define IO_BASE          0x400000
#define IO_REG(off)      (*(volatile ee_u32 *)(IO_BASE + (off)))
#define IO_UART_DAT      IO_REG(8)
#define IO_UART_CNTL     IO_REG(16)
#define IO_COUNTER       IO_REG(32)
#define EE_TICKS_PER_SEC 12000000

#if VALIDATION_RUN
volatile ee_s32 seed1_volatile = 0x3415;
volatile ee_s32 seed2_volatile = 0x3415;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PERFORMANCE_RUN
volatile ee_s32 seed1_volatile = 0x0;
volatile ee_s32 seed2_volatile = 0x0;
volatile ee_s32 seed3_volatile = 0x66;
#endif
#if PROFILE_RUN
volatile ee_s32 seed1_volatile = 0x8;
volatile ee_s32 seed2_volatile = 0x8;
volatile ee_s32 seed3_volatile = 0x8;
#endif
volatile ee_s32 seed4_volatile = ITERATIONS;
volatile ee_s32 seed5_volatile = 0;

ee_u32 default_num_contexts = 1;

static CORETIMETYPE start_time_val, stop_time_val;

void start_time(void)
{
    start_time_val = IO_COUNTER;
}

void stop_time(void)
{
    stop_time_val = IO_COUNTER;
}

CORE_TICKS get_time(void)
{
    return stop_time_val - start_time_val;
}

secs_ret time_in_secs(CORE_TICKS ticks)
{
    return (secs_ret)ticks / (secs_ret)EE_TICKS_PER_SEC;
}

void portable_init(core_portable *p, int *argc, char *argv[])
{
    (void)argc;
    (void)argv;
    p->portable_id = 1;
}

void portable_fini(core_portable *p)
{
    p->portable_id = 0;
}

void uart_send_char(char c)
{
    if (c == '\n') uart_send_char('\r');
    while (IO_UART_CNTL & (1 << 9));
    IO_UART_DAT = c;
}
