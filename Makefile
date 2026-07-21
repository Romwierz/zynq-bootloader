CC := $${XILINX_VITIS}/gnu/aarch32/lin/gcc-arm-none-eabi/bin/arm-none-eabi-gcc
AR := $${XILINX_VITIS}/gnu/aarch32/lin/gcc-arm-none-eabi/bin/arm-none-eabi-ar
SZ := $${XILINX_VITIS}/gnu/aarch32/lin/gcc-arm-none-eabi/bin/arm-none-eabi-size

LINKER_SCRIPT := src/lscript.ld

ROOTDIR = $(realpath .)

VITIS_WORKSPACE := $(ROOTDIR)/test_workspace
SPECS_FILE 		:= $(ROOTDIR)/bsp/Xilinx.spec
BSP_SRC 		:= $(ROOTDIR)/bsp/libsrc
BSP_HEADERS 	:= $(ROOTDIR)/bsp/include
BSP_LIBS_PATH 	:= $(ROOTDIR)/bsp/lib

comma:= ,
empty:=
space:= $(empty) $(empty)
LIBS := xil xilstandalone gcc c
LIBS := $(addprefix -l,$(LIBS))
LIBS := $(subst $(space),$(comma),$(LIBS))

relpath = $(patsubst $(ROOTDIR)/%,%,$(1))

# From Vitis IDE (Platform build):
CFLAGS		 := -DSDT -mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard -MMD -MP \
				-specs=$(SPECS_FILE) -I$(BSP_HEADERS)
CFLAGS_EXTRA := -O2 -g -Wall -Wextra -fno-tree-loop-distribute-patterns -DNDEBUG

ALL_CFLAGS 	 := $(CFLAGS) $(CFLAGS_EXTRA)
ALL_LDFLAGS  := $(CFLAGS) $(LDFLAGS) \
				-T"$(LINKER_SCRIPT)" \
				-L"$(BSP_LIBS_PATH)" -L"/" \
				-Wl,--start-group,$(LIBS) -Wl,--end-group
				# -Wl,--start-group,-lxiltimer,-lxilffs,-lxilrsa,-lxil,-lxilstandalone,-lxiltimer,-lxilffs,-lxilrsa,-lgcc,-lc -Wl,--end-group

SRC := $(wildcard src/*.c)
OBJ := $(SRC:.c=.o)

.PHONY: all clean bsp build-bsp-libxil-objects help

all: out.elf

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
	$(CC) $^ -o $@ $(ALL_LDFLAGS)
	$(SZ) $@

%.o: %.c
	$(CC) -c -o $@ $(ALL_CFLAGS) $<

# BSP madness
define build_drv
$(MAKE) -C $(BSP_SRC)/$(1)/src libs \
	COMPILER="$(CC)" \
	ARCHIVER="$(AR)" \
	COMPILER_FLAGS="-c $(CFLAGS)" \
	EXTRA_COMPILER_FLAGS="$(CFLAGS_EXTRA)"
endef

define clean_drv
$(MAKE) -C $(BSP_SRC)/$(1)/src clean
endef

define FOREACH
	for $1 in $2; do {\
		$3 ;\
	} done
endef

BSP_BUILD			  := $(ROOTDIR)/bsp/build
BSP_DRIVERS_MAKEFILES := $(wildcard $(BSP_SRC)/*/src/Makefile)
BSP_DRIVERS   		  := $(patsubst $(BSP_SRC)/%/src/Makefile,%,$(BSP_DRIVERS_MAKEFILES))
# Don't include standalone and xiltimer
BSP_DRIVERS_SRCS 	  := $(patsubst %/Makefile,%,$(BSP_DRIVERS_MAKEFILES))
BSP_DRIVERS_SRCS 	  := $(filter-out $(BSP_SRC)/xiltimer/src,$(BSP_DRIVERS_SRCS))
BSP_LIBXIL 	  		  := $(BSP_LIBS_PATH)/libxil.a
BSP_LIBXIL_STANDALONE := $(BSP_LIBS_PATH)/libxilstandalone.a

BSP_DRIVERS_C   := $(wildcard $(BSP_SRC)/*/src/*.c)
BSP_DRIVERS_OBJ := \
$(foreach dir,$(BSP_DRIVERS_SRCS),\
    $(addprefix $(BSP_LIBS_PATH)/,\
        $(notdir $(basename $(wildcard $(dir)/*.c)))))
BSP_DRIVERS_OBJ := $(addsuffix .o,$(BSP_DRIVERS_OBJ))

BSP_STANDALONE_ROOT := $(BSP_SRC)/standalone/src

BSP_STANDALONE_C := \
	$(wildcard $(BSP_STANDALONE_ROOT)/*.c) \
	$(wildcard $(BSP_STANDALONE_ROOT)/common/*.c) \
	$(wildcard $(BSP_STANDALONE_ROOT)/common/intr/*.c) \
	$(wildcard $(BSP_STANDALONE_ROOT)/arm/common/*.c) \
	$(wildcard $(BSP_STANDALONE_ROOT)/arm/common/gcc/*.c) \
	$(wildcard $(BSP_STANDALONE_ROOT)/arm/cortexa9/*.c)

BSP_STANDALONE_S := \
	$(wildcard $(BSP_STANDALONE_ROOT)/arm/cortexa9/gcc/*.S)

BSP_STANDALONE_OBJ := \
	$(patsubst $(BSP_STANDALONE_ROOT)/%.c,$(BSP_BUILD)/standalone/%.o,$(BSP_STANDALONE_C)) \
	$(patsubst $(BSP_STANDALONE_ROOT)/%.S,$(BSP_BUILD)/standalone/%.o,$(BSP_STANDALONE_S))

BSP_STANDALONE_INCLUDES := \
	-I$(BSP_STANDALONE_ROOT) \
	-I$(BSP_STANDALONE_ROOT)/common \
	-I$(BSP_STANDALONE_ROOT)/common/intr \
	-I$(BSP_STANDALONE_ROOT)/arm/common \
	-I$(BSP_STANDALONE_ROOT)/arm/cortexa9 \
	-I$(BSP_STANDALONE_ROOT)/arm/cortexa9/gcc

bsp: $(BSP_LIBXIL) $(BSP_LIBXIL_STANDALONE) ## Build BSP

$(BSP_LIBXIL): $(BSP_DRIVERS_OBJ)
	@mkdir -p $(BSP_LIBS_PATH)
	$(AR) rcs $@ $^

$(BSP_LIBXIL_STANDALONE): $(BSP_STANDALONE_OBJ)
	@mkdir -p $(BSP_LIBS_PATH)
	$(AR) rcs $@ $^

$(BSP_LIBS_PATH)/%.o:
	@mkdir -p $(BSP_LIBS_PATH)
	$(foreach drv,$(BSP_DRIVERS),$(call build_drv,$(drv));)

$(BSP_BUILD)/standalone/%.o: $(BSP_STANDALONE_ROOT)/%.c
	@mkdir -p $(dir $@)
	$(CC) -c $(BSP_STANDALONE_INCLUDES) $(ALL_CFLAGS) $< -o $@

$(BSP_BUILD)/standalone/%.o: $(BSP_STANDALONE_ROOT)/%.S
	@mkdir -p $(dir $@)
	$(CC) -c -x assembler-with-cpp $(BSP_STANDALONE_INCLUDES) $(ALL_CFLAGS) $< -o $@

bsp-drivers-clean:
	$(foreach drv,$(BSP_DRIVERS),$(call clean_drv,$(drv));)

bsp-standalone-clean:
	$(MAKE) -C $(BSP_SRC)/standalone/src/arm/cortexa9/gcc clean
	rm -rf $(BSP_BUILD)/standalone

bsp-clean-objects: bsp-drivers-clean bsp-standalone-clean ## Remove BSP objects

bsp-clean: bsp-clean-objects ## Remove BSP objects and libs
	rm -f $(BSP_LIBXIL) $(BSP_LIBXIL_STANDALONE)

update-clangd: ## Update project-level .clangd
	@$(ROOTDIR)/utils/update-clangd
