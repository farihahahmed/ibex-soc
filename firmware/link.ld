OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { IMEM (rx) : ORIGIN = 0x00000080, LENGTH = 1K }
SECTIONS {
  .text : { *(.text*) *(.rodata*) } > IMEM
  .data : { *(.data*) *(.bss*) } > IMEM
}
