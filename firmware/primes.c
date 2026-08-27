#define UART_ST (*(volatile unsigned int*)0x00020000)
#define UART_D  (*(volatile unsigned int*)0x00020004)
static void putc(char c){ while(UART_ST & 1); UART_D=c; }
static void putn(unsigned int n){ char b[10];int i=0; if(!n){putc('0');return;} while(n){b[i++]='0'+n%10;n/=10;} while(i--)putc(b[i]); }
static int isp(unsigned int n){ if(n<2)return 0; for(unsigned int i=2;i*i<=n;i++) if(n%i==0)return 0; return 1; }
void main(void){
    for(unsigned int n=2;;n++){ if(isp(n)){ putn(n); putc(' '); } }
}
