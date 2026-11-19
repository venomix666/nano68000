UART_BASE       equ     $800000
UART_DATA       equ     UART_BASE+$0
UART_TX_READY   equ     UART_BASE+$2
TX_READY_BIT    equ     0

        org     $000000

        dc.l    $011000         ; initial SSP inside RAM ($010000+), grows downward
        dc.l    start           ; initial PC -> $000008

        org     $000008
        
start:
        move.b  #'H',d0
        jsr     uart_tx_byte
        move.b  #'e',d0
        jsr     uart_tx_byte
        move.b  #'l',d0
        jsr     uart_tx_byte
        move.b  #'l',d0
        jsr     uart_tx_byte
        move.b  #'o',d0
        jsr     uart_tx_byte

loop:
        jsr     s0
        bra.s   loop

s0:
        addq.l  #1,d0
        eor.w   d1,d0
        rts

uart_tx_byte:
.wait_tx:
    btst    #TX_READY_BIT,UART_TX_READY
    beq.s   .wait_tx
    move.b  d0,UART_DATA
    rts
