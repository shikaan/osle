OUTPUT_FORMAT(binary)
OUTPUT_ARCH(i8086)

SECTIONS
{
    . = 0x0000;
    
    .text : {
        *(.text.prologue)
        *(.text.epilogue)
    }
    
    .rodata : {
        *(.rodata)
        *(.rodata.*)
    }
    
    .data : {
        *(.data)
        *(.data.*)
    }
    
    /DISCARD/ : {
        *(.eh_frame)
        *(.eh_frame_hdr)
        *(.comment)
        *(.note.*)
        *(.got)
        *(.got.plt)
        *(.gnu.hash)
    }
}
