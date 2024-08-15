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

.rmode:
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

.pmode:
    [bits 32]

    ; setup segments
    mov ax, 0x10
    mov ds, ax
    mov ss, ax

%endmacro

; Convert linear address to segment:offset address
; Args:
;    1 - linear address
;    2 - (out) target segment (e.g. es)
;    3 - target 32-bit register to use (e.g. eax)
;    4 - target lower 16-bit half of #3 (e.g. ax)

%macro LinearToSegOffset 4

    mov %3, %1      ; linear address to eax
    shr %3, 4
    mov %2, %4
    mov %3, %1      ; linear address to eax
    and %3, 0xf

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


;; FOllowing disk functions copied from older stage 2 asm with slight modifications

; bool _cdecl x86_Disk_GetDriveParams(uint8_t drive, uint8_t* driveTypeOut, uint16_t* cylindersOut,
;                                    uint16_t* sectorsOut, uint16_t* headsOut);
global x86_Disk_GetDriveParams
x86_Disk_GetDriveParams:
    [bits 32]

    ; make new call frame
    push ebp             ; save old call frame
    mov ebp, esp         ; initialize new call frame

    x86_EnterRealMode

    [bits 16]

    ; save regs
    push es
    push bx
    push esi
    push di

    ; call int13h
    mov dl, [bp + 8]    ; dl - disk drive
    mov ah, 08h
    mov di, 0           ; es:di - 0000:0000
    mov es, di
    stc
    int 13h

    ; out params
    mov eax, 1
    sbb eax, 0

    ; drive type from bl
    ; see one note for explanation on how this conversion works
    LinearToSegOffset [bp + 12], es, esi, si
    mov [es:si], bl

    ; cylinders
    mov bl, ch          ; cylinders - lower bits in ch
    mov bh, cl          ; cylinders - upper bits in cl (6-7)
    shr bh, 6
    inc bx

    LinearToSegOffset [bp + 16], es, esi, si
    mov [es:si], bx

    ; sectors
    xor ch, ch          ; sectors - lower 5 bits in cl
    and cl, 3Fh
    
    LinearToSegOffset [bp + 20], es, esi, si
    mov [es:si], cx

    ; heads
    mov cl, dh          ; heads - dh
    inc cx

    LinearToSegOffset [bp + 24], es, esi, si
    mov [es:si], cx

    ; restore regs
    pop di
    pop esi
    pop bx
    pop es

    ; return

    push eax

    x86_EnterProtectedMode

    [bits 32]

    pop eax

    ; restore old call frame
    mov esp, ebp
    pop ebp
    ret

global x86_Disk_Reset
x86_Disk_Reset:
    [bits 32]

    ; make new call frame
    push ebp             ; save old call frame
    mov ebp, esp          ; initialize new call frame


    x86_EnterRealMode

    mov ah, 0
    mov dl, [bp + 8]    ; dl - drive
    stc
    int 13h

    mov eax, 1
    sbb eax, 0           ; 1 on success, 0 on fail   

    push eax

    x86_EnterProtectedMode

    pop eax

    ; restore old call frame
    mov esp, ebp
    pop ebp
    ret


global x86_Disk_Read
x86_Disk_Read:

    ; make new call frame
    push ebp             ; save old call frame
    mov ebp, esp          ; initialize new call frame

    x86_EnterRealMode

    ; save modified regs
    push ebx
    push es

    ; setup args
    mov dl, [bp + 8]    ; dl - drive

    mov ch, [bp + 12]    ; ch - cylinder (lower 8 bits)
    mov cl, [bp + 13]    ; cl - cylinder to bits 6-7
    shl cl, 6
    
    mov al, [bp + 16]    ; cl - sector to bits 0-5
    and al, 3Fh
    or cl, al

    mov dh, [bp + 20]   ; dh - head

    mov al, [bp + 24]   ; al - count

    LinearToSegOffset [bp + 28], es, ebx, bx

    ; call int13h
    mov ah, 02h
    stc
    int 13h

    ; set return value
    mov eax, 1
    sbb eax, 0           ; 1 on success, 0 on fail   

    ; restore regs
    pop es
    pop ebx

    push eax

    x86_EnterProtectedMode

    pop eax

    ; restore old call frame
    mov esp, ebp
    pop ebp
    ret
