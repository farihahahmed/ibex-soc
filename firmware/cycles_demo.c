// Measures the custom instructions against their software equivalents.
//
// PicoRV32 has no cycle counter in this configuration (ENABLE_COUNTERS=0), so
// timing is taken externally: the firmware raises GPIO[4] for the duration of
// each measured region and the testbench counts clock edges while it is high.
// That avoids adding counter hardware purely to measure the accelerator.
//
// Each pair runs the same workload twice - once in software, once with the
// custom instruction - over identical data, so the ratio is the speedup.
#define GPIO   (*(volatile unsigned int*)0x00010000)
#define UART_S (*(volatile unsigned int*)0x00020000)
#define UART_D (*(volatile unsigned int*)0x00020004)

#define MARK_HI  GPIO = 0x10
#define MARK_LO  GPIO = 0x00

static void putc_(char c){ while(UART_S & 1); UART_D = c; }
static void puthex(unsigned v){
    for (int i = 7; i >= 0; i--){
        unsigned n = (v >> (i*4)) & 0xF;
        putc_(n < 10 ? '0'+n : 'a'+n-10);
    }
    putc_(' ');
}

#define CUSTOM(f3, rd, rs1, rs2) \
    asm volatile (".insn r 0x0B, " #f3 ", 0, %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2))

// Software CRC32, bitwise. The table-driven version needs a 1 KB lookup table,
// which does not fit in this chip's 512 B data memory - so this loop is the
// realistic software baseline, not a strawman.
static unsigned crc32_sw(unsigned crc, unsigned byte){
    crc ^= byte;
    for (int i = 0; i < 8; i++)
        crc = (crc >> 1) ^ (0xEDB88320u & (unsigned)(-(int)(crc & 1)));
    return crc;
}

static unsigned popcount_sw(unsigned v){
    unsigned n = 0;
    while (v) { n += v & 1; v >>= 1; }
    return n;
}

__attribute__((section(".text.start"))) void _start(void){
    unsigned r, a, b;
    const int N = 200;               // large enough to dwarf the GPIO marker overhead

    // ---- CRC32 byte: software ----
    MARK_HI;
    r = 0xFFFFFFFF;
    for (unsigned c = 0; c < N; c++) r = crc32_sw(r, c + '1');
    MARK_LO;
    puthex(r);

    // ---- CRC32 byte: hardware ----
    MARK_HI;
    r = 0xFFFFFFFF;
    for (unsigned c = 0; c < N; c++) { a = r; b = c + '1'; CUSTOM(0, r, a, b); }
    MARK_LO;
    puthex(r);

    // ---- popcount: software ----
    MARK_HI;
    r = 0;
    for (unsigned i = 0; i < N; i++) r += popcount_sw(0xF0F0F0F0u ^ i);
    MARK_LO;
    puthex(r);

    // ---- popcount: hardware ----
    MARK_HI;
    r = 0;
    for (unsigned i = 0; i < N; i++) { a = 0xF0F0F0F0u ^ i; b = 0; CUSTOM(2, b, a, b); r += b; }
    MARK_LO;
    puthex(r);

    putc_('\n');
    for(;;);
}
