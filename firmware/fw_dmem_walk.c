// Data-memory walking test: 6 words written across 0x40..0x54, read back and
// verified, then an inverted pass to catch stuck bits / inter-word bleed.
// Prints "D+" / "D-".  (crt0 sets sp; main() may use the stack.)
#define UART_ST (*(volatile unsigned int*)0x00020000)
#define UART_D  (*(volatile unsigned int*)0x00020004)
static void putc_(char c){ while(UART_ST & 1); UART_D = c; }
void main(void){
    volatile unsigned *m = (volatile unsigned*)0x00000040;
    unsigned ok = 1;
    for (int i = 0; i < 6; i++) m[i] = (0x11u << i) ^ (i * 0x01010101u);
    for (int i = 0; i < 6; i++)
        if (m[i] != ((0x11u << i) ^ (unsigned)(i * 0x01010101u))) ok = 0;
    for (int i = 0; i < 6; i++) m[i] = ~m[i];
    for (int i = 0; i < 6; i++)
        if (m[i] != ~((0x11u << i) ^ (unsigned)(i * 0x01010101u))) ok = 0;
    putc_('D'); putc_(ok ? '+' : '-');
    while(1);
}
