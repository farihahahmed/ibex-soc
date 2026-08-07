OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 256 }
SECTIONS {
  .text : { *(.text*) *(.rodata*) } > IMEM
  .data : { *(.data*) *(.bss*) } > IMEM
}
