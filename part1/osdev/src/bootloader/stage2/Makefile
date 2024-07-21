BUILD_DIR?= $(abspath build)
TARGET_ASMFLAGS += -f elf	# watcom used obj files, gcc requires elf files
TARGET_CFLAGS += -ffreestanding -nostdlib
# explanation for above flags
# --freestanding says that these files are not dependant on any OS
# -nostdlib++
TARGET_LIBS += -lgcc
TARGET_LINKFLAGS += -T linker.ld -nostdlib


SOURCES_C=$(wildcard *.c)
SOURCES_ASM=$(wildcard *.asm)
OBJECTS_C=$(patsubst %.c, $(BUILD_DIR)/stage2/c/%.obj, $(SOURCES_C))
OBJECTS_ASM=$(patsubst %.asm, $(BUILD_DIR)/stage2/asm/%.obj, $(SOURCES_ASM))

.PHONY: all stage2 clean always

all: stage2

stage2: $(BUILD_DIR)/stage2.bin

$(BUILD_DIR)/stage2.bin: $(OBJECTS_ASM) $(OBJECTS_C)
	$(TARGET_LD) $(TARGET_LINKFLAGS) -Wl,-Map=$(BUILD_DIR)/stage2.map -o $@ $^
#	$(TARGET_LD) NAME $(BUILD_DIR)/stage2.bin FILE \{ $(OBJECTS_ASM) $(OBJECTS_C) \} OPTION MAP=$(BUILD_DIR)/stage2.map @linker.lnk

# @linker.ld is the custom script that needs to be executed. We will write it later

$(BUILD_DIR)/stage2/c/%.obj: %.c always
	$(TARGET_CC) $(TARGET_CFLAGS) -c -o=$@ $<

# Above $@ refers to the target, $< refers to the first depedency. 
# The target is full path to the obj file, the first dependency that we have specified above is the .c file

$(BUILD_DIR)/stage2/asm/%.obj: %.asm always
	$(TARGET_ASM) $(TARGET_ASMFLAGS) -o $@ $<

always:
	mkdir -p $(BUILD_DIR)/stage2/c
	mkdir -p $(BUILD_DIR)/stage2/asm

clean:
	rm -f $(BUILD_DIR)/stage2.bin

