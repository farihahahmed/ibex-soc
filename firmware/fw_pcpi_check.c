#define UART_ST (*(volatile unsigned int*)0x00020000)
#define UART_D  (*(volatile unsigned int*)0x00020004)
static void putc_(char c){ while(UART_ST & 1); UART_D = c; }
#define CUSTOM(f3, rd, rs1, rs2) \
    asm volatile (".insn r 0x0B, " #f3 ", 0, %0, %1, %2" : "=r"(rd) : "r"(rs1), "r"(rs2))
void main(void){
    putc_('a');                        // reached main
    unsigned r = 0xFFFFFFFF, x, y;
    for (unsigned c = '1'; c <= '9'; c++){ x = r; y = c; CUSTOM(0, r, x, y); }
    r ^= 0xFFFFFFFF;
    putc_('b');                        // finished CRC
    putc_('P');
    putc_(r == 0xcbf43926u ? '+' : '-');
    while(1);
}
