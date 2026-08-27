// One SPI transfer with the TB holding MISO high: RX must be 0xFF.
// Prints "S+" / "S-".
#define UART_ST (*(volatile unsigned int*)0x00020000)
#define UART_D  (*(volatile unsigned int*)0x00020004)
#define SPI     (*(volatile unsigned int*)0x00030000)
static void putc_(char c){ while(UART_ST & 1); UART_D = c; }
void main(void){
    SPI = 0xB7;                                    // start transfer
    while (SPI & 1);                               // busy
    unsigned rx = (SPI >> 8) & 0xFF;
    putc_('S'); putc_(rx == 0xFF ? '+' : '-');
    while(1);
}
