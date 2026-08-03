This is a minimal project to run an application on Zynq-7000 SoC (Z-turn board). Minimal UART
functionality is provided. The two LEDs that are present on the board blinks alternately to indicate
that the code is actually running.

It was created by analyzing and debloating the project generated in Vitis IDE. The `arm-none-eabi-`
toolchain is required for building. It is available as part of the Vitis installation.

This program is supposed to be loaded into the memory by the FSBL bootloader which is not provided
in this repository. The loading address can be changed through the linker script.

The boot image containing fsbl.elf, FPGA bitstream (optionally) and the main application must be
generated using `bootgen` available in Vitis installation (2025.2 version). If using an SD card as
boot device, the image must be named `boot.bin` and must be placed on the first partion (FAT16/32 format).
The command used to generate the image is:
`bootgen -arch zynq -image zturn.bif -w on -o boot.bin`.

Todo:
- provide configuration for the original Vitis project for reference.
