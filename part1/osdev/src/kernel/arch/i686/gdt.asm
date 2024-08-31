[bits 32]

; void __attribute__((cdecl)) i686_GDT_Load(GDTDescriptor* descriptor, uint16_t codeSegment, uint16_t dataSegment);
global i686_GDT_Load
i686_GDT_Load:
    
    ; make new call frame
    push ebp             ; save old call frame
    mov ebp, esp         ; initialize new call frame
    
    ; load gdt
    mov eax, [ebp + 8] ;; old ebp is pushed to ebp and return address is at ebp+4
    lgdt [eax]

    ;; According to the protocol, after doing the lgdt, we need to modify segment registers. But the CS register can not be directly set and can only be modified by using a far jump or a far return. 
    ;; We can do a far jump but for that we will need to setup DS and SI registers firsty. Instead we are doing a trick here. Instead of far jump, we will do a far return (which has the same effect). 
    ;; Before calling retf, we will push the address for label reload_cs onto stack, 
    ;; then call a far return which should cause a jump to that label 
    ; reload code segment
    mov eax, [ebp + 12]
    push eax
    push .reload_cs
    retf

.reload_cs:

    ; code segment is not modified
    ; modify remaining segment registers to reload data segments
    mov ax, [ebp + 16]
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax,
    mov ss, ax

    ; restore old call frame
    mov esp, ebp
    pop ebp
    ret