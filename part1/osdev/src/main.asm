org 0x7C00  ; The bios loads the code at location 7C00 so tell the assembler to set this as the offset so that remaining addresses will start from here
bits 16  ; Tells the assembler to emit 16 bit code. We can use 16/32/64. But all x86 CPUs are backward compatible. 16bit is easier to write

%define ENDL 0x0D, 0x0A

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
	call puts

	hlt ; make the cpu halt. 

; sometimes the CPU may start executing again after halt. SO make a label and loop back to it. 

.halt:
	jmp .halt

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
