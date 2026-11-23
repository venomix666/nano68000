.section .text.entry, "ax", @progbits
        .globl _start
        .equ SDRAM_STACK_TOP, 0x00180000

_start:
        move.l  %sp, %d0
        move.l  #SDRAM_STACK_TOP, %sp
        move.l  %d0, -(%sp)
        movem.l %d1-%d7/%a0-%a6, -(%sp)
        bsr.w   c_entry
        movem.l (%sp)+, %d1-%d7/%a0-%a6
        move.l  (%sp)+, %d0
        move.l  %d0, %sp
        rts
