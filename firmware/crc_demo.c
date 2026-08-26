// CRC32 accelerator demo.
// Folds a known string through the custom crc32 instruction and prints the
// result as 8 hex digits over UART. Compare against any standard CRC32
// implementation (zlib, python zlib.crc32) to confirm the hardware matches.
#define UART_STATUS (*(volatile unsigned int*)0x00020000)
#define UART_DATA   (*(volatile unsigned int*)0x00020004)

static void putc_(char c){ while(UART_STATUS & 1); UART_DATA = c; }

// crc32 rd, rs1, rs2  -> custom-0, funct3=000, funct7=0000000
static inline unsigned crc32_step(unsigned crc, unsigned byte){
    unsigned out;
    asm volatile (".insn r 0x0B, 0, 0, %0, %1, %2"
                  : "=r"(out) : "r"(crc), "r"(byte));
    return out;
}

__attribute__((section(".text.start"))) void _start(void){
    // The standard CRC32 check vector "123456789", generated arithmetically.
    // A string literal would live in .rodata, which the linker places in
    // instruction memory - but data loads on this chip are routed to the AHB
    // data memory, so .rodata is not reachable via loads.
    unsigned crc = 0xFFFFFFFF;
    for (unsigned c = '1'; c <= '9'; c++)
        crc = crc32_step(crc, c);
    crc ^= 0xFFFFFFFF;                     // final xor
    for (int i = 7; i >= 0; i--){
        unsigned nib = (crc >> (i*4)) & 0xF;
        putc_(nib < 10 ? '0'+nib : 'a'+nib-10);
    }
    putc_('\n');
    for(;;);
}
