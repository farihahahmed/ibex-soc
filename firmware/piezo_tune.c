#define GPIO (*(volatile unsigned int*)0x00010000)
static void delay(unsigned int n){ while(n--) __asm__("nop"); }
static void tone(unsigned int p, unsigned int d){ for(unsigned int i=0;i<d;i++){GPIO=1;delay(p);GPIO=0;delay(p);} }
static const unsigned short song[] = {392,392,440,392,523,494,392,392,440,392,587,523,392,392,784,659,523,494,440,698,698,659,523,587,523};
void _start(void){
    while(1){ for(int i=0;i<25;i++) tone(song[i], 100); delay(100000); }
}
