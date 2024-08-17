#pragma once

// 0x00000000 - 0x000003FF - interrupt vector table
// 0x00000400 - 0x000004FF - BIOS data area

#define MEMORY_MIN          0x00000500
#define MEMORY_MAX          0x00080000

// 0x20000 - 0x30000 - FAT driver
#define MEMORY_FAT_ADDR     ((void*)0x20000)
#define MEMORY_FAT_SIZE     0x00010000

// This is the area where FAT will read kernel file in stage2
#define MEMORY_LOAD_KERNEL  ((void*)0x30000)
#define MEMORY_LOAD_SIZE    0x00010000

// 0x00020000 - 0x00030000 - stage2

// 0x00030000 - 0x00080000 - free

// 0x00080000 - 0x0009FFFF - Extended BIOS data area
// 0x000A0000 - 0x000C7FFF - Video
// 0x000C8000 - 0x000FFFFF - BIOS

// this is the actual kernel address where it is copied and then started from
#define MEMORY_KERNEL_ADDR  ((void*)0x100000)