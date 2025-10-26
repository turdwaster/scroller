scr0 = $0400
scr1 = $2400
colmem = $d800
charsPerRow = 40
levelWidth = 20
lines = 24
chunks = 4
rowsPerChunk = 6
chunkSize = charsPerRow * rowsPerChunk

; Bytes
LEVELPOS = $fb
SCROLLX = $fc
SCROLLWORKPTR = $fd
CHARBANK = $fe

*=$0801
!byte $0c,$08,$b5,$07,$9e,$20,$32,$30,$36,$32,$00,$00,$00

main:
    lda #$10
    sta CHARBANK
    lda #7
    sta SCROLLX
    lda #0
    sta SCROLLWORKPTR
    lda #0
    sta LEVELPOS
    jsr copyBacking

install:
    sei
    LDA #%01111111      ; switch off interrupt signals from CIA-1
    STA $DC0D

    AND $D011           ; clear most significant bit of VIC's raster register
    STA $D011

    STA $DC0D           ; acknowledge pending interrupts from CIA-1
    STA $DD0D           ; acknowledge pending interrupts from CIA-2

    lda #$01            ; enable raster interrupt only
    sta $d01a

    LDA #250        ; set rasterline where interrupt shall occur (251 = start of lower border)
    STA $D012           ; 53266
    lda #<irq           ; set IRQ vector low byte
    sta $0314
    lda #>irq           ; set IRQ vector high byte
    sta $0315
    cli
    rts

topIrq:
    lda #$01
    sta $d019

    lda $d016
    and #255-15
    sta $d016

    lda #0
    sta $d021
    LDA #250
    STA $D012
    lda #<irq
    sta $0314
    lda #>irq
    sta $0315
    jmp $ea81

irq:
    lda #$01
    sta $d019
    lda #0
    sta $d020
    lda #6
    sta $d021

    LDA #242
    STA $D012
    lda #<topIrq
    sta $0314
    lda #>irq
    sta $0315

    jsr skipandhop

exitirq:
    ;lda #11
    ;sta $d020

    ; Display current scroll worker step while marking end-of-preScrollWorkStart raster line
    lda SCROLLWORKPTR
    sec
    sbc #scrollWorkStart-preScrollWorkStart
    lsr
    ldx #0
    jsr debugg

    lda #0
    sta $d020
    jmp $ea81

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

    ldy SCROLLWORKPTR   ; Execute current scroll preScrollWorkStart item
    lda preScrollWorkStart,y
    sta trampo + 1
    lda preScrollWorkStart+1,y
    sta trampo + 2
trampo:
    jsr 0
    
    ldy SCROLLWORKPTR
    iny                 ; Skip to next preScrollWorkStart item
    iny
    cpy #scrollWorkEnd-preScrollWorkStart
    bne stillWorkToDo
    ldy #scrollWorkStart - preScrollWorkStart
stillWorkToDo:
    sty SCROLLWORKPTR
    rts

    !macro moveAChunk .scr,.c,.step {
        .startChr = .scr + (.c - 1) * chunkSize
        ldx #0
.chunkNext:
        !for r, rowsPerChunk {
            lda .startChr + (r - 1) * charsPerRow + .step,x
            sta .startChr + (r - 1) * charsPerRow,x
        }
        inx
        cpx #charsPerRow - .step
        beq .chunkDone
        jmp .chunkNext
.chunkDone:
        rts
    }

moveChunk1:
    !for c, chunks {
        !zone {
            .cstart = *
            +moveAChunk scr0, c, 2
            !if c = 1 {
                ; Take first size of moveAChunk as shared size for all instances
                moveChunkLen = (* - .cstart)
            }
        }
    }

moveChunk2:
    !for c, chunks {
        +moveAChunk scr1, c, 2
    }

moveColorsAndSwap:
    lda CHARBANK        ; Swap frame scr0/scr1
    eor #$80
    sta CHARBANK
    lda $d018
    and #15
    ora CHARBANK
    sta $d018

moveColors:
    .half = lines/2

    ; Add new color column from level data
    ldy LEVELPOS
    !for r, .half  {
        lda level + (r - 1) * levelWidth - 1,y
        sta colmem + (r - 1) * charsPerRow + (charsPerRow - 1)
    }

    ldx #0
colorNext:
    !for r, .half  {
        lda colmem + (r - 1) * charsPerRow + 1,x
        sta colmem + (r - 1) * charsPerRow,x
    }
    inx
    cpx #charsPerRow - 1
    beq someColorsDone
    jmp colorNext

someColorsDone:
    ; Add new color column from level data
    ldy LEVELPOS
    !for r, .half  {
        lda level + (r + .half - 1) * levelWidth - 1,y
        sta colmem + (r + .half - 1) * charsPerRow + (charsPerRow - 1)
    }

    ldx #0
colorNext2:
    !for r, .half  {
        lda colmem + (r + .half - 1) * charsPerRow + 1,x
        sta colmem + (r + .half - 1) * charsPerRow,x
    }
    inx
    cpx #charsPerRow - 1
    beq colorsDone
    jmp colorNext2
colorsDone:

noWork:
    rts

fillColumn1:
    ldy LEVELPOS
    .fillWidth = 2
    !for r, lines  {
        lda level + (r - 1) * levelWidth + 0,y
        sta scr0 + (r - 1) * charsPerRow + (charsPerRow - .fillWidth) + 0
    }
    !for r, lines  {
        lda level + (r - 1) * levelWidth + 1,y
        sta scr0 + (r - 1) * charsPerRow + (charsPerRow - .fillWidth) + 1
    }
    rts

fillColumn2:
    ldy LEVELPOS
    !for r, lines  {
        lda level + (r - 1) * levelWidth + 0,y
        sta scr1 + (r - 1) * charsPerRow + (charsPerRow - .fillWidth) + 0
    }
    !for r, lines  {
        lda level + (r - 1) * levelWidth + 1,y
        sta scr1 + (r - 1) * charsPerRow + (charsPerRow - .fillWidth) + 1
    }
    rts

bumpLevelPtr:
    ldy LEVELPOS
    iny
    ; Let it loop baby
    ;cpy #levelWidth-1
    ;bne stillHazLevel
    ;ldy #0
;stillHazLevel:
    sty LEVELPOS
    rts

; At start: copy + shift back buffer (LEVELPTR = X) and run preScrollWork

preScrollWorkStart:
    !word noWork ;                       [ABCDEF]    [BCDEFX]
    !word noWork ;                          |           |
    !word noWork ;                          |           |
    !word noWork ;                          |           |
    !word noWork ;                          |           |
    !word noWork ;                          |           |
    !word noWork ;                          |           |
    !word moveColorsAndSwap ;            [ABCDEF] -> [BCDEFX]

scrollWorkStart: ;                       [ABCDEF]    [BCDEFX]
    !word moveChunk1 + moveChunkLen * 0 ;[ .... ]       |
    !word moveChunk1 + moveChunkLen * 1 ;[ .... ]       |
    !word moveChunk1 + moveChunkLen * 2 ;[ .... ]       |
    !word moveChunk1 + moveChunkLen * 3 ;[CDEF--]       |
    !word fillColumn1 ;                  [CDEFXY]       |     (LVLPTR = X)
    !word bumpLevelPtr ;                     |          |     LVLPTR -> Y
    !word noWork ;                           |          |
    !word moveColorsAndSwap ;            [CDEFXY] <- [BCDEFX]
;                                            |          |
    !word moveChunk2 + moveChunkLen * 0 ;    |       [ .... ]
    !word moveChunk2 + moveChunkLen * 1 ;    |       [ .... ]
    !word moveChunk2 + moveChunkLen * 2 ;    |       [ .... ]
    !word moveChunk2 + moveChunkLen * 3 ;    |       [DEFX--]
    !word fillColumn2 ;                      |       [DEFXYZ] (LVLPTR = Y)
    !word bumpLevelPtr ;                     |          |     LVLPTR -> Z
    !word noWork ;                           |          |
    !word moveColorsAndSwap ;            [CDEFXY] -> [DEFXYZ]
scrollWorkEnd:

    !align 255, 0
level:
    !for r, lines  {
        !byte 0, 1, 2, 3, 4, 5
        !fill levelWidth - 6, 32
        ;!byte 1,4,1,13, 32, 9,19, 32, 1, 32, 19,5,1,12, 32,32,32,32, 32,32
    }
levelEnd:

;;;;;;;;;;;;; Start out-of-line, cold code ;;;;;;;;;;;;;

copyBacking:
    ; Set back buffer to front shifted one char left (ABCDEF -> BCDEF-)
    ldx #charsPerRow-1
backingNext:
    !for r, lines  {
        lda scr0 + (r - 1) * charsPerRow + 1,x
        sta scr1 + (r - 1) * charsPerRow + 0,x
    }
    dex
    bmi backingDone
    jmp backingNext

backingDone:
    ; Clear bottom row
    ldx #charsPerRow-1
    lda #32
clearMore:
    sta scr1 + lines * charsPerRow,x
    dex
    bpl clearMore

    ; Add first level column to back buffer (BCDEF- -> BCDEFX)
    ldy #0
    !for r, lines  {
        lda level + (r - 1) * levelWidth,y
        sta scr1 + (r - 1) * charsPerRow + (charsPerRow - 1)
    }
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
