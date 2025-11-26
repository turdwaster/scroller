*=$0801
!byte $0c,$08,$b5,$07,$9e,$20,$32,$30,$36,$32,$00,$00,$00

main:
    lda #$10
    sta CHARBANK
    lda #7
    sta SCROLLX
    lda #0
    sta SCROLLWORKPTR
    sta LEVELPOS
    lda #256-8        ; Start at -8 to be at zero after preScrollWork is finished
    sta ANIMFRAME
    jsr copyBacking
    jsr resetAnims

    lda #7              ; Spawn player sprite
    sta freeSprite
    jsr spawnStuff
    lda #0
    sta $d000 + 7*2
    
install:
    SEI
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
    lsr $d019           ; Raster interrupt <=> C = 1

    lda $d016
    and #255-15
    sta $d016

    lda #0
    sta $d021
    LDA #250
    STA $D012
    lda #<irq
    sta $0314
    ;lda #>irq          ; Assuming same page
    ;sta $0315
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
    ;lda #>topIrq          ; Assuming same page
    ;sta $0315
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

    lda anim_stepwait
    ldx #2
    jsr debugg

    lda anim_pc
    ldx #4
    jsr debugg

    lda #0
    sta $d020
    jmp $ea81

skipandhop:
    lda $dc00
    lsr
    bcs noUpJoy
    ldy #255
    jmp setPlayerDy

noUpJoy:
    lsr
    bcs noDownJoy
    ldy #1
    jmp setPlayerDy

noDownJoy:
    ldy #0
setPlayerDy:
    sty sprite_dy + 7*2

    lsr
    bcs noLeftJoy
    ldy #255
    jmp setPlayerDx

noLeftJoy:
    lsr
    bcs noRightJoy
    ldy #1
    jmp setPlayerDx

noRightJoy:
    ldy #0
setPlayerDx:
    sty sprite_dx + 7*2

checkButton:
    ldx #255           ; Assume scrolling left: X = scrollSpeed = -1 px/frame
    lsr
    bcc shouldScroll

    lda SCROLLX         ; SCROLLX = 0: at screen swap step (moveColorsAndSwap)
    beq shouldScroll    ; Char anims were swapped in prev. step so force swap to match anim targets

    lda $d016           ; Not scrolling; set X shift and clear scroll speed
    and #255-15
    ora SCROLLX
    sta $d016
    ldx #0

shouldScroll:
    stx scrollSpeed

doMovement:
    jsr moveSprites     ; Defined in anim.asm

    inc ANIMFRAME       ; Run animate on odd frames (try to avoid doing it at time of moveColorsAndSwap)
    lda ANIMFRAME
    and #1
    beq skipAnimate
    jsr animate         ; Defined in anim.asm

skipAnimate:
    lda scrollSpeed
    bne goAheadScroll
    rts

goAheadScroll:
    dec SCROLLX         ; Move one pixel to the left
    bpl xOk
    lda #7              ; Reset scroll
    sta SCROLLX

xOk:                    ; Set scroll x
    lda $d016
    and #255-15
    ora SCROLLX
    sta $d016
    jmp scrollLeft      ; Defined in scroll.asm

;;;;;;;;;;;;; Start out-of-line, cold code ;;;;;;;;;;;;;

copyBacking:
    ; Set back buffer to front shifted one char left (ABCDEF -> BCDEF-)
    ldx #charsPerRow-1
backingNext:
    !for r, 0, lines-1 {
        lda scr0 + r * charsPerRow + 1,x
        sta scr1 + r * charsPerRow + 0,x
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
    !for r, 0, lines-1 {
        lda level + r * levelWidth,y
        sta scr1 + r * charsPerRow + (charsPerRow - 1)
    }
    rts

debugg:
    clc
    adc #48
    cmp #48 + 10
    bcc okNum
    sbc #57 ; Carry is already set here
okNum:
    sta scr0 + 40 * lines + 2, x
    sta scr1 + 40 * lines + 2, x
    lda #1
    sta colmem + 40 * lines + 2, x
    rts
