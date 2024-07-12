org 0x7C00
bits 16

; setup stack
entry:
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax      ; real mode, setting ss to 0 essentially means we are telling that memory addresses will be referred only by the stack pointer (SP) addresses
    mov sp, 7C00h   ; stack grows downward. All data will go below this

    ;; STEPS TO SWITCH TO PROTECTED MODE

    cli     ;; step 1: disable interrupts
            ;; INTEL manual also recommends to disable NMI interrupts. But this can be more complicated

    ;; step 2: Enable the A20 line
    ; This step is only in the osdev wiki, not in the intel doc
    call EnableA20

    ;; Step 3: load GDT table
    call LoadGDT

    ; Step 4: Set protected mode enabled
    mov eax, cr0
    or al, 1    ; Set bit 1 of eax to 1
    mov cr0, eax

    ; step 5: perform a far jump/call into a protected mode code segment
    ;; In our case, protected mode code segment is the 2nd entry into the GDT table
    ;; for detailed explanation, check one note page "CPU protected vs real mode " section: STEP-5 : https://onedrive.live.com/redir?resid=A5259C7E6DFB4C6F%211685&page=Edit&wd=target%28Nanobyte%20OS%20Youtube%20series.one%7C8a3e1774-edb1-4849-86ee-1cf0c8c52b78%2FCPU%20protected%20vs%20real%20mode%7Cba2f029f-231c-4d6e-b3be-67040f222c95%2F%29&wdorigin=703

    jmp dword 08h:.pmode

.pmode:
    ;; we are now in 32 bit protected mode!

.halt:
    jmp .halt

LoadGDT:
    ;; lgdt is a special instruction that loads the data structure into the GDTR register
    lgdt [g_GDTDesc]
    ret

EnableA20:
    [bits 16]   ;; since we will be switching between 16 bit real mode and 32 bnit protected mode in this file, we need to specify for every function what bit mode we are using

    ;; following steps are needed to enable the A20 line
    ;; In short, based on doc here: https://wiki.osdev.org/%228042%22_PS/2_Controller#PS/2_Controller_Output_Port
    ;; we need to set the bit 1 of A20 gate to 1
    ;; for this, we first read this config, then set bit 1 to 1, then write config back

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

    ;; we need to wait for Keyboard controller to be available
    ;; We do this by using the status register
    ;; https://wiki.osdev.org/%228042%22_PS/2_Controller#Status_Register
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


KbdControllerDataPort               equ 0x60
KbdControllerCommandPort            equ 0x64

;; following are commands that can be sent to 0x64
;; https://wiki.osdev.org/%228042%22_PS/2_Controller#PS/2_Controller_IO_Ports
KbdControllerDisableKeyboard        equ 0xAD
KbdControllerEnableKeyboard         equ 0xAE
KbdControllerReadCtrlOutputPort     equ 0xD0
KbdControllerWriteCtrlOutputPort    equ 0xD1


;; GDT
g_GDT:
        ;; see OneNote notebook page for how this is structured

        dq 0        ;; first entry of GDT is NULL. (dq puts 8 bytes)

        ;; To keep things simple, we are going to use the entire memory for all regions and they will be overlapping regions
        ;; In protected mode, we will have full 32 bit code and data segment overlapping regions so the region can store both code and data
        ;; For real mode, we will have 16 bit code and data segments
        ;; Protected mode and real mode memory will also be overlapping

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

times 510-($-$$) db 0
dw 0AA55h























