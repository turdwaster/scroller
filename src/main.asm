scr0 = $0400
scr1 = $2400
colmem = $d800
charsPerRow = 40
lines = 24
chunks = 4
rowsPerChunk = 6
chunkSize = charsPerRow * rowsPerChunk

; Pointers
LEVELDATA = $f8

; Bytes
SCROLLX = $fc
SCROLLWORKPTR = $fd
CHARBANK = $fe
DELAY = $ff
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
    lda #<level
    sta LEVELDATA
    lda #>level
    sta LEVELDATA+1
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
    cmp #20
    bne exitirq
    lda #0
    sta DELAY

    jsr skipandhop

exitirq:
    lda #$00
    sta $d020
    jmp $ea31 ; $EA81 = no other handling of IRQs

skipandhop:
    dec SCROLLX         ; Move one pixel to the left
    bpl xOk

    lda #7              ; Reset scroll
    sta SCROLLX

xOk:                    ; Set scroll x
    lda $d016
    and #255-15
    ora SCROLLX
    sta $d016

    lda SCROLLWORKPTR
    lsr
    ldx #0
    jsr debugg
    lda SCROLLWORKPTR
    lsr
    ldx #0
    jsr debugg

    ldy SCROLLWORKPTR   ; Execute current scroll work item
    lda work,y
    sta trampo + 1
    lda work+1,y
    sta trampo + 2
trampo:
    jsr 0
    
    ldy SCROLLWORKPTR
    iny                 ; Skip to next work item
    iny
    cpy #endWork-work
    bne stillWorkToDo
    ldy #0
stillWorkToDo:
    sty SCROLLWORKPTR
    rts

    !macro moveAChunk .scr,.c {
        .startChr = .scr + (.c - 1) * chunkSize
        ldx #0
.chunkNext:
        !for r, rowsPerChunk {
            lda .startChr + (r - 1) * charsPerRow + 2,x
            sta .startChr + (r - 1) * charsPerRow,x
        }
        inx
        cpx #charsPerRow - 2
        beq .chunkDone
        jmp .chunkNext
.chunkDone:
        rts
    }

    !align chrMoveAlign - 1, 0

moveChunk1:
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
    lda CHARBANK        ; Swap frame scr0/scr1
    eor #$80
    sta CHARBANK
    lda $d018
    and #15
    ora CHARBANK
    sta $d018

    ldx #0
colorNext:
    !for r, lines  {
        lda colmem + (r - 1) * charsPerRow + 1,x
        sta colmem + (r - 1) * charsPerRow,x
    }
    inx
    cpx #charsPerRow - 1
    beq colorsDone
    jmp colorNext
colorsDone:
noWork:
    rts

fillColumn1:
    ldy #0
    !for r, lines  {
        lda (LEVELDATA),y
        sta scr0 + (r - 1) * charsPerRow + (charsPerRow - 1)
        iny
    }
    rts

fillColumn2:
    ldy #0
    !for r, lines  {
        lda (LEVELDATA),y
        sta scr1 + (r - 1) * charsPerRow + (charsPerRow - 1)
        iny
    }
    rts

bumpLevelPtr:
    ; Advance level data pointer
    tya
    clc
    adc LEVELDATA
    sta LEVELDATA
    lda LEVELDATA+1
    adc #0
    sta LEVELDATA+1
    rts

; scr0      scr1
; ==================
;   ____
; |ABCDEF|  | ABCDE|
; 
; moveChunk2
;   ____
; |ABCDEF|  |BCDE  |
; 
; fillColumn2
; swap
;             ____
; |ABCDEF|  |BCDE X|
; 
; moveChunk1
;             ____
; |CDEF  |  |BCDE X|
; 
; fillColumn1
;             ____
; |CDEF X|  |ABCDEX|

work:
    !word moveChunk2
    !word moveChunk2 + chrMoveAlign * 1
    !word moveChunk2 + chrMoveAlign * 2
    !word moveChunk2 + chrMoveAlign * 3
    !word fillColumn2
    !word noWork
    !word noWork
    !word moveColorsAndSwap

    !word moveChunk1
    !word moveChunk1 + chrMoveAlign * 1
    !word moveChunk1 + chrMoveAlign * 2
    !word moveChunk1 + chrMoveAlign * 3
    !word fillColumn1
    !word bumpLevelPtr
    !word noWork
    !word moveColorsAndSwap
endWork:

copyBacking:
    ldx #charsPerRow-1
backingNext:
    !for r, lines  {
        lda scr0 + (r - 1) * charsPerRow,x
        sta scr1 + (r - 1) * charsPerRow + 1,x
    }
    dex
    bmi backingDone
    jmp backingNext
backingDone:
    rts

debugg:
    clc
    adc #48
    cmp #48 + 10
    bcc okNum
    sec
    sbc #57
okNum:
    sta scr0 + 40 * lines + 2, x
    sta scr1 + 40 * lines + 2, x
    lda #1
    sta colmem + 40 * lines + 2, x
    rts

level:
    !byte 1, 2, 3, 4, 5, 6
    !byte 1, 2, 3, 4, 5, 6
    !byte 1, 2, 3, 4, 5, 6
    !byte 1, 2, 3, 4, 5, 6
