OUTPUT_ARCH(m68k)
ENTRY(start)

MEMORY
{
    ROM (rx)  : ORIGIN = 0xFFE000, LENGTH = 8K
    RAM (rwx) : ORIGIN = 0xFE0000, LENGTH = 64K
}

SECTIONS
{
    .vectors :
    {
        KEEP(*(.vectors))
    } > ROM

    .text :
    {
        *(.text*)
        *(.rodata*)
    } > ROM

    .bss :
    {
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        __bss_end = .;
    } > RAM
}
