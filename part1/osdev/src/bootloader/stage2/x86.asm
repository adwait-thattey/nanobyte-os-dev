bits 16

section _TEXT class=CODE    ;; we want to put this file in the TEXT section of CODE class (see linker class)

;
; U4D
;
; Operation:      Unsigned 4 byte divide
; Inputs:         DX;AX   Dividend
;                 CX;BX   Divisor
; Outputs:        DX;AX   Quotient
;                 CX;BX   Remainder
; Volatile:       none
;
global __U4D
__U4D:
    shl edx, 16         ; dx to upper half of edx
    mov dx, ax          ; edx - dividend
    mov eax, edx        ; eax - dividend
    xor edx, edx

    shl ecx, 16         ; cx to upper half of ecx
    mov cx, bx          ; ecx - divisor

    div ecx             ; eax - quot, edx - remainder
    mov ebx, edx
    mov ecx, edx
    shr ecx, 16

    mov edx, eax
    shr edx, 16

;
; U4M
; Operation:      integer four byte multiply
; Inputs:         DX;AX   integer M1
;                 CX;BX   integer M2
; Outputs:        DX;AX   product
; Volatile:       CX, BX destroyed
;
global __U4M
__U4M:
    shl edx, 16         ; dx to upper half of edx
    mov dx, ax          ; m1 in edx
    mov eax, edx        ; m1 in eax

    shl ecx, 16         ; cx to upper half of ecx
    mov cx, bx          ; m2 in ecx

    mul ecx             ; result in edx:eax (we only need eax)
    mov edx, eax        ; move upper half to dx
    shr edx, 16

    ret


global _x86_div64_32
_x86_div64_32:

    ; make new call frame
    push bp             ; save old call frame
    mov bp, sp          ; initialize new call frame

    push bx

    ; divide upper 32 bits
    mov eax, [bp + 8]   ; eax <- upper 32 bits of dividend
    mov ecx, [bp + 12]  ; ecx <- divisor
    xor edx, edx
    div ecx             ; eax - quot, edx - remainder

    ; store upper 32 bits of quotient
    mov bx, [bp + 16]
    mov [bx + 4], eax

    ; divide lower 32 bits
    mov eax, [bp + 4]   ; eax <- lower 32 bits of dividend
                        ; edx <- old remainder
    div ecx

    ; store results
    mov [bx], eax
    mov bx, [bp + 18]
    mov [bx], edx

    pop bx

    ; restore old call frame
    mov sp, bp
    pop bp
    ret



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

;; bool _cdecl x86_Disk_Reset(uint8_t drive);
global _x86_Disk_Reset  ;; export it
_x86_Disk_Reset:
    ;; create a new frame
    push bp
    mov bp, sp

    ;; for input ah=00h, dl is drive
    ;; ax will return a bool success/failure
    ;; no need to save ah or dl because cdecl calling convention makes caller save it

    mov ah, 00h
    mov dl, [bp + 4]        ;; same as previous func, args start from bp+4

    stc     ;; reset the carry flag
    int 13h     ;; carry flag (CF) will be set on error, clear if successful

    mov ax, 1
    sbb ax, 0       ;; sbb instruction is subtract with borrow. borrow value is picked from carry flag (CF)
                    ;; Thus this expression is essentially ax = ax - (0 + CF) => ax = ax - CF
                    ;; Thus ax = 1: success. Ax=0: failure

    ;; restore previous frame
    mov sp, bp
    pop bp
    ret


;;  bool _cdecl x86_Disk_Read(  uint8_t drive, uint16_t cylinder, uint16_t sector, 
;;                              uint16_t head, uint8_t count, uint8_t far * dataOut);
global _x86_Disk_Read  ;; export it
_x86_Disk_Read:
    ;; create a new frame
    push bp
    mov bp, sp

    ;; interrupt is 13/ ah=02
    ;;  Arguments are:
    ;;  AH=02h, AL=number of sectors to read, 
    ;;  CH = lower 8 bits of cylinder number, CL: bits 0-5: sector number, bits 6-7: upper 2 bits of cylinder
    ;;  DH = head number , Dl = drive number
    ;;  ES:BX = data buffer
    ;;

    ;; save regs being used
    push bx
    push es

    ;; argument list
    ;; bp + 4: drive , +6: cylinder, +8: head, +10: sector, +12: count, +14: buffer

    mov dl, [bp + 4] ;; drive

    ;; cylinder
    mov ch, [bp + 6]    ; lower 8 bits (we are in little endian. So lower 8 bits are before upper 8 bits in stack)
    mov cl, [bp + 7]    ; copy full upper 8 bits. but we need only upper 2 bits so shift left by 6
    shl cl, 6

    mov dh, [bp + 10]    ; head

    ;; sector number. Bits 0-5 of Cl represent the sector number. So copy then take an & with 00111111 (x3F) to ensure only bits 0-5 survive 
    mov al, [bp + 8]; temp copy to al
    and al, 3Fh
    or cl, al; now bits 0-5 of cl are sector num and bits 6-7 are cylinder

    mov al, [bp + 12] ; count

    ;; output buffer: it is a far pointer. So is the size of a double (4 bytes)
    ;; first move higher 8 bits into es. then lower 8 bits into bx
    mov bx, [bp + 16]   ; 
    mov es, bx
    mov bx, [bp + 14]

    ;; call int
    mov ah, 02h
    stc
    int 13h

    ;; return
    mov ax, 1
    sbb ax, 0   ;; check reset func for how this works

    ;; restore saved regs
    pop es
    pop bx

    ;; restore previous frame
    mov sp, bp
    pop bp
    ret


; bool _cdecl x86_Disk_GetDriveParams(uint8_t drive, uint8_t* driveTypeOut, uint16_t* cylindersOut,
;                                    uint16_t* sectorsOut, uint16_t* headsOut);
global _x86_Disk_GetDriveParams
_x86_Disk_GetDriveParams:
    ;; create a new frame
    push bp
    mov bp, sp

    ;; interrupt is 13/ ah=08h
    ;;  Arguments are:
    ;;  AH=08h, DL= drive
    ;;  ES: DI = 0000h:0000h to guard against bios bugs
    ;;

    ;; cdecl convention preserves only ax, cx, dx. So save es and di
    push es
    push di
    push bx
    push si

    mov dl, [bp + 4]
    mov ah, 08h
    mov di, 0
    mov es, di
    stc
    int 13h

    ;; returns
    mov ax, 1
    sbb ax, 0   ;; check reset func for how this works

    ;; process out params

    ;; this is how out pointer params are processed. At address bp+6, we have 2nd param which is a uint8_t*
    ;; Thus [bp+6] is the pointer address
    ;; We copy this pointer address into si in first step
    ;; now copy bl into [si]
    ;; [si] essentially dereferences the pointer and sets value in the underlying variable
    mov si, [bp+6]
    mov [si], bl        ; bl contains drive type from intrrupt

    mov bl, ch  ; lower 8 bits of cylinder
    mov bh, cl  ; bits 7-6 of CL are 2 max bits of cylinder 
    shr bh, 6   ; now bits 0-1 of CH are upper bits of cylinder
    mov si, [bp+8]
    mov [si], bx

    xor ch, ch  ; first clear ch as we will copy whole cx later
    and cl, 3Fh ; 3F is 111111 ; Now CL only contains sectors number
    mov si, [bp+10]
    mov [si], cx

    mov cl, dh ; DH contains num heads. CH was already clearred earlier so we can safely copy CX to stack
    mov si, [bp+12]
    mov [si], cx

    ;; restore saved regs
    pop si
    pop bx
    pop di
    pop es


    ;; restore previous frame
    mov sp, bp
    pop bp
    ret
