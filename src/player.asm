playerSpriteIdx = 7
playerColor = SPRITE_COLOR + playerSpriteIdx
playerStartX = 256 + 56 + 24 - 160 - 12
playerX = SPRITE_X + playerSpriteIdx*2
playerY = SPRITE_Y + playerSpriteIdx*2
playerDX = sprite_dx + playerSpriteIdx*2
playerDY = sprite_dy + playerSpriteIdx*2
playerFlags = sprite_flags + playerSpriteIdx*2
playerBit = 1 << playerSpriteIdx
playerMapX = continueFlag
playerMapY = curPc
minDistY = zpTmp2

PLAYER_RSCROLLX = XSTARTRIGHT - 72 ; Position at which player stops and screen scrolls right
PLAYER_W = 24
PLAYER_H = 16
TOPEDGE = 50
LEFTEDGE = 24
GRAVITY_DELAY = 1

resetPlayer:
	lda #7									; Spawn player sprite (TODO: overlap with spawnStuff...)
	sta freeSprite
	lda #0
	sta playerFlags
	jsr spawnStuff

	lda SPRITE_X_MSB						; Set x MSB
	and #255 - playerBit
	sta SPRITE_X_MSB
	lda #playerStartX 						; Go to start position since default spawn is outside screen
	sta playerX

	lda #14
	sta playerColor 						; Remove when supported by spawn or stop using spawn...
	rts

checkPlayerMovement:
	lda $dc00
	lsr
	bcs noUpJoy

	ldy playerDY
	bmi checkRight							; Already moving up

	dey 									; Accelerate upward (max speed will be -1)
	; ldy #256 - 2                             ;  Alternative: jump boost
	sty playerDY
	jmp checkRight

noUpJoy:
	tax
	lda animFrame
	and #((1 << GRAVITY_DELAY) - 1) << 1       ; Only called for every other animFrame so mask must be << 1
	bne restoreJoyBits

	ldy playerDY
	bmi alwaysFall							; Not at max fall speed if moving up
	cpy #7
	bcs restoreJoyBits						; Already at max fall speed - stop accelerating

alwaysFall:
	inc playerDY							; Accelerate downward

restoreJoyBits:
	txa

checkRight:
	lsr
	bcs checkLeft
	ldy #1

checkLeft:
	lsr
	bcs noLeftJoy
	ldy #255
	lsr
	jmp setPlayerDx

noLeftJoy:
	lsr
	bcs noRightJoy

	tay 									; Check right side limit of player; scroll if trying to go right
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

	; Check button
	ldx #255
	lsr
	bcc setScrollSpeed
	ldx #0

setScrollSpeed:
	stx scrollSpeed
	rts

checkCollisions:
	lda playerX 							; Get and store actual tile relative player X
	sec
	sbc #LEFTEDGE
	sec
	sbc scrollX
	sta playerMapX

	lda playerY 							; Get on-screen relative top coord
	sec
	sbc #TOPEDGE
	sta playerMapY

	lsr
	lsr
	lsr
	tax
	lda rowStartLo, X 						; Set row start address
	sta zpTmp
	lda rowStartHi, X
	ora animateScrHi
	sta zpTmpHi

	lda playerMapX							; Find X target tile offset
	lsr
	lsr
	lsr

	clc 									; Adjust zpTmp from start of row to start of to leftmost tile
	adc zpTmp
	bcc xTileOffsetOk
	inc zpTmpHi
xTileOffsetOk:
	sta zpTmp

	; ZpTmp is now top left tile of player; start doing collision checks based on movement direction
	lda playerDY
	beq noDownMove							; No vertical movement = no floor check
	bpl movingDown							; No floor check unless moving down

noDownMove:
	jmp noDownMovement

movingDown:
	lda playerMapY
	and #7									; Calculate minDist to nearest char below Y = 7 - y & 7 (or 0 if Y & 7 == 0)
	eor #7
	clc
	adc #1
	and #7
	sta minDistY							; Stash minDistY

	sec
	sbc playerDY							; Check if travelling into next block below
	beq checkFloor							; Aligned to floor tile so must check and handle collision
	bcs floorCheckDone						; There was room left so no need to look for floor

checkFloor:
	; Start checking floor
	lda #(CHARSPERROW * (PLAYER_H / 8))              ; Find floor tile row
	ldy minDistY
	beq chkTileB0 							; No adjustment needed if exactly at tile boundary
	clc
	adc #CHARSPERROW

chkTileB0:
	tay
	lda (zpTmp), Y							; Start peeking for floor tiles left to right
	asl
	bcs hitFloor
	bpl chkTileB1 							; Nothing here; check next
	jsr pickup

chkTileB1:
	iny
	lda (zpTmp), Y
	asl
	bcs hitFloor
	bpl chkTileB2 							; Nothing here; check next
	jsr pickup

chkTileB2:
	iny
	lda (zpTmp), Y
	asl
	bcs hitFloor
	bpl chkTileB3 							; Nothing here; check next
	jsr pickup

chkTileB3:
	iny
	lda playerMapX							; Check X "hangover" for player right edge
	and #7
	beq floorCheckDone						; Not poking out over rightmost char!

	lda (zpTmp), Y
	asl
	bcs hitFloor
	bpl floorCheckDone						; Nothing here; check next
	jsr pickup
	jmp floorCheckDone

hitFloor:
	lda #0									; Stop movement ("thud")
	sta playerDY

	lda minDistY							; Move remaining distance to block (minDistY)
	beq floorCheckDone						; No room left below; stay put
	clc
	adc playerY
	sta playerY

floorCheckDone:
noDownMovement:
	rts

pickup:
	rts
