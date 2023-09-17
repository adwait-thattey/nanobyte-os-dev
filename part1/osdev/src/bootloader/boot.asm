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

ebr_drive_number:			db 0				; drive no is 0 for floppy disk
ebr_win_flag:				db 0				; reserved flag for WINDOWS NT
ebr_sig:					db 029h
ebr_vol_id:					db 12h, 34h, 56h, 78h  ; 4 byte serial number. We can put anything
ebr_vol_label:				db 'NANOBYTE OS'		; 11 bytes; any label is fine but pad it to 11 bytes
ebr_system_id:				db 'FAT12   '			; 8 bytes; Pas with spaces


;; remaining is the boot code and signature





start:
	jmp main ;ensure that main is the entry point of our function

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

main:

	; setup data segments
	mov ax, 0 ; we cant dorectly write to ds/es
	mov ds, ax
	mov es, ax

	; setup the stack
	; the stack grows downwards. If we put it anywhere, it might start overwriting the OS code whne it grows. 
	; putting it at the start of OS memory is safe place as there is nothing before it
	mov ss, ax
	mov sp, 0x7C00

	; print the message. LOad address in ds:si and call the puts function
	mov si, msg_hello
	call puts

	hlt ; make the cpu halt.

; sometimes the CPU may start executing again after halt. SO make a label and loop back to it. 

.halt:
	jmp .halt

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
	mov cx dx							; cx now has sector number

	div word [bpb_sides_on_media]		; ax = (LBA / sectors_per_track) / HEADS ;; dx = (LBA / sectors_per_tracl) % HEAD
										; cylinder now in ax, head is in dx

	mov dh, dl							; head was in dx, dl is the lower 8 bits of dx

	;; for cylinder, lower 6 bits of cx are sector number and remaining 10 bits are cylinder (in opp order, lower 8 bits of cylinder in 8-15 and higher 2 bits in 6-7)
	; cylinder is in ax. move from al to ch the lower 8 bits of cylinder. For upper 2 bits, first shift them by 6, then or with cl
	; note that cl alrady contains the head
	; instruction to shift left is shl

	mov ch, al
	shl 6								; ax is now shifted by 6
	or cl,al							; cl = cl OR al  (remeber cx already contains sector number)

	;; restore the saved registers
	; pop earlier saved dx, but restore only dl

	pop ax
	mov dl, al
	pop ax

	ret


;
; Reads a sector from disk
;



msg_hello: db 'Hello world!', ENDL, 0		;; db writes to the memory and puts label msg_hello as reference to the memory

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
