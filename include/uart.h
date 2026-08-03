/******************************************************************************
 * This file is derived from the AMD/Xilinx embeddedsw project.
 *
 * Original file: xuartps.c
 *
 * Original copyright:
 * Copyright (C) 2010-2021 Xilinx, Inc.
 * Copyright (C) 2022-2023 Advanced Micro Devices, Inc.
 * SPDX-License-Identifier: MIT
 *
 * Modifications and simplifications:
 * Copyright (C) 2026 Michał Romsicki
******************************************************************************/

#ifndef UART_H /* circular inclusion protection macro */
#define UART_H

#include "xstatus.h"
#include "xuartps_hw.h"

#define UART_DFT_BAUDRATE  115200U   /* Default baud rate */

/* Low-level operations. */
#define UART_READ_REG(base_address, reg_offset) \
	Xil_In32((base_address) + (u32)(reg_offset))

#define UART_WRITE_REG(base_address, reg_offset, register_val) \
	Xil_Out32((base_address) + (u32)(reg_offset), (u32)(register_val))

#define UART_Enable(instance_ptr) \
   Xil_Out32(((instance_ptr)->config.base_addr + (u32)XUARTPS_CR_OFFSET), \
	  ((Xil_In32((instance_ptr)->config.base_addr + (u32)XUARTPS_CR_OFFSET) & \
	  (u32)(~XUARTPS_CR_EN_DIS_MASK)) | ((u32)XUARTPS_CR_RX_EN | (u32)XUARTPS_CR_TX_EN)))

#define UART_Disable(instance_ptr) \
   Xil_Out32(((instance_ptr)->config.base_addr + (u32)XUARTPS_CR_OFFSET), \
	  (((Xil_In32((instance_ptr)->config.base_addr + (u32)XUARTPS_CR_OFFSET)) & \
	  (u32)(~XUARTPS_CR_EN_DIS_MASK)) | ((u32)XUARTPS_CR_RX_DIS | (u32)XUARTPS_CR_TX_DIS)))

/* Keep track of state information about a data buffer in the interrupt mode. */
typedef struct {
	u8 *next_byte_ptr;
	u32 requested_bytes;
	u32 remaining_bytes;
} uart_buffer_t;

/* Keep track of data format setting of a device. */
typedef struct {
	u32 baud_rate; /**< In bps, ie 1200 */
	u32 data_bits; /**< Number of data bits */
	u32 parity;	   /**< Parity */
	u8 stop_bits;  /**< Number of stop bits */
} uart_format_t;

typedef struct {
	char *name;
	u32 base_addr;    /**< Base address of device (IPIF) */
	u32 input_clk_hz; /**< Input clock frequency */
} uart_config_t;

typedef struct {
	uart_config_t config; /* Configuration data structure */
	u32 input_clk_hz;	  /* Input clock frequency */
	u32 is_ready;		  /* Device is initialized and ready */
	u32 baud_rate;		  /* Current baud rate */

	uart_buffer_t send_buffer;
	uart_buffer_t receive_buffer;
} uart_t;

int uart_init(UINTPTR base_addr);
s32 XUartPs_SetBaudRate(uart_t *instance_ptr, u32 baud_rate);

#endif /* end of protection macro */
