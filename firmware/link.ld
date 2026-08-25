OUTPUT_ARCH(riscv)
ENTRY(_start)
MEMORY { IMEM (rx) : ORIGIN = 0x00000000, LENGTH = 512 }
SECTIONS {
  .text : {
    KEEP(*(.text.start))
    *(.text*) *(.rodata*)
  } > IMEM
  .data : { *(.data*) *(.bss*) } > IMEM
}
