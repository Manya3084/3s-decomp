PLATFORM ?= ps2
VERSION ?= anniversary

# Binaries

ifeq ($(PLATFORM),ps2)
	MAIN := THIRD_U.BIN
endif

# Export so that Python could see those
export PLATFORM
export VERSION
export MAIN

# Directories

BIN_DIR := bin
BUILD_DIR := build/$(VERSION)/$(PLATFORM)
SRC_DIR := src/$(VERSION)
ASM_DIR := asm/$(VERSION)
INCLUDE_DIR := include
CONFIG_DIR := config/$(VERSION)
TOOLS_DIR := tools
EE_FORKWRAP := $(BIN_DIR)/ee-forkwrap.so
# Relative path: LD_PRELOAD splits on spaces, and this tree may live in one.
EEGCC_PATHS := LD_PRELOAD=$(EE_FORKWRAP) PATH=$(BIN_DIR)/ee/bin:$(BIN_DIR)/lib/gcc-lib/ee/2.96-ee-001003-1

# Tools

WIBO := $(BIN_DIR)/wibo
DTK := $(BIN_DIR)/dtk
MWCCPS2 := $(BIN_DIR)/mwccps2.exe
MWLDPS2 := MWCIncludes=$(BIN_DIR) $(WIBO) $(BIN_DIR)/mwldps2.exe

EEGCC := $(BIN_DIR)/ee/bin/gcc

CCPS2 := MWCIncludes=$(BIN_DIR) $(WIBO) $(MWCCPS2)

CC := $(CCPS2)
# Prefer a distro assembler. Arch has none, so setup_tools drops one in bin/.
SYS_AS := $(shell command -v mipsel-linux-gnu-as 2>/dev/null)
ifneq ($(SYS_AS),)
AS := $(SYS_AS)
else
AS := $(abspath $(BIN_DIR)/mipsel-linux-gnu-as)
endif
LD := $(MWLDPS2)

PYTHON := $(shell if [ -x .venv/bin/python3 ]; then echo .venv/bin/python3; else echo python3; fi)
# Retail SLUS-20949 v1.02 THIRD/THIRD_U.BIN does not match. This is the debug ELF.
EXPECTED_SHA1 := cf58495054c31ad852175c66e9ca04d5094f000e
SPLICE_ELF := $(PYTHON) $(TOOLS_DIR)/splice_elf.py
COMPARE_BYTES := $(PYTHON) $(TOOLS_DIR)/compare_bytes.py
PATCH_ALIGNMENT := $(PYTHON) $(TOOLS_DIR)/patch_alignment.py
GENERATE_LCF := $(PYTHON) -m tools.lcf.generate_lcf

# Flags

COMMON_INCLUDES := -I$(INCLUDE_DIR) -I$(INCLUDE_DIR)/sdk -I$(INCLUDE_DIR)/cri -I$(INCLUDE_DIR)/cri/ee -Izlib
PS2_INCLUDES := $(COMMON_INCLUDES) -I$(INCLUDE_DIR)/gcc
PS2_DEFINES := -DTARGET_PS2 -DDEBUG
MWCCPS2_FLAGS := -gccinc $(PS2_INCLUDES) -O0,p -c -lang c -str readonly -fl divbyzerocheck -sdatathreshold 128 $(PS2_DEFINES)
MWCCPS2_ZLIB_FLAGS := -inline off $(MWCCPS2_FLAGS)
EEGCC_FLAGS := $(PS2_INCLUDES) -O2 -G0 -c $(PS2_DEFINES) -DXPT_TGT_EE

AS_FLAGS += -EL -I $(INCLUDE_DIR) -G 128 -march=r5900 -mabi=eabi -no-pad-sections
LD_FLAGS := -main func_00100008 -map

# Files

MAIN_TARGET := $(BUILD_DIR)/$(MAIN)

S_FILES := $(shell find $(ASM_DIR) -name '*.s' -not -path *nonmatchings* 2>/dev/null)
GAME_C_FILES := $(shell find $(SRC_DIR)/sf33rd -name '*.c' -not -path '*/Compress/zlib/*' 2>/dev/null)
ZLIB_C_FILES := $(shell find $(SRC_DIR)/sf33rd/Source/Compress/zlib -name '*.c' 2>/dev/null)
CRI_C_FILES := $(shell find $(SRC_DIR)/cri -name '*.c' 2>/dev/null)
BIN2OBJ_C_FILES := $(shell find $(SRC_DIR)/bin2obj -name '*.c' 2>/dev/null)

ASM_O_FILES := $(patsubst %.s,%.s.o,$(S_FILES))
ASM_O_FILES := $(addprefix $(BUILD_DIR)/,$(ASM_O_FILES))
GAME_O_FILES := $(patsubst %.c,%.c.o,$(GAME_C_FILES))
GAME_O_FILES := $(addprefix $(BUILD_DIR)/,$(GAME_O_FILES))
ZLIB_O_FILES := $(patsubst %.c,%.c.o,$(ZLIB_C_FILES))
ZLIB_O_FILES := $(addprefix $(BUILD_DIR)/,$(ZLIB_O_FILES))
CRI_O_FILES := $(patsubst %.c,%.c.o,$(CRI_C_FILES))
CRI_O_FILES := $(addprefix $(BUILD_DIR)/,$(CRI_O_FILES))
BIN2OBJ_O_FILES := $(patsubst %.c,%.c.o,$(BIN2OBJ_C_FILES))
BIN2OBJ_O_FILES := $(addprefix $(BUILD_DIR)/,$(BIN2OBJ_O_FILES))

ALL_O_FILES := $(GAME_O_FILES) $(ZLIB_O_FILES) $(CRI_O_FILES) $(BIN2OBJ_O_FILES) $(ASM_O_FILES)
EEGCC_O_FILES := $(CRI_O_FILES) $(BIN2OBJ_O_FILES)

LINKER_SCRIPT := $(BUILD_DIR)/$(MAIN).lcf

COMPILER_TAR := mwcps2-3.0b38-030307.tar.gz
EE_COMPILER_TAR := ee-gcc2.96.tar.xz
DTK_TAG := v1.8.4

build: $(MAIN_TARGET)

# Etc. rules

decrypt:
	@test -f encrypted.bin || { echo "missing encrypted.bin"; exit 1; }
	@pass="$${BIN_PASSWORD:-}"; \
	if [ -z "$$pass" ] && [ -f .bin-password ]; then pass=$$(head -n 1 .bin-password); fi; \
	if [ -z "$$pass" ]; then echo "Set BIN_PASSWORD or write it in .bin-password"; exit 1; fi; \
	openssl enc -d -aes-256-cbc -in encrypted.bin -out $(MAIN) -pass pass:"$$pass"
	@got=$$(sha1sum $(MAIN) | awk '{print $$1}'); \
	if [ "$$got" != "$(EXPECTED_SHA1)" ]; then \
		echo "decrypted file sha1 $$got"; \
		echo "expected $(EXPECTED_SHA1)"; \
		exit 1; \
	fi
	@echo "decrypted $(MAIN)"

split:
	@test -f $(MAIN) || { echo "missing $(MAIN)"; echo "The matched file is the debug ELF, sha1 $(EXPECTED_SHA1). See docs/builde-guide.md."; exit 1; }
	@got=$$(sha1sum $(MAIN) | awk '{print $$1}'); \
	if [ "$$got" != "$(EXPECTED_SHA1)" ]; then \
		echo "$(MAIN) sha1 $$got"; \
		echo "expected $(EXPECTED_SHA1)"; \
		echo "The retail disc file is a different build. See docs/builde-guide.md."; \
		exit 1; \
	fi
	@mkdir -p $(dir $(LINKER_SCRIPT))
	$(GENERATE_LCF) $(LINKER_SCRIPT)

split_cps3:
	cargo build --release --manifest-path ./tools/saturn-splitter/rust-dis/Cargo.toml
	python3 ./tools/combine-and-decrypt.py ./sfiii3n/ ./decrypted.bin
	cargo run --release --manifest-path ./tools/saturn-splitter/rust-dis/Cargo.toml ./config/cps3/sfiii3n.yaml

clean: ##@ clean extracted files, assets, and build artifacts
	git clean -fdx $(ASM_DIR)/
	git clean -fdx build/
	git clean -fdx .splache

# Build

$(MAIN_TARGET): $(ALL_O_FILES) $(LINKER_SCRIPT)
	@$(LD) $(LD_FLAGS) -o $@ \
		$(LINKER_SCRIPT) \
		$(shell find $(BUILD_DIR) -name '*.o')

	$(COMPARE_BYTES) $(MAIN) $(MAIN_TARGET) 0x80 0x478A00

$(BUILD_DIR)/%.s.o: %.s
	@mkdir -p $(dir $@)
	"$(AS)" $(AS_FLAGS) -o $@ $<
	$(PATCH_ALIGNMENT) $@

$(BUILD_DIR)/%.c.o: %.c
	@mkdir -p $(dir $@)
	$(PYTHON) tools/mwccgap/mwccgap.py $< $@ --mwcc-path $(MWCCPS2) --macro-inc-path $(INCLUDE_DIR)/macro.inc --use-wibo --wibo-path $(WIBO) --as-path "$(AS)" --as-march r5900 --as-mabi eabi --target-encoding shift_jis $(MWCCPS2_FLAGS)
	$(PATCH_ALIGNMENT) $@

$(CRI_O_FILES): $(EE_FORKWRAP)
$(CRI_O_FILES): $(BUILD_DIR)/%.c.o: %.c
	@mkdir -p $(dir $@)
	$(EEGCC_PATHS) $(EEGCC) $< -o $@ $(EEGCC_FLAGS)

$(ZLIB_O_FILES): $(BUILD_DIR)/%.c.o: %.c
	@mkdir -p $(dir $@)
	$(PYTHON) tools/mwccgap/mwccgap.py $< $@ --mwcc-path $(MWCCPS2) --macro-inc-path $(INCLUDE_DIR)/macro.inc --use-wibo --wibo-path $(WIBO) --as-path "$(AS)" --as-march r5900 --as-mabi eabi --target-encoding shift_jis $(MWCCPS2_ZLIB_FLAGS)
	$(PATCH_ALIGNMENT) $@

# Tools

setup_tools: $(MWCCPS2) $(WIBO) $(EEGCC) $(EE_FORKWRAP) $(DTK) $(if $(SYS_AS),,$(BIN_DIR)/mipsel-linux-gnu-as)

$(EE_FORKWRAP): $(TOOLS_DIR)/ee-forkwrap.S
	@mkdir -p $(BIN_DIR)
	gcc -m32 -shared -fPIC -nostdlib -o $@ $<

$(BIN_DIR)/mipsel-linux-gnu-as:
	$(TOOLS_DIR)/fetch_mips_as.sh

$(WIBO):
	@mkdir -p $(BIN_DIR)
	wget -O $@ https://github.com/decompals/wibo/releases/download/0.6.13/wibo
	chmod +x $(WIBO)

$(DTK):
	@mkdir -p $(BIN_DIR)
	wget -O $@ https://github.com/encounter/decomp-toolkit/releases/download/$(DTK_TAG)/dtk-linux-x86_64
	chmod +x $(DTK)

$(MWCCPS2):
	@mkdir -p $(BIN_DIR)
	wget -O- https://github.com/decompme/compilers/releases/download/compilers/$(COMPILER_TAR) | tar xzv -C $(BIN_DIR)

$(EEGCC):
	@mkdir -p $(BIN_DIR)
	wget -O- https://github.com/decompme/compilers/releases/download/compilers/$(EE_COMPILER_TAR) | tar xJv -C $(BIN_DIR)
	ln -sfn ../lib $(BIN_DIR)/ee/lib

# Retail disc ELF. Independent of the encrypted debug build.
RETAIL_ELF := THIRD_U.BIN.retail
RETAIL_BUILD := build/retail
RETAIL_LD := config/retail/link.ld
RETAIL_MIPS_LD := $(BIN_DIR)/mipsel-linux-gnu-ld
RETAIL_OUT := $(RETAIL_BUILD)/THIRD_U.BIN

split-retail: $(RETAIL_BUILD)/equates.stamp

$(RETAIL_BUILD)/split.stamp: config/retail/sfiii.retail.yaml config/retail/symbols/funcs.txt $(RETAIL_ELF)
	@mkdir -p $(RETAIL_BUILD)
	$(PYTHON) -m splat split config/retail/sfiii.retail.yaml
	@touch $@

$(RETAIL_BUILD)/equates.stamp: $(RETAIL_BUILD)/split.stamp tools/retail_equates.py
	$(PYTHON) tools/retail_equates.py
	@touch $@

build-retail: $(RETAIL_OUT)

$(RETAIL_BUILD)/text.o: $(RETAIL_BUILD)/equates.stamp
	@mkdir -p $(RETAIL_BUILD)
	cat asm/retail/split/equates.s asm/retail/split/text.labeled.s | "$(AS)" $(AS_FLAGS) -o $@

$(RETAIL_BUILD)/payload.o: $(RETAIL_BUILD)/split.stamp asm/retail/split/data/payload.s
	@mkdir -p $(RETAIL_BUILD)
	"$(AS)" $(AS_FLAGS) -o $@ asm/retail/split/data/payload.s

$(RETAIL_OUT): $(RETAIL_BUILD)/text.o $(RETAIL_BUILD)/payload.o $(RETAIL_LD) $(RETAIL_MIPS_LD)
	$(RETAIL_MIPS_LD) -m elf32ltsmip -EL -T $(RETAIL_LD) -o $@ $(RETAIL_BUILD)/text.o $(RETAIL_BUILD)/payload.o
	$(PYTHON) tools/compare_retail.py $@
