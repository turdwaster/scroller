*=$0801
!byte $0c,$08,$b5,$07,$9e,$20,$32,$30,$36,$32,$00,$00,$00

main:
    lda #$10
    sta charBank
    lda #7
    sta scrollX
    lda #0
    sta scrollWorkPtr
    sta levelPos
    lda #256-8        ; Start at -8 to be at zero after preScrollWork is finished
    sta animFrame
    jsr copyBacking
    jsr resetAnims
    jsr resetPlayer
    
install:
    SEI
    LDA #%01111111      ; switch off interrupt signals from CIA-1
    STA $DC0D

    AND $D011           ; clear most significant bit of VIC's raster register
    STA $D011
    STA $DC0D           ; acknowledge pending interrupts from CIA-1/2
    STA $DD0D

    lda #$01            ; enable raster interrupt only
    sta $d01a

    LDA #250          ; set rasterline where interrupt shall occur
    STA $D012
    lda #<irq
    sta $0314
    lda #>irq
    sta $0315
    cli
    rts

topIrq:
    lsr $d019           ; Raster interrupt <=> C = 1
    lda $d016           ; Clear X scroll for scoreboard
    and #255-15
    sta $d016

    lda #0
    sta $d021
    LDA #250
    STA $D012
    lda #<irq
    sta $0314
    jmp $ea81

irq:
    lsr $d019           ; Raster interrupt <=> C = 1
    lda #0
    sta $d020
    lda #6
    sta $d021

    LDA #242
    STA $D012
    lda #<topIrq
    sta $0314
    jsr skipandhop

exitirq:
    ;lda #0
    ;sta $d020

    ; Display current scroll worker step while marking end-of-preScrollWorkStart raster line
    lda scrollWorkPtr
    sec
    sbc #scrollWorkStart-preScrollWorkStart
    lsr
    ldx #0
    jsr debugg

    lda activeSpawn
    ldx #2
    jsr debugg

    lda activeAnim
    ldx #4
    jsr debugg
    jmp $ea81

skipandhop:
    inc animFrame       ; Run animations on odd frames (avoid doing anything at time of moveColorsAndSwap)
    lda animFrame
    and #1
    beq skipAnimate

    jsr checkPlayerMovement ; Defined in player.asm
    jsr animate         ; Defined in anim.asm

skipAnimate:
    jsr moveSprites     ; Defined in anim.asm

    lda scrollSpeed
    bne shouldScroll
    lda scrollX         ; scrollX = 0: at screen swap step (moveColorsAndSwap)
    beq shouldScroll    ; Char anims were swapped in prev. step so force swap to match anim targets

    lda $d016           ; Not scrolling; set X shift and clear scroll speed
    and #255-15
    ora scrollX
    sta $d016
    rts

shouldScroll:
    dec scrollX         ; Move one pixel to the left
    bpl xOk
    lda #7              ; Reset scroll
    sta scrollX
xOk:                    ; Set scroll x
    lda $d016
    and #255-15
    ora scrollX
    sta $d016
    jmp scrollLeft      ; Defined in scroll.asm

;;;;;;;;;;;;; Start out-of-line, cold code ;;;;;;;;;;;;;

copyBacking:
    ; Set back buffer to front shifted one char left (ABCDEF -> BCDEF-)
    ldx #CHARSPERROW-1
backingNext:
    !for r, 0, CHARLINES-1 {
        lda scr0 + r * CHARSPERROW + 1,x
        sta scr1 + r * CHARSPERROW + 0,x
    }
    dex
    bmi backingDone
    jmp backingNext

backingDone:
    ; Clear bottom row
    ldx #CHARSPERROW-1
    lda #32
clearMore:
    sta scr1 + CHARLINES * CHARSPERROW,x
    dex
    bpl clearMore

    ; Add first level column to back buffer (BCDEF- -> BCDEFX)
    ldy #0
    !for r, 0, CHARLINES-1 {
        lda level + r * LEVELWIDTH,y
        sta scr1 + r * CHARSPERROW + (CHARSPERROW - 1)
    }
    rts

debugg:
    clc
    adc #48
    cmp #48 + 10
    bcc okNum
    sbc #57 ; Carry is already set here
okNum:
    sta scr0 + 40 * CHARLINES + 2, x
    sta scr1 + 40 * CHARLINES + 2, x
    lda #1
    sta VIC_COLMEM + 40 * CHARLINES + 2, x
    rts
