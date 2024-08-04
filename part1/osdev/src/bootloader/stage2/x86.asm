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