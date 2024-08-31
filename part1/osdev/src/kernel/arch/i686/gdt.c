#include "gdt.h"
#include <stdint.h>
#include <stdio.h>

typedef struct
{
    // members are placed in memory in order. So 1st element is placed at lowest memory and last member at highest memory

    uint16_t limit0_15; // lower limit bits 0-15
    uint16_t base0_15;  // segment start address bits 0-15
    uint8_t  base16_23; // segment start address bits 16-23
    uint8_t  accessByte; // access flags
    uint8_t  flagsAndLimit16_19; // flags and limit bits 16-19
    uint8_t  base24_31; // segment start address bits 24-31 
} __attribute__((packed)) GDTEntry;

enum GDTAccessFlags 
{
    GDTAccessFlags_Default  = 0,
    GDTAccessFlags_Accessed = 1,
    
    GDTAccessFlags_ReadWriteAllowed = 1 << 1,

    GDTAccessFlags_DirectionUP = 0 << 2,
    GDTAccessFlags_DirectionDown = 1 << 2,

    GDTAccessFlags_NonExecutableDataSegment = 0 << 3,
    GDTAccessFlags_ExecutableCodeSegment = 1 << 3,

    GDTAccessFlags_DescriptorType_SegmentSystem = 0 << 4,
    GDTAccessFlags_DescriptorType_SegmentCodeOrData = 1 << 4,

    // Privilege level is 2 bits
    GDTAccessFlags_PrivilegeLevel_Ring0 = 0 << 5,
    GDTAccessFlags_PrivilegeLevel_Ring1 = 1 << 5,    
    GDTAccessFlags_PrivilegeLevel_Ring2 = 2 << 5,    
    GDTAccessFlags_PrivilegeLevel_Ring3 = 3 << 5, 

    GDTAccessFlags_Present = 1 << 7    
};

enum GDTFlags
{
    // flags are upper 3 bits of flags+limit
    GDTFlags_64BitLongMode = 1 << 5,

    GDTFlags_16BitRealMode = 0 << 6,
    GDTFlags_32BitRealMode = 1 << 6,

    GDTFlags_GranularityByte = 0 << 7,
    GDTFlags_GranularityPage = 1 << 7, // 4Kib segments
};

typedef struct
{
    uint16_t Limit;                     // sizeof(gdt) - 1
    GDTEntry* Ptr;                      // address of GDT
} __attribute__((packed)) GDTDescriptor;


GDTEntry getNullSegment() {
    GDTEntry nullSegment;
    nullSegment.limit0_15 = 0;
    nullSegment.base0_15 = 0;
    nullSegment.base16_23 = 0;
    nullSegment.accessByte = 0;
    nullSegment.flagsAndLimit16_19 = 0;
    nullSegment.base24_31 = 0;
    
    return nullSegment;
}

GDTEntry getCodeSegment() {
    
    GDTEntry codeSegment;
    codeSegment.limit0_15 = 0xFFFF;
    codeSegment.base0_15 = 0;
    codeSegment.base16_23 = 0;
    codeSegment.accessByte = GDTAccessFlags_ReadWriteAllowed | GDTAccessFlags_DirectionUP | GDTAccessFlags_ExecutableCodeSegment | GDTAccessFlags_DescriptorType_SegmentCodeOrData | GDTAccessFlags_PrivilegeLevel_Ring0 | GDTAccessFlags_Present;
    codeSegment.flagsAndLimit16_19 = 0b1111 | GDTFlags_GranularityPage | GDTFlags_32BitRealMode;
    codeSegment.base24_31 = 0;
    
    return codeSegment;
}

GDTEntry getDataSegment() {

    GDTEntry dataSegment;
    dataSegment.limit0_15 = 0xFFFF;
    dataSegment.base0_15 = 0;
    dataSegment.base16_23 = 0;
    dataSegment.accessByte = GDTAccessFlags_ReadWriteAllowed | GDTAccessFlags_DirectionUP | GDTAccessFlags_NonExecutableDataSegment | GDTAccessFlags_DescriptorType_SegmentCodeOrData | GDTAccessFlags_PrivilegeLevel_Ring0 | GDTAccessFlags_Present;
    dataSegment.flagsAndLimit16_19 = 0b1111 | GDTFlags_GranularityPage | GDTFlags_32BitRealMode;
    dataSegment.base24_31 = 0;
    
    return dataSegment;
}

// THIS function is written in assembly which actually calls the LGDT instruction
void __attribute__((cdecl)) i686_GDT_Load(GDTDescriptor* descriptor, uint16_t codeSegment, uint16_t dataSegment);

void i686_GDT_Initialize() {
    // we need only 1 code and 1 data segment here. 1st segment is always 0

    GDTEntry gdt[] = {
        getNullSegment(),
        getCodeSegment(),
        getDataSegment()
    };

    GDTDescriptor g_GDTDescriptor = { sizeof(gdt) - 1, gdt};

    /* ** DEBUG **
    uint64_t* gdt0 = (uint64_t*)(&gdt[0]);
    uint64_t* gdt1 = (uint64_t*)(&gdt[1]);
    uint64_t* gdt2 = (uint64_t*)(&gdt[2]);
    printf("GDT0: %llu , GDT1: %llu , GDT2: %llu", *gdt0, *gdt1, *gdt2);
    */

    i686_GDT_Load(&g_GDTDescriptor, i686_GDT_CODE_SEGMENT, i686_GDT_DATA_SEGMENT);
}

// int main() {

//     initializeGDT();    
// }