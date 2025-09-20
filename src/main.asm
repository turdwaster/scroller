scr0 = $0400
scr1 = $2400
row = 40
lines = 25
chunks = 4
rowsPerChunk = 6
chunkSize = row * rowsPerChunk
SCROLLX = $fb
CHARBANK = $fc
SCROLLWORKPTR = $fd
DELAY = $fe
chrMoveAlign = 64

*=$0801
!byte $0c,$08,$b5,$07,$9e,$20,$32,$30,$36,$32,$00,$00,$00

main:
    lda #$10
    sta CHARBANK
    lda #7
    sta SCROLLX
    lda #0
    sta SCROLLWORKPTR
    sta DELAY
    jsr copyBacking

install:
    sei
    LDA #%01111111      ; switch off interrupt signals from CIA-1
    STA $DC0D

    AND $D011           ; clear most significant bit of VIC's raster register
    STA $D011

    STA $DC0D           ; acknowledge pending interrupts from CIA-1
    STA $DD0D           ; acknowledge pending interrupts from CIA-2

    LDA #170            ; set rasterline where interrupt shall occur (251 = start of lower border)
    STA $D012           ; 53266

    lda #<irq           ; set IRQ vector low byte
    sta $0314
    lda #>irq           ; set IRQ vector high byte
    sta $0315
    lda #$01            ; enable raster interrupt only
    sta $d01a
    cli
    rts

irq:
    lda #$01
    sta $d019
    lda #$01
    sta $d020

    inc DELAY
    lda DELAY
    cmp #40
    bne exitirq
    lda #0
    sta DELAY

skipandhop:
    dec SCROLLX         ; Move one pixel to the left
    bpl xOk

    lda #7              ; Reset scroll
    sta SCROLLX

xOk:                    ; Set scroll x
    lda $d016
    and #255-7
    ora SCROLLX
    sta $d016

debugg:
    lda SCROLLWORKPTR
    lsr
    clc
    cmp #9
    bcc okNum
    adc #65-48-10
okNum:
    adc #48
    sta $0400 + 40*24 + 2
    sta $2400 + 40*24 + 2
    lda #1
    sta $d800 + 40*24 + 2

    ldy SCROLLWORKPTR   ; Execute current scroll work item
    lda work,y
    sta trampo + 1
    lda work+1,y
    sta trampo + 2
trampo:
    jsr 0
    
    iny                 ; Skip to next work item
    iny
    cpy #endWork-work
    bne stillWorkToDo
    ldy #0
stillWorkToDo:
    sty SCROLLWORKPTR

exitirq:
    lda #$00
    sta $d020
    jmp $ea31 ; $EA81 = no other handling of IRQs

swap:
    lda CHARBANK        ; Swap frame $0400/$2400
    eor #$80
    sta CHARBANK
    lda $d018
    and #15
    ora CHARBANK
    sta $d018
    rts

    !macro moveAChunk .scr,.c {
        .startChr = .scr + (.c - 1) * chunkSize
        ldx #0
.chunkNext:
        !for r, rowsPerChunk {
            lda .startChr + (r - 1) * row + 1,x
            sta .startChr + (r - 1) * row,x
        }
        inx
        cpx #row - 1
        beq .chunkDone
        jmp .chunkNext
.chunkDone:        
        rts
    }

    !align chrMoveAlign - 1, 0

moveChunk:
    !for c, chunks {
        +moveAChunk scr0, c
        !align chrMoveAlign-1, 0
    }

moveChunk2:
    !for c, chunks {
        +moveAChunk scr1, c
        !align chrMoveAlign-1, 0
    }

moveColorsAndSwap:
    jsr swap

moveColors:
    ldx #0
colorNext:
    !for r, lines-1  {
        lda $d801 + (r - 1) * row,x
        sta $d800 + (r - 1) * row,x
    }
    inx
    cpx #row - 1
    beq colorsDone
    jmp colorNext
colorsDone:
    rts

work:
    !for c, chunks {
        !byte <(moveChunk2 + chrMoveAlign * (c-1)), >(moveChunk2 + chrMoveAlign * (c-1))
    }

    !for c, (7 - chunks) {
        !byte <colorsDone, >colorsDone
    }

    !byte <moveColorsAndSwap, >moveColorsAndSwap

    !for c, chunks {
        !byte <(moveChunk + chrMoveAlign * (c-1)), >(moveChunk + chrMoveAlign * (c-1))
    }

    !for c, (7 - chunks) {
        !byte <colorsDone, >colorsDone
    }

    !byte <moveColorsAndSwap, >moveColorsAndSwap
endWork:

copyBacking:
    ldx #0
copyMore:
    lda $0400,x
    sta $2400,x
    lda $0500,x
    sta $2500,x
    lda $0600,x
    sta $2600,x
    lda $0700,x
    sta $2700,x

    txa
    sta $d800,x
    dex
    bne copyMore
    rts
