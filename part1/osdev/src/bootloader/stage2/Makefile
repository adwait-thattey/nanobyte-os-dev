BUILD_DIR?=build/
ASM?=nasm
ASMFLAGS?=-f obj
CC16=/usr/bin/watcom/binl64/wcc
CFLAGS16?=-4 -d3 -wx -ms -zl -zq
	# These flags taken from watcom documentation
	#  -4 specifically compiler compatible with 486 compiler. Not strictly necessary.
	#  -d3 generates full debugging symbols with obj files
	#  -s removes stackoverflow checks. We can not use this in our environment 
	#  -wx enable all warnings
	#  -ms: Use small memory model
	#  -zl: DOnt add references to std library., Very important in our free standing environment because we dont have standard OS libraries
	#  -zq only display warnings and errors
	#
LD16=/usr/bin/watcom/binl64/wlink

SOURCES_C=$(wildcard *.c)
SOURCES_ASM=$(wildcard *.asm)
OBJECTS_C=$(patsubst %.c, $(BUILD_DIR)/stage2/c/%.obj, $(SOURCES_C))
OBJECTS_C=$(patsubst %.asm, $(BUILD_DIR)/stage2/asm/%.obj, $(SOURCES_ASM))

.PHONY: all clean

all: stage2

stage2: $(BUILD_DIR)/stage2.bin

$(BUILD_DIR)/stage2.bin: $(OBJECTS_ASM) $(OBJECTS_C)
	$(LD16) NAME $(BUILD_DIR)/stage2.bin FILE \{ $(OBJECTS_ASM) $(OBJECTS_C) \} OPTION MAP=$(BUILD_DIR)/stage2.map @linker.lnk

# @linker.lnk is the custom script that needs to be executed. We will write it later

$(BUILD_DIR)/stage2/c/%.obj: %.c always
	$(CC16) $(CFLAGS16) -fo=$@ $<

# Above $@ refers to the target, $< refers to the first depedency. 
# The target is full path to the obj file, the first dependency that we have specified above is the .c file

$(BUILD_DIR)/stage2/asm/%.obj: %.asm always
	$(ASM) $(ASMFLAGS) -o $@ $<

always:
	mkdir -p $(BUILD_DIR)/stage2/c
	mkdir -p $(BUILD_DIR)/stage2/asm

clean:
	rm -rf $(BUILD_DIR)/stage2.bin

