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

PLAYER_RSCROLLX = XSTARTRIGHT - 72 ; Position at which player stops and screen scrolls right
PLAYER_W = 24
PLAYER_H = 16
TOPEDGE = 50
LEFTEDGE = 24

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
	bmi checkRight		; Already moving up

	dey					; Accelerate upward (max speed will be -1)
	sty playerDY
	jmp checkRight

noUpJoy:
	ldy playerDY
	bmi alwaysFall      ; Not at max fall speed if moving up
	cpy #7
	bcs checkRight		; Already at max fall speed - stop accelerating
	
alwaysFall:
	inc playerDY		; Accelerate downward

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

	lda playerDY
	beq noFloorReached     ; No vertical movement = no floor check
	bmi noFloorReached       ; No floor check unless moving down

	lda playerY                    ; Get on-screen relative top coord
	sec
	sbc #TOPEDGE
	tay
	and #7                             ; Calculate minDist to nearest char below Y = 7 - y & 7 (or 0 if Y & 7 == 0)
	eor #7
	clc
	adc #1
	and #7
	tax                               ; Store minDistY in X reg for now

	sec
	sbc playerDY                   ; Check if travelling into next block below (could skip all of this if dy == 0)
	beq checkFloor         ; Aligned to floor tile so must check and handle collision
	bcs noFloorReached       ; There was room left so no need to look for floor

checkFloor:
	tya                               ; Find target tile row from local player Y
	clc
	adc #7 + PLAYER_H                  ; Round up (+7) and move down player height
	lsr
	lsr
	lsr
	tay

	lda rowStartLo, Y              ; Get row address
	sta zpTmp
	lda rowStartHi, Y
	ora animateScrHi
	sta zpTmpHi

	; Add player X tile offset
	lda playerMapX
	lsr
	lsr
	lsr
	tay

	lda (zpTmp), Y               ; Start peeking for floor tiles left to right
	bne hitFloor1

	iny
	lda (zpTmp), Y
	bne hitFloor2

	iny
	lda (zpTmp), Y
	bne hitFloor3

	lda playerMapX              ; Check X "hangover" for player right edge
	and #7
	beq noFloorReached     ; Not poking out over rightmost char!
	iny
	lda (zpTmp), Y
	bne hitFloor4            ; TODO: reverse if correct Y reg is not needed
	jmp noFloorReached

hitFloor1:
	;        iny();    ; To guarantee same char offset in row after check if needed for reuse
hitFloor2:
	;        iny();
hitFloor3:
	;        iny();
hitFloor4:
	lda #0                             ; Stop movement ("thud")
	sta playerDY

	txa                               ; Move remaining distance to block (minDistY)
	beq noFloorReached     ; No room left below; stay put
	clc
	adc playerY
	sta playerY

noFloorReached:
	; TODO: check other walls
	rts
