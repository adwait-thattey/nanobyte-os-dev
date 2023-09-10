org 0x7C00  ; The bios loads the code at location 7C00 so tell the assembler to set this as the offset so that remaining addresses will start from here

bits 16  ; Tells the assembler to emit 16 bit code. We can use 16/32/64. But all x86 CPUs are backward compatible. 16bit is easier to write

main:
	hlt ; make the cpu halt. 

; sometimes the CPU may start executing again after halt. SO make a label and loop back to it. 

.halt:
	jmp .halt


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
