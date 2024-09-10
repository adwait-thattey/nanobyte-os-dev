[bits 32]

;; Check the onenote notebook for details on how we are planning to implement the assembly wrappers for ISR
;; https://onedrive.live.com/edit.aspx?resid=A5259C7E6DFB4C6F!1685&migratedtospo=true&wd=target%28Nanobyte%20OS%20Youtube%20series.one%7C8a3e1774-edb1-4849-86ee-1cf0c8c52b78%2FHandling%20Interrupts%20in%20Kernel%7C61514a6b-2ca2-428c-990f-8f071f347b1b%2F%29&wdorigin=703

;; This will be the C function that should be called for every interrupt
extern i686_ISR_Handler

global i686_ISR0:
i686_ISR0:
    push 0          ;; dummy error code
    push 0          ;; push interrupt number
    jmp isr_common

global i686_ISR1:
i686_ISR1:
    push 0          ;; dummy error code
    push 1          ;; push interrupt number
    jmp isr_common

;; -----

global i686_ISR8:
i686_ISR8:
    ;; ISR 8 also pushes an error code to the stack
    push 0          ;; dummy error code
    push 8          ;; push interrupt number
    jmp isr_common

;; ---- remaining ISRs till 256
isr_common:

    ;; before proceeding, store all registers so that we can freely use them later
    pusha

    ;;now push the current data segment
    xor eax, eax
    mov ax, ds
    push eax

    ;; make sure to set the data segment to kernel data segment
    mov ax, 0x10    ; In our GDT, we have null seg, code seg, data seg. 3rd entry wikll be found at 16 i.e. 0x10
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    push esp ;; pass a pointer to the stack to the C function
    call i686_ISR_Handler
    add esp, 4  ;; remove the top item from stack, i.e. the pushed esp

    pop eax ;; restore the old data segment
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax

    popa    ;; restore old registers
    add esp, 8  ;; remove the pushed error code and interrupt number
    iret





