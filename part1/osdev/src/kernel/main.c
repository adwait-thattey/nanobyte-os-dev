#include <stdint.h>
#include "stdio.h"
#include "memory.h"
#include "hal/hal.h"

// These both will be coming from the linker script
extern uint8_t __bss_start;
extern uint8_t __end;


// we will be placing start function in the entry section of the linker 
void __attribute__((section(".entry"))) start(uint16_t bootDrive)
{
    memset(&__bss_start, 0, (&__end) - (&__bss_start));
    clrscr();

    printf("Hello World from Kernel!!\n");
    HAL_Initialize();
    printf("Hello World after setting up GDT and IDT via HAL!!\n");

end:
    for(;;);
}



