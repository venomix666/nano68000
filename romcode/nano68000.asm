        org     $000000

        dc.l    $011000         ; initial SSP inside RAM ($010000+), grows downward
        dc.l    start           ; initial PC -> $000008

        org     $000008
start:
        moveq   #0,d0
        moveq   #1,d1
loop:
        addq.l  #1,d0
        eor.w   d1,d0
        bra.s   loop
