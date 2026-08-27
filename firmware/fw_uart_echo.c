// RX 3 bytes (paced by TB), buffer them, then transmit all three + "E+".
// Proves CPU-side RX consume + TX report without TX/RX-drive overlap.
#define UART_ST (*(volatile unsigned int*)0x00020000)
#define UART_D  (*(volatile unsigned int*)0x00020004)
static void putc_(char c){ while(UART_ST & 1); UART_D = c; }
void main(void){
    unsigned b0, b1, b2;
    while (!(UART_ST & 2)); b0 = UART_D & 0xFF;
    while (!(UART_ST & 2)); b1 = UART_D & 0xFF;
    while (!(UART_ST & 2)); b2 = UART_D & 0xFF;
    putc_((char)b0); putc_((char)b1); putc_((char)b2);
    putc_('E'); putc_('+');
    while(1);
}
