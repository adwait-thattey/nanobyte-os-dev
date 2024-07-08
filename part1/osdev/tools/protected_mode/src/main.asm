org 0x7C00
bits 16

; setup stack
entry:
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax      ; real mode, setting ss to 0 essentially means we are telling that memory addresses will be referred only by the stack pointer (SP) addresses
    mov sp, 7C00h   ; stack grows downward. All data will go below this

.halt:
    jmp .halt

times 510-($-$$) db 0
dw 0AA55h























