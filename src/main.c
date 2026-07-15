// GPIO registers offsets
#define DATA0 0x00000040/4
#define DIRM0 0x00000204/4
#define OEN0  0x00000208/4

// MIO registers offsets
#define MIO_PIN_00 0x00000700/4 // User LED 1
#define MIO_PIN_09 0x00000724/4 // User LED 2

// MIO_PIN_x bits definition
#define MIO_PIN_DisableRcvr 1U << 13
#define MIO_PIN_PULLUP      1U << 12
#define MIO_PIN_IO_Type     6U << 11
#define MIO_PIN_Speed       1U << 8
#define MIO_PIN_L3_SEL      6U << 7
#define MIO_PIN_L2_SEL      6U << 4
#define MIO_PIN_L1_SEL      1U << 2
#define MIO_PIN_L0_SEL      1U << 1
#define MIO_PIN_TRI_ENABLE  1U << 0

#define MIO_PIN_IO_Type_LVCMOS18 1U << 11

unsigned int * const XGPIOPS = (unsigned int *)0xe000a000;
volatile unsigned int * const SLCR = (unsigned int *)0xf8000000;

static inline void set_bit(unsigned int nr, volatile unsigned int *addr)
{
    unsigned int mask = 1U << nr;
    *addr  |= mask;
}

static inline void clear_bit(unsigned int nr, volatile unsigned int *addr)
{
    unsigned int mask = 1U << nr;
    *addr &= ~mask;
}

void configure_mio0_9(void)
{
    SLCR[MIO_PIN_00] = MIO_PIN_DisableRcvr | MIO_PIN_IO_Type_LVCMOS18;
    SLCR[MIO_PIN_09] = MIO_PIN_DisableRcvr | MIO_PIN_IO_Type_LVCMOS18;
}

static void delay(volatile unsigned int cycles)
{
    while (cycles--);
}

int main(void)
{
    // Congigure MIO0,9 as GPIO
    configure_mio0_9();

    // Configure MIO pins 0,9 (User LED 1,2) as output and enable it
    set_bit(0, &XGPIOPS[DIRM0]);
    set_bit(0, &XGPIOPS[OEN0]);
    set_bit(9, &XGPIOPS[DIRM0]);
    set_bit(9, &XGPIOPS[OEN0]);

    // Toggle the leds
    while(1) {
        clear_bit(0, &XGPIOPS[DATA0]);
        set_bit(9, &XGPIOPS[DATA0]);
        delay(4000000U);
        set_bit(0, &XGPIOPS[DATA0]);
        clear_bit(9, &XGPIOPS[DATA0]);
        delay(4000000U);
    };

    return 0;
}
