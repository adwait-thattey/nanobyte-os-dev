ASM=nasm
CC=gcc
RUSTC=cargo

SRC_DIR=src
BUILD_DIR=build
TOOLS_DIR=tools

.PHONY: all floppy_image kernel bootloader clean always tools_fat

all: floppy_image kernel bootloader tools_fat
#
# Floppy Image
#
floppy_image: $(BUILD_DIR)/main_floppy.img

$(BUILD_DIR)/main_floppy.img: bootloader kernel
	# create a 1.4 MB floppy with each block 512 bytes
	dd if=/dev/zero of=$(BUILD_DIR)/main_floppy.img bs=512 count=2880
	mkfs.fat -F 12 -n "NBIOS" $(BUILD_DIR)/main_floppy.img

	# now copy the bootloader. Use notrunc otherwise dd will delete the file beyond the size of bootloader
	dd if=$(BUILD_DIR)/bootloader.bin of=$(BUILD_DIR)/main_floppy.img conv=notrunc

	mcopy -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/stage2.bin "::stage2.bin"
	mcopy -i $(BUILD_DIR)/main_floppy.img $(BUILD_DIR)/kernel.bin "::kernel.bin"
	mcopy -i $(BUILD_DIR)/main_floppy.img $(TOOLS_DIR)/fat/test.txt "::test.txt"



#
# Bootloader
#
bootloader: stage1 stage2

stage1: $(BUILD_DIR)/stage1.bin

$(BUILD_DIR)/stage1.bin: always
	$(MAKE) -C $(SRC_DIR)/bootloader/stage1 BUILD_DIR=%(abspath $(BUILD_DIR))

#
stage2: $(BUILD_DIR)/stage2.bin

$(BUILD_DIR)/stage2.bin: always
	$(MAKE) -C $(SRC_DIR)/bootloader/stage2 BUILD_DIR=%(abspath $(BUILD_DIR))


# Kernel
#
kernel: $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/kernel.bin: always
	$(ASM) $(SRC_DIR)/kernel/main.asm -f bin -o $(BUILD_DIR)/kernel.bin


#
# Tools
#

tools_fat: $(BUILD_DIR)/tools/fat
$(BUILD_DIR)/tools/fat : always $(TOOLS_DIR)/fat
	mkdir -p $(BUILD_DIR)/tools
	$(CC) -g -o $(BUILD_DIR)/tools/fat12.bin $(TOOLS_DIR)/fat/parser.c 
	#$(RUSTC) build --manifest-path $(TOOLS_DIR)/fat/fat_parser/Cargo.toml
	#cp $(TOOLS_DIR)/fat/fat_parser/target/debug/fat_parser $(BUILD_DIR)/tools/

#
# Always
#
always: 
	mkdir -p $(BUILD_DIR)

#
# Clean
#
clean:
	rm -rf $(BUILD_DIR)/*
