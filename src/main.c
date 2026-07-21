#include "xstatus.h"
#include "xuartps.h"
#include "xparameters.h"

#define PS_CLK 33330000

// GPIO registers offsets
#define DATA0 0x00000040/4
#define DIRM0 0x00000204/4
#define OEN0  0x00000208/4

// MIO registers offsets
#define MIO_PIN_00 0x00000700/4 // User LED 1
#define MIO_PIN_09 0x00000724/4 // User LED 2
#define MIO_PIN_11 0x0000072c/4 // UART0 Tx

// SLCR registers offsets
#define SLCR_IO_PLL_CTRL   0x00000108
#define SLCR_PLL_STATUS    0x0000010C
#define SLCR_IO_PLL_CFG    0x00000118
#define SLCR_DCI_CLK_CTRL  0x00000128
#define SLCR_UART_CLK_CTRL 0x00000154

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

#define	XUARTPS_BASEADDRESS	XPAR_XUARTPS_1_BASEADDR

int UartPsHelloWorldExample(UINTPTR BaseAddress);

unsigned int * const XGPIOPS = (unsigned int *)0xe000a000;
volatile unsigned int * const SLCR = (unsigned int *)0xf8000000;
XUartPs Uart_Ps;

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

u32 calculate_uart_ref_clk(const u32 ps_clk)
{
    u32 uart_clk_ctrl;
    u32 io_pll_ctrl;
    u32 io_pll_cfg;
    u32 divisor = 0;
    u32 srcsel = 0;
    u32 pll_fdiv = 0;
    u32 pll_lock_cnt = 0;
    u32 pll_cp = 0;
    u32 pll_res = 0;

    // todo:
    // 1) Check PLL source used to generate UART clock
    // 2) Check PLL configuration (bypass included)
    // For now, assume IO PLL is source and bypass is disabled

    uart_clk_ctrl = Xil_In32(XPAR_SLCR_BASEADDR + SLCR_UART_CLK_CTRL);
    divisor = (uart_clk_ctrl >> 8) & 0x6;
    srcsel = (uart_clk_ctrl >> 4) & 0x2;

    io_pll_ctrl = Xil_In32(XPAR_SLCR_BASEADDR + SLCR_IO_PLL_CTRL);
    io_pll_cfg = Xil_In32(XPAR_SLCR_BASEADDR + SLCR_IO_PLL_CFG);
    pll_fdiv = (io_pll_ctrl >> 12) & 0x7;
    pll_lock_cnt = (io_pll_cfg >> 12) & 0xa;
    pll_cp = (io_pll_cfg >> 8) & 0x4;
    pll_res = (io_pll_cfg >> 4) & 0x4;

    return ps_clk * pll_fdiv / divisor;
}

int main(void)
{
    int Status;

    // Congigure MIO0,9 as GPIO
    configure_mio0_9();

    // Configure MIO pins 0,9 (User LED 1,2) as output and enable it
    set_bit(0, &XGPIOPS[DIRM0]);
    set_bit(0, &XGPIOPS[OEN0]);
    set_bit(9, &XGPIOPS[DIRM0]);
    set_bit(9, &XGPIOPS[OEN0]);

	Status = UartPsHelloWorldExample(XUARTPS_BASEADDRESS);
    if (Status == XST_FAILURE) {
		return XST_FAILURE;
	}

    xil_printf("SLCR_PLL_STATUS: 0x%08x\n\r", Xil_In32(XPAR_SLCR_BASEADDR + SLCR_PLL_STATUS));
    xil_printf("SLCR_IO_PLL_CTRL: 0x%08x\n\r", Xil_In32(XPAR_SLCR_BASEADDR + SLCR_IO_PLL_CTRL));
    xil_printf("SLCR_IO_PLL_CFG: 0x%08x\n\r", Xil_In32(XPAR_SLCR_BASEADDR + SLCR_IO_PLL_CFG));
    xil_printf("SLCR_UART_CLK_CTRL: 0x%08x\n\r", Xil_In32(XPAR_SLCR_BASEADDR + SLCR_UART_CLK_CTRL));
    xil_printf("Calculated UART_ref_clk: %d\n\r", calculate_uart_ref_clk(PS_CLK));

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

int UartPsHelloWorldExample(UINTPTR BaseAddress)
{
	u8 HelloWorld[] = "\n\rHello World\n\r";
	u32 SentCount = 0;
	int Status;
	XUartPs_Config Config;

    Config.BaseAddress = BaseAddress;
    Config.InputClockHz = calculate_uart_ref_clk(PS_CLK);

	Status = XUartPs_CfgInitialize(&Uart_Ps, &Config, Config.BaseAddress);
	if (Status != XST_SUCCESS) {
		return XST_FAILURE;
	}

	XUartPs_SetBaudRate(&Uart_Ps, 115200);

	while (SentCount < (sizeof(HelloWorld) - 1)) {
		/* Transmit the data */
		SentCount += XUartPs_Send(&Uart_Ps,
					   &HelloWorld[SentCount], 1);
	}

    xil_printf("InputClkHz: %d\n\r", Uart_Ps.Config.InputClockHz);
    xil_printf("RefClk: %d\n\r", Uart_Ps.Config.RefClk);
    xil_printf("Calculated Baudrate: %d\n\r", Uart_Ps.BaudRate);

	return SentCount;
}
