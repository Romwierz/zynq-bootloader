include verbose.mk

CC := $${XILINX_VITIS}/gnu/aarch32/lin/gcc-arm-none-eabi/bin/arm-none-eabi-gcc
LD := $(CC)
AR := $${XILINX_VITIS}/gnu/aarch32/lin/gcc-arm-none-eabi/bin/arm-none-eabi-ar
SZ := $${XILINX_VITIS}/gnu/aarch32/lin/gcc-arm-none-eabi/bin/arm-none-eabi-size

ROOTDIR = $(realpath .)

LINKER_SCRIPT := $(ROOTDIR)/src/lscript.ld
SPECS_FILE := $(ROOTDIR)/src/Xilinx.spec

relpath = $(patsubst $(ROOTDIR)/%,%,$(1))

INC += -I.
INC += -I./include

# From Vitis IDE (Platform build):
CFLAGS		 := -DSDT -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=softfp -MMD -MP \
				-specs=$(SPECS_FILE)
CFLAGS_EXTRA := -O2 -g -Wall -Wextra -fno-tree-loop-distribute-patterns -DNDEBUG

ALL_CFLAGS 	 := $(INC) $(CFLAGS) $(CFLAGS_EXTRA)
ALL_LDFLAGS  = $(CFLAGS) $(LDFLAGS) \
				-T"$(LINKER_SCRIPT)" \
				-Wl,-Map=$@.map,--cref
ifeq ($(BUILD_VERBOSE),1)
ALL_LDFLAGS += -Wl,--trace
endif

SRC_C += $(addprefix src/,\
	main.c \
	xuartps.c \
	xuartps_hw.c \
	)

OBJ := $(SRC_C:.c=.o)

.PHONY: all clean bsp build-bsp-libxil-objects help

all: out.elf

deploy: out.elf ## Build and deploy
	@bootgen -arch zynq -image zturn.bif -w on -o boot.bin
	# @read '?Press Enter to continue...'
	# @sudo ./utils/copy-boot-image /dev/sde1

help: ## Show this help message
	@grep --no-filename -E '^[a-zA-Z_-]+:.*?##.*$$' $(MAKEFILE_LIST) | awk 'BEGIN { \
	 FS = ":.*?## "; \
	 printf "\033[1m%-30s\033[0m %s\n", "TARGET", "DESCRIPTION" \
	} \
	{ printf "\033[32m%-30s\033[0m %s\n", $$1, $$2 }'

clean:
	@rm -f out.elf $(OBJ)

printvars: ## Print internal variables
	@echo "CC      = $(CC)"
	@echo "CFLAGS  = $(ALL_CFLAGS)"
	@echo "LDFLAGS = $(ALL_LDFLAGS)"
	@echo "OBJ     = $(OBJ)"
	@echo "LIBS    = $(LIBS)"
	@echo "BSP_DRV = $(BSP_DRIVERS)"
	@echo "BSP_DRV_OBJ = $(BSP_DRIVERS_OBJ)"
	@echo "BSP_BUILD   = $(BSP_BUILD)"
	@echo "BSP_STANDALONE_C   = $(BSP_STANDALONE_C)"
	@echo "BSP_STANDALONE_OBJ = $(BSP_STANDALONE_OBJ)"

out.elf: $(OBJ)
	@echo "LINK $@"
	$(Q)$(LD) $^ -o $@ $(ALL_LDFLAGS)
	$(Q)$(SZ) $@

%.o: %.c
	@echo "CC $<"
	$(Q)$(CC) -c -o $@ $(ALL_CFLAGS) $<

update-clangd: ## Update project-level .clangd
	@$(ROOTDIR)/utils/update-clangd
