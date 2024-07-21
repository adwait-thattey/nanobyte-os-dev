bits 16   ;# using 16 bit code

section .entry       ;# As defined in the linker script

;;extern _cstart_    ;# This is the entrypoint from C
global entry        ;# export the entry symbol so that it is visible outside this assembly file

entry:
    cli  ;# clear interrupt while setting up the flag

    ;# we are using the small memory model so the stack and data segments should be the same

    ;# data segment is already setup by stage 1. Copy it to stack segment
    mov ax, ds
    mov ss, ax

    
    ;# We set the base pointer and stack pointer to 0. SInce stack grows downward, it will wrap around the segment. 
    ;# Nothing should be overridden as long as stage2 is below somewhere around 60KBs
    
    mov sp, 0
    mov bp, sp

    sti  ;# set interrupts. Allow external interrupts now


    ;# now we expect the boot drive to be set in DL register. We will send it as an argument to the main function
    ;# To do this, put it into the stack
    
    xor dh, dh
    push dx     ;# we can push only full dx. SO set dh to 0 before pushing DL

    ;;call _cstart_

    ;# If we reach here, for safety, halt the system

    cli
    hlt
