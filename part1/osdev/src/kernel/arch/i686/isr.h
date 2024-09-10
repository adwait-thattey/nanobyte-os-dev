#pragma once
#include <cstdint>
#include <stdint.h>


/*
* The registers will be pushed from the assembly handler on the stack
* Here we are defining the exact order they will be pushed so that we can access them one by one using stack pointer
* The order defined in this struct is opposite of push order
* The order in which pusha instruction pushes is given in documentation
*/
typedef struct
{
    uint32_t ds;    // original data segment that was pushed by us
    uint32_t edi, esi, ebp, esp_orig, ebx, edx, ecx, eax; // reverse order as pushed by pusha instruction
    uint32_t interrupt, error;  // as pushed by our wrapper
    uint32_t eip, cs, eflags, esp, ss; // these are automatically pushed by the CPU
} __attribute__((packed)) Registers;



