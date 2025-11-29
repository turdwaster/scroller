playerSpriteIdx = 7
playerColor = SPRITE_COLOR + playerSpriteIdx
playerStartX = 256 + 56 + 24 - 160 - 12
playerX = SPRITE_X + playerSpriteIdx*2
playerDX = sprite_dx + playerSpriteIdx*2
playerDY = sprite_dy + playerSpriteIdx*2
playerFlags = sprite_flags + playerSpriteIdx*2
playerBit = 1 << playerSpriteIdx

PLAYER_RSCROLLX = XSTARTRIGHT - 72 ; Position at which player stops and screen scrolls right

resetPlayer:
    lda #7              ; Spawn player sprite (TODO: overlap with spawnStuff...)
    sta freeSprite
    lda #0
    sta playerFlags
    jsr spawnStuff

    lda SPRITE_X_MSB           ; Set x MSB
	and #255 - playerBit
	sta SPRITE_X_MSB
    lda #playerStartX  ; Go to start position since default spawn is outside screen
    sta playerX

    lda #14
    sta playerColor    ; Remove when supported by spawn or stop using spawn...
    rts

checkPlayerMovement:
    lda $dc00
    lsr
    bcs noUpJoy
    ldy #255
    lsr
    jmp setPlayerDy

noUpJoy:
    lsr
    bcs noDownJoy
    ldy #1
    jmp setPlayerDy

noDownJoy:
    ldy #0
setPlayerDy:
    sty playerDY

    lsr
    bcs noLeftJoy
    ldy #255
    lsr
    jmp setPlayerDx

noLeftJoy:
    lsr
    bcs noRightJoy

    tay                 ; Check right side limit of player; scroll if trying to go right
    lda SPRITE_X_MSB
    and #playerBit
    beq notAtRight
    lda playerX
    cmp #PLAYER_RSCROLLX & 255
    bcc notAtRight
    lda #1
    sta playerDX
    ldx #255
    jmp setScrollSpeed

notAtRight:
    tya
    ldy #1
    jmp setPlayerDx

noRightJoy:
    ldy #0
setPlayerDx:
    sty playerDX

checkButton:
    ldx #255
    lsr
    bcc setScrollSpeed
    ldx #0

setScrollSpeed: 
    stx scrollSpeed
    rts
