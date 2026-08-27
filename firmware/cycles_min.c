// Minimal cycle comparison: no UART, no printing. GPIO[4] brackets each loop,
// GPIO[3] toggles once at the very end so the testbench knows we're done.
#define GPIO (*(volatile unsigned int*)0x00010000)

#define CUSTOM(f3, rd, rs1, rs2) \
    asm volatile (".insn r 0x0B, " #f3 ", 0, %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2))

static unsigned crc32_sw(unsigned crc, unsigned byte){
    crc ^= byte;
    for (int i = 0; i < 8; i++)
        crc = (crc >> 1) ^ (0xEDB88320u & (unsigned)(-(int)(crc & 1)));
    return crc;
}

__attribute__((section(".text.start"))) void _start(void){
    unsigned r, a, b;
    volatile unsigned sink;
    const int N = 64;

    GPIO = 0x10;                                   // region 1: software
    r = 0xFFFFFFFF;
    for (int c = 0; c < N; c++) r = crc32_sw(r, (unsigned)c);
    GPIO = 0x00;
    sink = r;

    GPIO = 0x10;                                   // region 2: hardware
    r = 0xFFFFFFFF;
    for (int c = 0; c < N; c++) { a = r; b = (unsigned)c; CUSTOM(0, r, a, b); }
    GPIO = 0x00;
    sink = r;

    GPIO = 0x08;                                   // done marker
    for(;;);
}
