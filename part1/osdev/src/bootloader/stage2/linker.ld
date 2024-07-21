ENTRY(entry)
OUTPUT_FORMAT("binary")
phys = 0x00000500;  /* load at address 500 */

SECTIONS
{
    . = phys; /* from now on, use this physical address */

    /*
    We are creating variables for where each section starts
    rodata is section for read only data. constants, string literals reside here
    bss is uninitialized data. Basically global variables but those which are not initialized.
    Address specified for all is same. SO they will be writrten in the following order from the start
    */

    .entry              : { __entry_start = .;      *(.entry)   }
    .text               : { __text_start = .;       *(.text)    }
    .data               : { __data_start = .;       *(.data)    }
    .rodata             : { __rodata_start = .;     *(.rodata)  }
    .bss                : { __bss_start = .;        *(.bss)     }
    
    __end = .;
}