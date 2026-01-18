chunks = 4
rowsPerChunk = 6
chunkSize = CHARSPERROW * rowsPerChunk

!if 0 {
initCharset:
    lda #$33
    sta $01
    ldx #$00
copyLoop:
    lda $D000,x             ; read from character ROM
    sta $3800,x             ; write to RAM
    lda $D100,x
    sta $3900,x
    lda $D200,x
    sta $3a00,x
    lda $D300,x
    sta $3b00,x
    lda $D400,x
    sta $3c00,x
    lda $D500,x
    sta $3d00,x
    lda $D600,x
    sta $3e00,x
    lda $D700,x
    sta $3f00,x
    inx
    bne copyLoop
    lda #$37
    sta $01
    rts
}

scrollLeft:
    ldy scrollWorkPtr
    iny                 ; Skip to next preScrollWorkStart item
    iny
    cpy #scrollWorkEnd-preScrollWorkStart
    bne stillWorkToDo
    ldy #scrollWorkStart - preScrollWorkStart
stillWorkToDo:
    sty scrollWorkPtr

    ; Execute current scroll preScrollWorkStart item (jmp -> "our" rts)
    lda preScrollWorkStart - 2 + 1,y ; -2 since predecremented, +1 since hi byte first
    beq scrollWorkDone
    sta zpTmpHi
    lda preScrollWorkStart - 2 + 0,y
    sta zpTmp
    jmp (zpTmp)
scrollWorkDone:
    rts

    !macro moveAChunk .scr,.c,.step {
        .startChr = .scr + .c * chunkSize
        ldx #0
.chunkNext:
        !for r, 0, rowsPerChunk-1 {
            lda .startChr + r * CHARSPERROW + .step,x
            sta .startChr + r * CHARSPERROW,x
        }
        inx
        cpx #CHARSPERROW - .step
        beq .chunkDone
        jmp .chunkNext
.chunkDone:
        rts
    }

moveChunk1:
    !for c, 0, chunks-1 {
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
    !for c, 0, chunks-1 {
        +moveAChunk scr1, c, 2
    }

moveColorsAndSwap:
    lda charBank        ; Swap frame scr0/scr1
    eor #$80
    sta charBank
    lda VIC_MEMCFG
    and #15
    ora #14
    ora charBank
    sta VIC_MEMCFG

moveColors:
    ldx #0 ; Move top half of color mem (beam chasing needed!)
colorNext:
    !for r, 0, CHARLINES/2-1  {
        lda VIC_COLMEM + r * CHARSPERROW + 1,x
        sta VIC_COLMEM + r * CHARSPERROW,x
    }
    inx
    cpx #CHARSPERROW - 1
    bne colorNext
someColorsDone:
    ; Add new color column from level data for top half
    ldy levelPos
    !for r, 0, CHARLINES/2-1  {
        lda level + r * LEVELWIDTH,y
        tax
        lda charColors,x
        sta VIC_COLMEM + r * CHARSPERROW + (CHARSPERROW - 1)
    }
    ldx #0 ; Now do bottom half
colorNext2:
    !for r, CHARLINES/2, CHARLINES-1  {
        lda VIC_COLMEM + r * CHARSPERROW + 1,x
        sta VIC_COLMEM + r * CHARSPERROW,x
    }
    inx
    cpx #CHARSPERROW - 1
    bne colorNext2
colorsDone:
    ldy levelPos
    !for r, CHARLINES/2, CHARLINES-1  {
        lda level + r * LEVELWIDTH,y
        tax
        lda charColors,x
        sta VIC_COLMEM + r * CHARSPERROW + (CHARSPERROW - 1)
    }
    rts

fillColumn1:
    ldy levelPos
    .fillWidth = 2
    !for r, 0, CHARLINES-1 {
        lda level + r * LEVELWIDTH + 0,y
        sta scr0 + r * CHARSPERROW + (CHARSPERROW - .fillWidth) + 0
    }
    !for r, 0, CHARLINES-1 {
        lda level + r * LEVELWIDTH + 1,y
        sta scr0 + r * CHARSPERROW + (CHARSPERROW - .fillWidth) + 1
    }
    rts

fillColumn2:
    ldy levelPos
    !for r, 0, CHARLINES-1 {
        lda level + r * LEVELWIDTH + 0,y
        sta scr1 + r * CHARSPERROW + (CHARSPERROW - .fillWidth) + 0
    }
    !for r, 0, CHARLINES-1 {
        lda level + r * LEVELWIDTH + 1,y
        sta scr1 + r * CHARSPERROW + (CHARSPERROW - .fillWidth) + 1
    }
    rts

bumpLevelPtr:
    ldy levelPos
    iny
    ; Let it loop baby
    cpy #LEVELWIDTH-1
    bne stillHazLevel
    ldy #0
stillHazLevel:
    sty levelPos
    rts

; At start: copy + shift back buffer (LEVELPTR = X) and run preScrollWork
preScrollWorkStart:
    !word 0 ;                            [ABCDEF]    [BCDEFX]
    !word 0 ;                               |           |
    !word 0 ;                               |           |
    !word 0 ;                               |           |
    !word 0 ;                               |           |
    !word 0 ;                               |           |
    !word animSwap ;                        |           |
    !word moveColorsAndSwap ;            [ABCDEF] -> [BCDEFX]

scrollWorkStart: ;                       [ABCDEF]    [BCDEFX]
    !word moveChunk1 + moveChunkLen * 0 ;[ .... ]       |
    !word moveChunk1 + moveChunkLen * 1 ;[ .... ]       |
    !word moveChunk1 + moveChunkLen * 2 ;[ .... ]       |
    !word moveChunk1 + moveChunkLen * 3 ;[CDEF--]       |
    !word fillColumn1 ;                  [CDEFXY]       |     (LVLPTR = X)
    !word bumpLevelPtr ;                     |          |     LVLPTR -> Y
    !word animSwap ;                         |          |
    !word moveColorsAndSwap ;            [CDEFXY] <- [BCDEFX]
;                                            |          |
    !word moveChunk2 + moveChunkLen * 0 ;    |       [ .... ]
    !word moveChunk2 + moveChunkLen * 1 ;    |       [ .... ]
    !word moveChunk2 + moveChunkLen * 2 ;    |       [ .... ]
    !word moveChunk2 + moveChunkLen * 3 ;    |       [DEFX--]
    !word fillColumn2 ;                      |       [DEFXYZ] (LVLPTR = Y)
    !word bumpLevelPtr ;                     |          |     LVLPTR -> Z
    !word animSwap ;                         |          |
    !word moveColorsAndSwap ;            [CDEFXY] -> [DEFXYZ]
scrollWorkEnd:
