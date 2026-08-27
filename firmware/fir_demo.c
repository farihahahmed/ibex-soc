// FIR filter demo for the MAC accelerator.
//
// Runs a 5-tap moving-average filter (taps 1,2,4,2,1 - unity DC gain) over a
// noisy square wave, using the custom mac/macrd/macclr instructions. Prints
// raw and filtered pairs over UART so the filtering is visible, not just
// asserted.
//
// The input is a +-100 square wave with +-30 alternating noise. A correct
// filter cuts the steady-state ripple from 30 to 6 - a 5x reduction - while
// preserving the square wave's amplitude.
//
// Samples and taps are computed arithmetically rather than declared as arrays:
// .rodata is placed in instruction memory by the linker, but data loads on
// this chip route to the AHB data memory, so const arrays are not reachable.
#define UART_S (*(volatile unsigned int*)0x00020000)
#define UART_D (*(volatile unsigned int*)0x00020004)

static void putc_(char c){ while(UART_S & 1); UART_D = c; }
static void putdec(int v){
    if (v < 0) { putc_('-'); v = -v; }
    if (v >= 100) putc_('0' + v/100);
    if (v >= 10)  putc_('0' + (v/10) % 10);
    putc_('0' + v % 10);
}

#define MAC(rd, rs1, rs2)   asm volatile (".insn r 0x0B, 4, 0, %0, %1, %2" \
                                          : "=r"(rd) : "r"(rs1), "r"(rs2))
#define MACCLR(rd)          asm volatile (".insn r 0x0B, 6, 0, %0, x0, x0" \
                                          : "=r"(rd))

static int sample(int i){
    if (i < 0) return 0;
    int base  = ((i / 8) % 2) ? -100 : 100;
    int noise = (i % 2) ? -30 : 30;
    return base + noise;
}
static int tap(int k){
    // 1, 2, 4, 2, 1
    if (k == 2) return 4;
    if (k == 1 || k == 3) return 2;
    return 1;
}

__attribute__((section(".text.start"))) void _start(void){
    unsigned r, a, b;
    for (int i = 0; i < 24; i++){
        MACCLR(r);                                   // start a new accumulation
        for (int k = 0; k < 5; k++){
            a = (unsigned)(sample(i - k) & 0xFFFF);  // 16-bit signed operand
            b = (unsigned)tap(k);
            MAC(r, a, b);                            // acc += a * b
        }
        int filtered = ((int)r) / 10;                // unity DC gain
        putdec(sample(i)); putc_(',');
        putdec(filtered);  putc_(' ');
    }
    putc_('\n');
    for(;;);
}
