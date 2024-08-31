BUILD_DIR?= $(abspath build)
TARGET_ASMFLAGS += -f elf	# watcom used obj files, gcc requires elf files
TARGET_CFLAGS += -ffreestanding -nostdlib -I.
# explanation for above flags
# --freestanding says that these files are not dependant on any OS
# -nostdlib++
# -I. adds the current directory as include directory. SO we can include files from here as <> . I dont really like this approach

TARGET_LIBS += -lgcc
TARGET_LINKFLAGS += -T linker.ld -nostdlib

# there is easier way to include subdirectories but for now this is fine. 
# Also we want to trigger a build if any header files change so adding them as dependencies
HEADERS_C = $(wildcard *.h) \
			$(wildcard */*.h) \
			$(wildcard */*/*.h) \
			$(wildcard */*/*/*.h)

SOURCES_C = $(wildcard *.c) \
			$(wildcard */*.c) \
			$(wildcard */*/*.c) \
			$(wildcard */*/*/*.c)

HEADERS_ASM = $(wildcard *.inc) \
			  $(wildcard */*.inc) \
			  $(wildcard */*/*.inc) \
			  $(wildcard */*/*/*.inc)

SOURCES_ASM = $(wildcard *.asm) \
			  $(wildcard */*.asm) \
			  $(wildcard */*/*.asm) \
			  $(wildcard */*/*/*.asm)


OBJECTS_C = $(patsubst %.c, $(BUILD_DIR)/kernel/c/%.obj, $(SOURCES_C))
OBJECTS_ASM = $(patsubst %.asm, $(BUILD_DIR)/kernel/asm/%.obj, $(SOURCES_ASM))

.PHONY: all kernel clean always

all: kernel

kernel: $(BUILD_DIR)/kernel.bin

$(BUILD_DIR)/kernel.bin: $(OBJECTS_ASM) $(OBJECTS_C)
	$(TARGET_LD) $(TARGET_LINKFLAGS) -Wl,-Map=$(BUILD_DIR)/kernel.map -o $@ $^ $(TARGET_LIBS)
	@echo "--> Created  kernel.bin"

# @linker.ld is the custom script that needs to be executed.

$(BUILD_DIR)/kernel/c/%.obj: %.c $(HEADERS_C) always
	@mkdir -p $(@D)
	$(TARGET_CC) $(TARGET_CFLAGS) -c -o $@ $<
	@echo "--> Compiled: " $<

# Above $@ refers to the target, $< refers to the first depedency. 
# The target is full path to the obj file, the first dependency that we have specified above is the .c file

$(BUILD_DIR)/kernel/asm/%.obj: %.asm $(HEADERS_ASM) always
	@mkdir -p $(@D)
	$(TARGET_ASM) $(TARGET_ASMFLAGS) -o $@ $<
	@echo "--> Compiled: " $<

always:
	mkdir -p $(BUILD_DIR)/kernel/c
	mkdir -p $(BUILD_DIR)/kernel/asm

clean:
	rm -f $(BUILD_DIR)/kernel.bin

