// Exercises all seven custom-0 instructions and prints each result as 8 hex
// digits over UART. Values are compared against a Python golden model in
// verification/cocotb/test_pyuvm_pcpi.py.
//
// No string literals or const arrays: .rodata is placed in instruction memory
// by the linker, but data loads on this chip are routed to the AHB data
// memory, so read-only data is not reachable via loads.
#define UART_STATUS (*(volatile unsigned int*)0x00020000)
#define UART_DATA   (*(volatile unsigned int*)0x00020004)
static void putc_(char c){ while(UART_STATUS & 1); UART_DATA = c; }
static void puthex(unsigned v){
    for (int i = 7; i >= 0; i--){
        unsigned n = (v >> (i*4)) & 0xF;
        putc_(n < 10 ? '0'+n : 'a'+n-10);
    }
    putc_(' ');
}

#define CUSTOM(f3, rd, rs1, rs2) \
    asm volatile (".insn r 0x0B, " #f3 ", 0, %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2))

__attribute__((section(".text.start"))) void _start(void){
    unsigned r, a, b;

    // crc32.b : fold "123456789" one byte at a time -> cbf43926 after final xor
    r = 0xFFFFFFFF;
    for (unsigned c = '1'; c <= '9'; c++) { a = r; b = c; CUSTOM(0, r, a, b); }
    puthex(r ^ 0xFFFFFFFF);

    // crc32.w : fold the word 0x34333231 ("1234") in one instruction
    a = 0xFFFFFFFF; b = 0x34333231; CUSTOM(1, r, a, b); puthex(r);

    // popcnt : 0xF0F0F0F0 has 16 bits set
    a = 0xF0F0F0F0; b = 0; CUSTOM(2, r, a, b); puthex(r);

    // brev : reverse 0x0000000F -> 0xF0000000
    a = 0x0000000F; b = 0; CUSTOM(3, r, a, b); puthex(r);

    // mac : clear, then 3*4 + 10*10 + (-1)*5 = 107 = 0x6b  (signed)
    a = 0; b = 0; CUSTOM(6, r, a, b);              // macclr
    a = 3;  b = 4;      CUSTOM(4, r, a, b);
    a = 10; b = 10;     CUSTOM(4, r, a, b);
    a = 0xFFFF; b = 5;  CUSTOM(4, r, a, b);        // -1 * 5, signed
    puthex(r);
    a = 0; b = 0; CUSTOM(5, r, a, b); puthex(r);   // macrd, must match

    putc_('\n');
    for(;;);
}
