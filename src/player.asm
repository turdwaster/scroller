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
	lda #7                 ; Spawn player sprite (TODO: overlap with spawnStuff...)
	sta freeSprite
	lda #0
	sta playerFlags
	jsr spawnStuff

	lda SPRITE_X_MSB   ; Set x MSB
	and #255 - playerBit
	sta SPRITE_X_MSB
	lda #playerStartX      ; Go to start position since default spawn is outside screen
	sta playerX

	lda #14
	sta playerColor    ; Remove when supported by spawn or stop using spawn...
	rts

checkPlayerMovement:
	lda $dc00
	lsr
	bcs noUpJoy

	ldy playerDY
	bmi checkRight                   ; Already moving up

	dey                                       ; Accelerate upward (max speed will be -1)
	; ldy #256 - 2                             ;  Alternative: jump boost
	sty playerDY
	jmp checkRight

noUpJoy:
	tax
	lda animFrame
	and #((1 << GRAVITY_DELAY) - 1) << 1       ; Only called for every other animFrame so mask must be << 1
	bne restoreJoyBits

	ldy playerDY
	bmi alwaysFall                   ; Not at max fall speed if moving up
	cpy #7
	bcs restoreJoyBits               ; Already at max fall speed - stop accelerating

alwaysFall:
	inc playerDY                           ; Accelerate downward

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

	tay                  ; Check right side limit of player; scroll if trying to go right
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
	lda playerX                    ; Get and store actual tile relative player X
	sec
	sbc #LEFTEDGE
	sec
	sbc scrollX
	sta playerMapX

	lda playerY                    ; Get on-screen relative top coord
	sec
	sbc #TOPEDGE
	sta playerMapY

	lsr
	lsr
	lsr
	tax
	lda rowStartLo, X              ; Set row start address
	sta zpTmp
	lda rowStartHi, X
	ora animateScrHi
	sta zpTmpHi

	lda playerMapX                ; Find X target tile offset
	lsr
	lsr
	lsr

	clc                               ; Adjust zpTmp from start of row to start of to leftmost tile
	adc zpTmp
	bcc xTileOffsetOk
	inc zpTmpHi
xTileOffsetOk:
	sta zpTmp

	; ZpTmp is now top left tile of player; start doing collision checks based on movement direction
	lda playerDY
	beq noDownMove     ; No vertical movement = no floor check
	bpl movingDown       ; No floor check unless moving down

noDownMove:
	jmp noDownMovement

movingDown:
	lda playerMapY
	and #7                             ; Calculate minDist to nearest char below Y = 7 - y & 7 (or 0 if Y & 7 == 0)
	eor #7
	clc
	adc #1
	and #7
	sta minDistY                  ; Stash minDistY

	sec
	sbc playerDY                   ; Check if travelling into next block below
	beq checkFloor         ; Aligned to floor tile so must check and handle collision
	bcs noFloorReached       ; There was room left so no need to look for floor

checkFloor:
	; Start checking floor

	lda #(CHARSPERROW * (PLAYER_H / 8))              ; Find floor tile row
	ldy minDistY
	beq skipAdjustFloor    ; No adjustment needed if exactly at tile boundary
	adc #CHARSPERROW

skipAdjustFloor:
	tay
	lda (zpTmp), Y               ; Start peeking for floor tiles left to right
	bmi hitFloor

	iny
	lda (zpTmp), Y
	bmi hitFloor

	iny
	lda (zpTmp), Y
	bmi hitFloor

	; TODO: pre-and playerMapX/playerMapY if not used anymore?

	lda playerMapX                ; Check X "hangover" for player right edge
	and #7
	beq noFloorReached     ; Not poking out over rightmost char!

	iny
	lda (zpTmp), Y
	bpl noFloorReached

hitFloor:
	lda #0                             ; Stop movement ("thud")
	sta playerDY

	lda minDistY                 ; Move remaining distance to block (minDistY)
	beq noFloorReached     ; No room left below; stay put
	clc
	adc playerY
	sta playerY

noFloorReached:
	; Check bottom pickupables
	ldy #(CHARSPERROW * (PLAYER_H / 8) + 3)	; Assume we poke into bottommost row

noT3:
	lda playerMapY
	and #7
	beq bottomRowHit	; Only touching bottom row if Y & 7 == 0 - otherwise check 2nd-to-bottom row
	ldy #(CHARSPERROW * (PLAYER_H / 8 - 1) + 3)

	; AND $40 funkar inte - finns massa tiles som har den biten satt...
	; När sammanfaller golvchecken med pickup? Går det att undvika upprepning
	; Kör båda från vänster för enkelhet...

bottomRowHit:
	lda playerMapX
	and #7
	beq noT11_T7 		; No touch for tile-aligned X

	lda (zpTmp), Y		; Check bottom rightmost
	and #64
	beq noT11_T7
	jsr pickup
noT11_T7:
	dey
	lda (zpTmp), Y		; Check bottom second-to-right
	and #64
	beq noT10_T6
	jsr pickup
noT10_T6:
	dey
	lda (zpTmp), Y		; Check bottom second-to-left
	and #64
	beq noT9_T5
	jsr pickup
noT9_T5:
	dey
	lda (zpTmp), Y		; Check bottom leftmost
	and #64
	beq noT8_T4
	jsr pickup
noT8_T4:

noDownMovement:
	rts

pickup:
	rts