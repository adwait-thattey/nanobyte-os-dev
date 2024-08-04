; See notebook for more details. 
; TLDR: We are making a macro to switch back and forth from protected and real mode after the first time to avoid using the stack
; The steps are taken from our trial of switching to PM and RM
; 0 below means we have 0 arguments
%macro x86_EnterRealMode 0
    [bits 32]
    jmp word 18h:.pmode16

.pmode16:
    [bits 16]
    ; now in 16 bit protected mode
    ; disable pmode bit in CR0
    mov eax, cr0
    and al, ~1      ;; ~ is NOT. Thus ~1 == 1111 1111 1111 1110
    mov cr0, eax

    ; jump to real mode
    jmp word 00h:.rmode

.rmode
    [bits 16]
    ; setup segments
    mov ax, 0
    mov ds, ax
    mov ss, ax

    ; enable interrupts
    sti
%endmacro


%macro x86_EnterProtectedMode 0
    [bits 16]

    cli

    ; set cr0 flag
    mov eax, cr0
    or al, 1
    mov cr0, eax

    ; far jump into pmode
    jmp dword 08h:.pmode

.pmode
    [bits 32]

    ; setup segments
    mov ax, 0x10
    mov ds, ax
    mov ss, ax

%endmacro


;; outb and inb functions are designed to read or write to a specific IO port
; we can dothe steps of setting up the stack frame by saving bp to the top of stack
; but thatis not needed because these are very small functions and we dont want to push anything into the stack here 

; Args: 1: Port ,2: Data to feed into port 
global x86_outb
x86_outb:
    ; esp would be the return address then 1st arg starts from esp+4
    [bits 32]
    mov dx, [esp + 4]
    mov al, [esp + 8]
    ; spec: https://c9x.me/x86/html/file_module_x86_id_222.html 
    ; we can use only DX for the port number
    out dx, al
    ret

global x86_inb
x86_inb:
    [bits 32]
    mov dx, [esp + 4]
    xor eax, eax
    ; spec: https://c9x.me/x86/html/file_module_x86_id_139.html
    in al, dx

    ;; in cdecl, int return values are passed through eax register
    ret


global x86_realmode_putc
x86_realmode_putc:

    ;; setup stack
    push ebp
    mov ebp, esp

    x86_EnterRealMode

        ; get first param from stack and print char
        mov al, [bp + 8]    ; we have 4 bytes of return address and then 4 bytes of saved ebp
        mov ah, 0xe
        int 10h
        
    x86_EnterProtectedMode

    ;; restoe stack
    mov esp, ebp
    pop ebp
    ret