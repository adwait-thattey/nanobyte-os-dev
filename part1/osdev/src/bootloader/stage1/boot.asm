org 0x7C00  ; The bios loads the code at location 7C00 so tell the assembler to set this as the offset so that remaining addresses will start from here
bits 16  ; Tells the assembler to emit 16 bit code. We can use 16/32/64. But all x86 CPUs are backward compatible. 16bit is easier to write

%define ENDL 0x0D, 0x0A

; Need to setup the header for FAT12 system
; Values set from here : https://wiki.osdev.org/FAT
; created a test FAT12 image to see what values each location should have

;
; FAT12 Header
;

;; BIOS Parameter Block

jmp short start									;The first 3 bytes are jump short and the address to start executing from, then a no-op
nop

bpb_oem:					db 'MSWIN4.1'		; 8bytes. This string is meaningless but for compatibility, MS recommends to set this value
bpb_bytes_per_sector:		dw 512				; 2 bytes
bpb_sectors_per_cluster:	db 1
bpb_n_reserved_clusters:	dw 1				; 2 bytes
bpb_fat_count:				db 2				; number of FATs on the media
bpb_root_dir_count:			dw 0E0h				; no of root dirs entries
bpb_total_sectors:			dw 2880				; floppy size is 1.44MiBs. 512 * 2880 = 1440 KBs
bpb_media_storage_des:		db 0F0h				; media descriptor type
bpb_sectors_per_fat:		dw 9
bpb_sectors_per_track:		dw 18
bpb_sides_on_media:			dw 2
bpb_hidden_sectors:			dd 0
bpb_large_sector_count:		dd 0

;; Extended boot record

ebr_drive_number:			db 0				; drive no is 0 for floppy disk; but meaningless as it is set by BIOS to DL on boot
ebr_win_flag:				db 0				; reserved flag for WINDOWS NT
ebr_sig:					db 029h
ebr_vol_id:					db 12h, 34h, 56h, 78h  ; 4 byte serial number. We can put anything
ebr_vol_label:				db 'NANOBYTE OS'		; 11 bytes; any label is fine but pad it to 11 bytes
ebr_system_id:				db 'FAT12   '			; 8 bytes; Pas with spaces


;; remaining is the boot code and signature





start:
    ; setup data segments
    mov ax, 0           ; can't set ds/es directly
    mov ds, ax
    mov es, ax

    ; setup stack
    mov ss, ax
    mov sp, 0x7C00              ; stack grows downwards from where we are loaded in memory

    ; some BIOSes might start us at 07C0:0000 instead of 0000:7C00, make sure we are in the
    ; expected location
    push es
    push word .after
    retf

.after:

    ; read something from floppy disk
    ; BIOS should set DL to drive number
    mov [ebr_drive_number], dl

    ; show loading message
    mov si, msg_loading
    call puts

    ; read drive parameters (sectors per track and head count),
    ; instead of relying on data on formatted disk
    push es
    mov ah, 08h
    int 13h
    jc floppy_error
    pop es

    and cl, 0x3F                        ; remove top 2 bits
    xor ch, ch
    mov [bpb_sectors_per_track], cx     ; sector count

    inc dh
    mov [bpb_sides_on_media], dh                 ; head count

    ; compute LBA of root directory = reserved + fats * sectors_per_fat
    ; note: this section can be hardcoded
    mov ax, [bpb_sectors_per_fat]
    mov bl, [bpb_fat_count]
    xor bh, bh
    mul bx                              ; ax = (fats * sectors_per_fat)
    add ax, [bpb_n_reserved_clusters]      ; ax = LBA of root directory
    push ax

    ; compute size of root directory = (32 * number_of_entries) / bytes_per_sector
    mov ax, [bpb_root_dir_count]
    shl ax, 5                           ; ax *= 32
    xor dx, dx                          ; dx = 0
    div word [bpb_bytes_per_sector]     ; number of sectors we need to read

    test dx, dx                         ; if dx != 0, add 1
    jz .root_dir_after
    inc ax                              ; division remainder != 0, add 1
                                        ; this means we have a sector only partially filled with entries
.root_dir_after:

    ; read root directory
    mov cl, al                          ; cl = number of sectors to read = size of root directory
    pop ax                              ; ax = LBA of root directory
    mov dl, [ebr_drive_number]          ; dl = drive number (we saved it previously)
    mov bx, buffer                      ; es:bx = buffer
    call disk_read

    ; search for kernel.bin
    xor bx, bx
    mov di, buffer

.search_kernel:
    mov si, file_kernel_bin
    mov cx, 11                          ; compare up to 11 characters
    push di
    repe cmpsb
    pop di
    je .found_kernel

    add di, 32
    inc bx
    cmp bx, [bpb_root_dir_count]
    jl .search_kernel

    ; kernel not found
    jmp kernel_not_found_error

.found_kernel:

    ; di should have the address to the entry
    mov ax, [di + 26]                   ; first logical cluster field (offset 26)
    mov [kernel_cluster], ax

    ; load FAT from disk into memory
    mov ax, [bpb_n_reserved_clusters]
    mov bx, buffer
    mov cl, [bpb_sectors_per_fat]
    mov dl, [ebr_drive_number]
    call disk_read

    ; read kernel and process FAT chain
    mov bx, KERNEL_LOAD_SEGMENT
    mov es, bx
    mov bx, KERNEL_LOAD_OFFSET

.load_kernel_loop:

    ; Read next cluster
    mov ax, [kernel_cluster]

    ; not nice :( hardcoded value
    add ax, 31                          ; first cluster = (kernel_cluster - 2) * sectors_per_cluster + start_sector
                                        ; start sector = reserved + fats + root directory size = 1 + 18 + 134 = 33
    mov cl, 1
    mov dl, [ebr_drive_number]
    call disk_read

    add bx, [bpb_bytes_per_sector]

    ; compute location of next cluster
    mov ax, [kernel_cluster]
    mov cx, 3
    mul cx
    mov cx, 2
    div cx                              ; ax = index of entry in FAT, dx = cluster mod 2

    mov si, buffer
    add si, ax
    mov ax, [ds:si]                     ; read entry from FAT table at index ax

    or dx, dx
    jz .even

.odd:
    shr ax, 4
    jmp .next_cluster_after

.even:
    and ax, 0x0FFF

.next_cluster_after:
    cmp ax, 0x0FF8                      ; end of chain
    jae .read_finish

    mov [kernel_cluster], ax
    jmp .load_kernel_loop

.read_finish:

    ; jump to our kernel
    mov dl, [ebr_drive_number]          ; boot device in dl

    mov ax, KERNEL_LOAD_SEGMENT         ; set segment registers
    mov ds, ax
    mov es, ax

    jmp KERNEL_LOAD_SEGMENT:KERNEL_LOAD_OFFSET

    jmp wait_key_and_reboot             ; should never happen

    cli                                 ; disable interrupts, this way CPU can't get out of "halt" state
    hlt


;
; Error handlers
;

floppy_error:
    mov si, msg_read_failed
    call puts
    jmp wait_key_and_reboot

kernel_not_found_error:
    mov si, msg_kernel_not_found
    call puts
    jmp wait_key_and_reboot

wait_key_and_reboot:
    mov ah, 0
    int 16h                     ; wait for keypress
    jmp 0FFFFh:0                ; jump to beginning of BIOS, should reboot

.halt:
    cli                         ; disable interrupts, this way CPU can't get out of "halt" state
    hlt


;
; Print a string tp the screen
; Parameters: DS:SI are expected to contain the start of the string buffer to print
;
puts:
	; save registers we will modify
	push si
	push ax

.loop:
	lodsb		; loads byte from ds:si into al and increments 1 byte
	or al, al	; if al contains 0, flag will be set which helps us check null condition
	jz .done

	mov ah, 0x0e  	; handle interrupt to print to tty
	mov bh, 0		; set page to 0
	int 0x10		; raise video interrupt

	jmp .loop

.done:

	pop ax
	pop si
	ret



; sometimes the CPU may start executing again after halt. SO make a label and loop back to it. 

;
; Disk IO routines
;

;
; Converts and LBA Address to a CHS address
; Params:
;	- ax : LBA Address
; Return:
;	- cx [bits 0-5]: sector number (lowest 6 bits)
;	- cx [bits 6-15]: cylinder     (remaining 10 bits) (in opp order, lower 8 bits of cylinder in 8-15 and higher 2 bits in 6-7)
;	- dh : head
;
;	Output is in this format because the disk read API requires this format

;Formula:
;	sector  = (LBA % sectors_per_track ) + 1
;	head = 	(LBA % sectors_per_track) % no_of_heads
;   cylinder = (LBA / sectors per track ) / no_of_heads
;

lba_to_chs:

	; before doing any operation. We must save registers that are not part of the output. i.e ax and dl
	; but we can not push and pop dl directly. So we push whole dx and later retrive only dl

	push ax
	push dx

	;;

	xor dx, dx							; dx = 0

	; the instruction div is used for unsigned data and idiv for signed
	; dividend is in ax, divisor is passed as argument (wither register or address)
	; result quotient is in ax and remainder in dx
	; ax already contains the LBA

	div word [bpb_sectors_per_track]	; ax = LBA / sectors_per_track , dx = LBA % sectors_per_track

	inc dx
	mov cx, dx							; cx now has sector number

	xor dx, dx
	div word [bpb_sides_on_media]		; ax = (LBA / sectors_per_track) / HEADS ;; dx = (LBA / sectors_per_tracl) % HEAD
										; cylinder now in ax, head is in dx

	mov dh, dl							; head was in dx, dl is the lower 8 bits of dx

	;; for cylinder, lower 6 bits of cx are sector number and remaining 10 bits are cylinder (in opp order, lower 8 bits of cylinder in 8-15 and higher 2 bits in 6-7)
	; cylinder is in ax. move from al to ch the lower 8 bits of cylinder. For upper 2 bits, first shift them by 6, then or with cl
	; note that cl alrady contains the head
	; instruction to shift left is shl

	mov ch, al
	shl ah, 6							; ax is now shifted by 6
	or cl,ah							; cl = cl OR ah  (remeber cx already contains sector number)

	;; restore the saved registers
	; pop earlier saved dx, but restore only dl

	pop ax
	mov dl, al
	pop ax

	ret


;
; Reads a sector from disk
; Parameters:
;	- ax: LBA Address
;	- cl: Number of sectors to read
;	- dl: Drive Number
;	- es:bx : Memory address where to store the read data

disk_read:

	; save all registers that will be modified

	push ax
	push bx
	push cx
	push dx
	push di

	; The 13,2 H interrupt does read on floppy. It needs CHS input,
	; which we should already get in required registers from the conversion function
	; We need to set AL to the number of sectors to read and should retry the read at least 3 times as floppys are unreliable

	push cx				; save cl (number of sectors to read)
	call lba_to_chs
	pop ax				; al = number of sectors to read. Cant just pop al

	mov ah, 02h			; 2h is read operation

 	mov di, 3			; retry read 3 times


.retry:

	pusha				; save all registers
	stc					; set carry flag explicitly
	
	int 13h				; if carry is cleared, means operation succeeded
	jnc .done
	
	; read failed
	popa
	call disk_reset		; reset disk controller

	dec di
	test di, di
	jnz .retry

.fail:
	; all attempts have failed

	jmp floppy_error
.done:
	popa

	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	
	ret


;
; Reset disk controller
; Parameter:
; dl: drive number
;
disk_reset:
	pusha
	mov ah, 0
	stc
	int 13h
	jc floppy_error
	popa
	ret

msg_loading:            db 'Loading...', ENDL, 0
msg_read_failed:        db 'Read from disk failed!', ENDL, 0
msg_kernel_not_found:   db 'STAGE2.BIN file not found!', ENDL, 0
file_kernel_bin:        db 'STAGE2  BIN'
kernel_cluster:         dw 0

KERNEL_LOAD_SEGMENT     equ 0x2000
KERNEL_LOAD_OFFSET      equ 0


; For signature BIOS expects last 2 bytes in 1st sector to be AA55
; We are using floppy format here which has 512 bytes in 1 sector. We will fill up 510 bytes then add the signature

; $ gives the offset of the current line.
; $$ gives the offset of the whole program.
; Thus $ - $$ will give the size of program till now.
; We will fill 0s from end of current program till 510th byte.
; db is an instruction to place a byte
; times is an instruction which allows to repeat other instruction

times 510 - ($ - $$) db 0

dw 0AA55h

buffer:
