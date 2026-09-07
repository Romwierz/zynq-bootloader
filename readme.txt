About
=====

This is a minimal project to run an application on Zynq-7000 SoC (Z-turn board). Minimal UART
functionality is provided. The two LEDs that are present on the board blinks alternately to indicate
that the code is actually running.

It was created by analyzing and debloating the project generated in Vitis IDE. The `arm-none-eabi-`
toolchain is required for building. It is available as part of the Vitis installation.

This program is supposed to be loaded into the memory by the FSBL bootloader which is not provided
in this repository. The loading address can be changed through the linker script.

The boot image containing fsbl.elf, FPGA bitstream (optionally) and the main application must be
generated using `bootgen` available in Vitis installation (2025.2 version). If using an SD card as
boot device, the image must be named `boot.bin` and must be placed on the first partition (FAT16/32 format).
The command used to generate the image is:
    bootgen -arch zynq -image zturn.bif -w on -o boot.bin

How to debug
============

The debug adapter that was tested and works with Zynq in JTAG-SMT2.

The software debugging is possible only when PS DAP is accessible through JTAG. In non-secure boot (which
is implicit if FSBL image is not encrypted) is automatically enabled by BootROM code. In secure boot the
access must be restored by the FSBL or subsequent PS images.

Start GDB server:
    openocd -f interface/ftdi/digilent_jtag_smt2_nc.cfg -f target/zynq_7000.cfg

Start GDB and connect to GDB server:
    arm-non-eabi-gdb out.elf -ex 'target remote localhost:3333'
