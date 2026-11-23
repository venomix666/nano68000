ENTRY(_start)

SECTIONS
{
    . = 0x100000;
    .text : {
        *(.text.entry)
        *(.text .text.*)
    }
    .rodata : {
        . = ALIGN(2);
        *(.rodata .rodata.*)
    }
    .data : {
        . = ALIGN(2);
        *(.data .data.*)
    }
    .bss : {
        . = ALIGN(2);
        *(.bss .bss.* COMMON)
    }
}
