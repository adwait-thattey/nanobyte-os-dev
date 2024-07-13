ASM=nasm

SRC_DIR=src
BUILD_DIR=build

image: $(BUILD_DIR)/floppy.img

$(BUILD_DIR)/floppy.img: $(BUILD_DIR)/boot.bin
	cp $(BUILD_DIR)/boot.bin $(BUILD_DIR)/floppy.img
	truncate -s 1140k $(BUILD_DIR)/floppy.img

$(BUILD_DIR)/boot.bin : $(SRC_DIR)/main.asm
	$(ASM) $(SRC_DIR)/main.asm -f bin -o $(BUILD_DIR)/boot.bin

run: image
	qemu-system-i386 -fda $(BUILD_DIR)/floppy.img

debug: image
	bochs -f bochs_config -q

.PHONY: image run debug
