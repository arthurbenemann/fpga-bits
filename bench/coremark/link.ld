MEMORY { PSRAM (rwx) : ORIGIN = 0x41000000, LENGTH = 8M }
ENTRY(_start)
SECTIONS {
  .text : { *(.text.start) *(.text*) *(.rodata*) *(.srodata*) } > PSRAM
  .data : { *(.data*) *(.sdata*) } > PSRAM
  .bss  : { __bss_start = .; *(.bss*) *(.sbss*) *(COMMON); . = ALIGN(4); __bss_end = .; } > PSRAM
  __stack_top = ORIGIN(PSRAM) + LENGTH(PSRAM);
}
