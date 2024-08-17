bits 16   ;# using 16 bit code

section .entry       ;# As defined in the linker script

;; this is for the bss section from the linker which will be zeroed later
extern __bss_start
extern __end

extern start
global entry        ;# export the entry symbol so that it is visible outside this assembly file

entry:
    cli  ;# clear interrupt while setting up the flag

    ;; save bootdrive
    mov [g_BootDrive], dl

    ;# we are using the small memory model so the stack and data segments should be the same

    ;# data segment is already setup by stage 1. Copy it to stack segment
    mov ax, ds
    mov ss, ax


    ;# We set the base pointer and stack pointer to 0. SInce stack grows downward, it will wrap around the segment.
    ;# Nothing should be overridden as long as stage2 is below somewhere around 60KBs

    mov sp, 0xFFF0
    mov bp, sp


    ;; Now make the switch to protected mode
    ;; Following is copied from tools/protected_mode/src
    ;; comments have been stripped from here. GO there to check full explanation
    ;; STEPS TO SWITCH TO PROTECTED MODE
    call EnableA20
    call LoadGDT

    ; set protection enable flag in cr0
    mov eax, cr0
    or al, 1    ; Set bit 1 of eax to 1
    mov cr0, eax

    ;5 - far jump to pmode
    jmp dword 08h:.pmode

;;;;
;;; Following code is to switch to protected mode.
;;; Taken from tools / protected_mode / src
;;; comments are stripped
;;;;
.pmode:
    ;; we are now in 32 bit protected mode!
    [bits 32]

    ;; step 6: Set ds, ss to data segment register
    mov ax, 0x10    ;; protected mode data segment is 3rd entry ion GDT = 16th bit = 0x10
    mov ds, ax
    mov ss, ax

    ; clear bss (uninitialized data)
    ; this is done to make sure all uninitialized (global) variables are set to 0 at the start
    mov edi, __bss_start
    mov ecx, __end
    sub ecx, edi
    mov al, 0
    cld ;; make sure edi is incremented in following instruction
    rep stosb ; stosb copies byte from al into edi then increment edi. rep repeats an instruction ecx times

    ; expect boot drive in dl, send it as argument to cstart function
    xor edx, edx
    mov dl, [g_BootDrive]
    push edx
    call start

    cli
    hlt

EnableA20:
    [bits 16]   ;; since we will be switching between 16 bit real mode and 32 bnit protected mode in this file, we need to specify for every function what bit mode we are using

    ; 1. Disable Keyboard
    call A20WaitInput
    mov al, KbdControllerDisableKeyboard
    out KbdControllerCommandPort, al

    ; step2: read control output port
    call A20WaitInput
    mov al, KbdControllerReadCtrlOutputPort
    out KbdControllerCommandPort, al

    call A20WaitOutput
    in al, KbdControllerDataPort    ; read from data port the requested output
    push eax    ; save al to stack

    ; step 3: write control output port. Set bit 2 or previously read data to 1 and send it back
    call A20WaitInput
    mov al, KbdControllerWriteCtrlOutputPort
    out KbdControllerCommandPort, al

    call A20WaitInput
    pop eax
    or al, 2                                    ; bit 2 = A20 bit
    out KbdControllerDataPort, al

    ; step4: enable keyboard
    call A20WaitInput
    mov al, KbdControllerEnableKeyboard
    out KbdControllerCommandPort, al

    call A20WaitInput
    ret


A20WaitInput:
    [bits 16]

    ; Bit 1 (Second bit) will tell us if it is clear. We need to wait until it is 0
    in al, KbdControllerCommandPort
    test al, 2  ; 2 is 10, test effectively perfoems AND between al and 10 thus result will be 1 or 0 depending on what is the bit 1 in AL
    jnz A20WaitInput    ; repeat until 0
    ret

A20WaitOutput:
    [bits 16]

    ;; Same as A20WaitInput but we need to check bit 0 amd wait till its 1
    in al, KbdControllerCommandPort
    test al, 1
    jz A20WaitOutput    ; repeat until 1
    ret

LoadGDT:
    [bits 16]
    ;; lgdt is a special instruction that loads the data structure into the GDTR register
    lgdt [g_GDTDesc]
    ret


KbdControllerDataPort               equ 0x60
KbdControllerCommandPort            equ 0x64

;; following are commands that can be sent to 0x64
;; https://wiki.osdev.org/%228042%22_PS/2_Controller#PS/2_Controller_IO_Ports
KbdControllerDisableKeyboard        equ 0xAD
KbdControllerEnableKeyboard         equ 0xAE
KbdControllerReadCtrlOutputPort     equ 0xD0
KbdControllerWriteCtrlOutputPort    equ 0xD1

ScreenBuffer                        equ 0xB8000

;; GDT
g_GDT:
        ;; see OneNote notebook page for how this is structured

        dq 0        ;; first entry of GDT is NULL. (dq puts 8 bytes)

        ; 32-bit code segment
        dw 0FFFFh                   ; limit (bits 0-15) = 0xFFFFF for full 32-bit range
        dw 0                        ; base (bits 0-15) = 0x0
        db 0                        ; base (bits 16-23)
        db 10011010b                ; access (present, ring 0, code segment, executable, direction 0, readable)
        db 11001111b                ; granularity (4k pages, 32-bit pmode) + limit (bits 16-19)
        db 0                        ; base high

        ; 32-bit data segment
        dw 0FFFFh                   ; limit (bits 0-15) = 0xFFFFF for full 32-bit range
        dw 0                        ; base (bits 0-15) = 0x0
        db 0                        ; base (bits 16-23)
        db 10010010b                ; access (present, ring 0, data segment, executable, direction 0, writable)
        db 11001111b                ; granularity (4k pages, 32-bit pmode) + limit (bits 16-19)
        db 0                        ; base high

        ; 16-bit code segment
        dw 0FFFFh                   ; limit (bits 0-15) = 0xFFFFF
        dw 0                        ; base (bits 0-15) = 0x0
        db 0                        ; base (bits 16-23)
        db 10011010b                ; access (present, ring 0, code segment, executable, direction 0, readable)
        db 00001111b                ; granularity (1b pages, 16-bit pmode) + limit (bits 16-19)
        db 0                        ; base high

        ; 16-bit data segment
        dw 0FFFFh                   ; limit (bits 0-15) = 0xFFFFF
        dw 0                        ; base (bits 0-15) = 0x0
        db 0                        ; base (bits 16-23)
        db 10010010b                ; access (present, ring 0, data segment, executable, direction 0, writable)
        db 00001111b                ; granularity (1b pages, 16-bit pmode) + limit (bits 16-19)
        db 0                        ; base high

;; This structure will be stored in the GDTR register
;; first entry is size of GDT - 1, second entry is the address of the GDT
g_GDTDesc:  dw g_GDTDesc - g_GDT - 1    ; limit = size of GDT
            dd g_GDT                    ; address of GDT

g_BootDrive: db 0
