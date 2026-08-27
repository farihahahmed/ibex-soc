.section .text.start, "ax"
.global _start
_start:
    li sp, 0x200        # STACKADDR: top of 512B data memory, grows down
    call main
hang:
    j hang
