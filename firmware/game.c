#define GPIO (*(volatile unsigned int*)0x00010000)
#define SPI  (*(volatile unsigned int*)0x00030000)
static void lcd(unsigned int c){ SPI = c; }
#define W 16
#define H 8
void _start(void){
    int player=W/2, obs_col=5, obs_row=0, score=0;
    unsigned int seed=12345;
    while(1){
        unsigned int b=GPIO;
        if((b&1)&&player>0) player--;
        if((b&2)&&player<W-1) player++;
        obs_row++;
        if(obs_row>=H){ obs_row=0; seed=seed*1103515245+12345; obs_col=(seed>>16)%W; score++; }
        lcd(0x80|player); lcd('A');
        lcd(0x80|(obs_col+16)); lcd('O');
        if(obs_row==H-1 && obs_col==player){ lcd('X'); score=0; }
    }
}
