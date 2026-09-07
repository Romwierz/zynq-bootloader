# Configure environment (can be put into file called e.g. mkenv.mk)
TOP = $(realpath .)
BUILD ?= build

include $(TOP)/verbose.mk

CROSS_COMPILE = $${XILINX_VITIS}/gnu/aarch32/lin/gcc-arm-none-eabi/bin/arm-none-eabi-
CC            = $(CROSS_COMPILE)gcc
CPP           = $(CC) -E
LD            = $(CC) # Use linker throug $CC, because direct usage may cause weird issues
OBJCOPY       = $(CROSS_COMPILE)objcopy
AR            = $(CROSS_COMPILE)ar
SZ            = $(CROSS_COMPILE)size

RM    = rm
ECHO  = @echo
CP    = cp
MKDIR = mkdir
SED   = sed
CAT   = cat

LINKER_SCRIPT := src/lscript.ld
SPECS_FILE := src/Xilinx.spec
BOOT_IMG = boot.bin

# Utilities functions (can be put into file called e.g. mkutil.mk)
relpath = $(patsubst $(TOP)/%,%,$(1))

# Define all compilation/linking flags and options
INC += -I.
INC += -I./include
INC += -I$(BUILD)

CFLAGS += $(INC) -DSDT -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=softfp -MMD -MP -specs=$(SPECS_FILE)
CFLAGS += -O2 -g -Wall -Wextra -fno-tree-loop-distribute-patterns -DNDEBUG
LDFLAGS = $(CFLAGS) -T"$(LINKER_SCRIPT)" -Wl,-Map=$@.map,--cref
ifeq ($(BUILD_VERBOSE),1)
LDFLAGS += -Wl,--trace
endif

# Define required source and object files
SRC_C += $(addprefix src/,\
	main.c \
	xuartps.c \
	xuartps_hw.c \
	)

OBJ := $(patsubst src/%.c,$(BUILD)/%.o,$(SRC_C))

# Custom functions
define WRITE_BOOT_DEV
	@sh -c '{ [ -n "$(DEV)" ] && [ -n "$(MNT_POINT)" ]; } || \
		{ echo "Cannot write to SD card: DEV or MNT_POINT not specified"; exit 1; }'
	@sh -c '[ -b $(DEV) ] || { echo "Cannot write to SD card: $(DEV) does not exist"; exit 1; }'
	$(ECHO) "Writing $< to SD card..."
	@sudo sh -c "mount $(DEV) $(MNT_POINT) && $(CP) -v $< $(MNT_POINT) && umount $(MNT_POINT)"
endef

# Targets
.PHONY: all clean help

all: $(BUILD)/out.elf

help: ## Show this help message
	@grep --no-filename -E '^[a-zA-Z_-]+:.*?##.*$$' $(MAKEFILE_LIST) | awk 'BEGIN { \
	 FS = ":.*?## "; \
	 printf "\033[1m%-30s\033[0m %s\n", "TARGET", "DESCRIPTION" \
	} \
	{ printf "\033[32m%-30s\033[0m %s\n", $$1, $$2 }'

clean:
	$(RM) -rf $(BUILD)

printvars: ## Print internal variables
	@echo "CC      = $(CC)"
	@echo "CFLAGS  = $(CFLAGS)"
	@echo "LDFLAGS = $(LDFLAGS)"
	@echo "OBJ     = $(OBJ)"

$(BUILD)/out.elf: $(OBJ)
	@echo "LINK $@"
	$(Q)$(LD) $^ -o $@ $(LDFLAGS)
	$(Q)$(SZ) $@

$(BUILD)/%.o: src/%.c
	@mkdir -p $(BUILD)
	@echo "CC $<"
	$(Q)$(CC) -c -o $@ $(CFLAGS) $<

$(BOOT_IMG): $(BUILD)/out.elf
	bootgen -arch zynq -image zturn.bif -w on -o $@

deploy: $(BOOT_IMG) ## Build and deploy
	$(call WRITE_BOOT_DEV)

update-clangd: ## Update project-level .clangd
	@$(TOP)/utils/update-clangd
