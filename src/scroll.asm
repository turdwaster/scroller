scrollLeft:
    ldy SCROLLWORKPTR
    iny                 ; Skip to next preScrollWorkStart item
    iny
    cpy #scrollWorkEnd-preScrollWorkStart
    bne stillWorkToDo
    ldy #scrollWorkStart - preScrollWorkStart
stillWorkToDo:
    sty SCROLLWORKPTR

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
            lda .startChr + r * charsPerRow + .step,x
            sta .startChr + r * charsPerRow,x
        }
        inx
        cpx #charsPerRow - .step
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
    lda CHARBANK        ; Swap frame scr0/scr1
    eor #$80
    sta CHARBANK
    lda $d018
    and #15
    ora CHARBANK
    sta $d018

moveColors:
    ldx #0 ; Move top half of color mem (beam chasing needed!)
colorNext:
    !for r, 0, lines/2-1  {
        lda colmem + r * charsPerRow + 1,x
        sta colmem + r * charsPerRow,x
    }
    inx
    cpx #charsPerRow - 1
    bne colorNext
someColorsDone:
    ; Add new color column from level data for top half
    ldy LEVELPOS
    !for r, 0, lines/2-1  {
        lda level + r * levelWidth,y
        sta colmem + r * charsPerRow + (charsPerRow - 1)
    }
    ldx #0 ; Now do bottom half
colorNext2:
    !for r, lines/2, lines-1  {
        lda colmem + r * charsPerRow + 1,x
        sta colmem + r * charsPerRow,x
    }
    inx
    cpx #charsPerRow - 1
    bne colorNext2
colorsDone:
    ldy LEVELPOS
    !for r, lines/2, lines-1  {
        lda level + r * levelWidth,y
        sta colmem + r * charsPerRow + (charsPerRow - 1)
    }
    rts

fillColumn1:
    ldy LEVELPOS
    .fillWidth = 2
    !for r, 0, lines-1 {
        lda level + r * levelWidth + 0,y
        sta scr0 + r * charsPerRow + (charsPerRow - .fillWidth) + 0
    }
    !for r, 0, lines-1 {
        lda level + r * levelWidth + 1,y
        sta scr0 + r * charsPerRow + (charsPerRow - .fillWidth) + 1
    }
    rts

fillColumn2:
    ldy LEVELPOS
    !for r, 0, lines-1 {
        lda level + r * levelWidth + 0,y
        sta scr1 + r * charsPerRow + (charsPerRow - .fillWidth) + 0
    }
    !for r, 0, lines-1 {
        lda level + r * levelWidth + 1,y
        sta scr1 + r * charsPerRow + (charsPerRow - .fillWidth) + 1
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
