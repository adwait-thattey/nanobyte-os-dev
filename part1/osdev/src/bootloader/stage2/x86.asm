bits 16

section _TEXT class=CODE    ;; we want to put this file in the TEXT section of CODE class (see linker class)


;; This is function to print a single character to screen
;; For this we use the interrupt 10h (Hex 10) with mode 0Eh (hex 0E)
;; The inputs for this arte 2. First is the character to print, 2nd argument is the page
;;
global _x86_Video_WriteCharacterTeletype ;; so that this will be exported and can be used from C
_x86_Video_WriteCharacterTeletype:
    
    ;; now create a new stack frame (call frame) by pushing bp
    ;; See notebook for reference: Section on CDecl convention
    ;;   https://onedrive.live.com/redir?resid=A5259C7E6DFB4C6F%211685&page=Edit&wd=target%28Nanobyte%20OS%20Youtube%20series.one%7Cb33e8ee2-c3ce-426f-a8ef-6cf922fb209d%2FWrite%20stage2%20in%20C%7Cc1e515f4-426d-46bf-ba2d-6397d5d53c83%2F%29&wdorigin=703
    
    push bp
    mov bp, sp

    ;; we will call interrupt 10h (0x10). It uses bh and bl. 
    ;; SO save bx first
    push bx


    ;; [bp + 0] contains old call frame
    ;; [bp + 2] contains return address (small memory model: 2 bytes)
    ;; [bp + 4] contains first argument (character to print)
    ;; [bp + 6] contains 2nd argument (page)

    mov ah, 0Eh     ;; mode to print a single character
    mov al, [bp + 4]
    mov bh, [bp + 6]

    int 10h


    ; restore
    pop bx

    ;; restore previous stack
    mov sp, bp
    pop bp
    ret


