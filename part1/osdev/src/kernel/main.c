#include <stdint.h>
#include "stdio.h"
#include "memory.h"
#include "arch/i686/io.h"
#include "arch/i686/gdt.h"

// These both will be coming from the linker script
extern uint8_t __bss_start;
extern uint8_t __end;


// we will be placing start function in the entry section of the linker 
void __attribute__((section(".entry"))) start(uint16_t bootDrive)
{
    memset(&__bss_start, 0, (&__end) - (&__bss_start));
    clrscr();

    printf("Hello World from Kernel!!\n");
    initializeGDT();
    printf("Hello World after setting up GDT!!\n");

end:
    for(;;);
}



