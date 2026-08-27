// Walking-1 across the 4 GPIO outputs, verified via output readback [5:2].
// Prints "GW+" on pass, "GW-" on first mismatch. No stack, no rodata.
#define UART_ST (*(volatile unsigned int*)0x00020000)
#define UART_D  (*(volatile unsigned int*)0x00020004)
#define GPIO    (*(volatile unsigned int*)0x00010000)
static void putc_(char c){ while(UART_ST & 1); UART_D = c; }
void main(void){
    unsigned ok = 1;
    for (unsigned w = 1; w <= 8; w <<= 1){
        GPIO = w;
        for (volatile int i = 0; i < 8; i++);      // settle
        if (((GPIO >> 2) & 0xF) != w) ok = 0;
    }
    GPIO = 0;
    putc_('G'); putc_('W'); putc_(ok ? '+' : '-');
    while(1);
}
