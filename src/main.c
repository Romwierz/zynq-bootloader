/*
 * Copyright (C) 2026 Michał Romsicki
 * SPDX-License-Identifier: MIT
 */

#include "system.h"
#include "xuartps.h"

XUartPs Uart_Ps;		/* The instance of the UART Driver */

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

u32 calculate_uart_ref_clk(const u32 ps_clk)
{
    u32 uart_clk_ctrl;
    u32 io_pll_ctrl;
    u32 divisor = 0;
    u32 pll_fdiv = 0;

    // todo:
    // 1) Check PLL source used to generate UART clock
    // 2) Check PLL configuration (bypass included)
    // For now, assume IO PLL is source and bypass is disabled

    uart_clk_ctrl = Xil_In32(XPAR_SLCR_BASEADDR + SLCR_UART_CLK_CTRL);
    divisor = (uart_clk_ctrl >> 8) & 0x6;

    io_pll_ctrl = Xil_In32(XPAR_SLCR_BASEADDR + SLCR_IO_PLL_CTRL);
    pll_fdiv = (io_pll_ctrl >> 12) & 0x7;

    return ps_clk * pll_fdiv / divisor;
}

int UartPsHelloWorldExample(UINTPTR BaseAddress)
{
	u8 HelloWorld[] = "Hello World";
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

	return SentCount;
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

    for(int i = 0; i < 10; ++i)
        outbyte('x');
    outbyte('\n');
    outbyte('\r');

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
