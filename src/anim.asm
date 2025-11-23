resetAnims:
	lda #0
	sta activeAnim
	sta activeSpawn
	sta freeSprite

	ldx #15
clearSprites:
	sta sprite_flags, X
	dex
	bpl clearSprites

	; Hi byte of visible/animated char segment
	lda #scr0 >> 8
	sta animateScrHi

	lda #1
	ldx #0
setBitValues:
	sta bitValues, X
	inx
	asl
	bne setBitValues
	rts

	; Called *after* screen is completely scroll-shifted since it assumes that content has moved left already
shiftAnims:
	ldx activeAnim

findNextActiveAnim:
	ldy spawn_x, X
	bmi allShifted           ; x < 0: tombstone, end scan
	bne shiftAnimLeft        ; x >= 0: still on screen and can be shifted right away

	lda #255
	sta anim_stepwait, X           ; Mark as inactive (went off screen)
	inx                               ; x == 0, so will go off screen now; bump active anim and try next
	stx activeAnim
	jmp findNextActiveAnim

animCheckShiftable:
	ldy spawn_x, X
	bmi allShifted           ; Tombstone; passed last active animation; exit
	; Can't put a tombstone on non-top anim since that ends the list, and can't move activeAnim either...

shiftAnimLeft:
	dey
	tya
	sta spawn_x, X

checkNextShift:
	inx
	jmp animCheckShiftable

allShifted:
	rts

spawnStuff:
	ldx activeSpawn

checkSpawn:
	lda spawn_wait, X
	bne noSpawnReady ; Active spawn wait count has not reached 0 yet; wait and exit

	; Spawn wait count is zero - do spawn (could use trampoline here...!)
	lda anim_firstInstr, X
	sta anim_pc, X
	jsr spawnUnit            ; Preserve or reload X!
	inx                      ; Spawn done - move to next entry
	jmp checkSpawn    ; Go to processing of next entry

noSpawnReady:
	dec spawn_wait, X     ; Waiting - tick active spawn wait time down
	stx activeSpawn      ; Update active ptr to new entry in case we spawned (or same if nothing spawned)
	rts

	; X holds index in spawn structure
spawnUnit:
	lda anim_y, X          ; Neg. y = sprite
	bpl spawnChar

	and #127                   ; Extract Y pos stored as (y/2 | 128) and stow it away
	asl
	sta zpTmp

	ldy freeSprite        ; Get free index

	lda #balloon / 64
	sta scr0 + 1016, Y     ; Sprite pointer = VIC bank start + acc. * 64
	sta scr1 + 1016, Y     ; Set it for both char screens since it moves...

	lda $d010             ; Set x MSB
	ora bitValues, Y
	sta $d010

	lda #13
	sta $d027, Y          ; Set color

	lda $d015
	ora bitValues, Y
	sta $d015             ; Update enable register

	; ---- From here do all values stored at sprite index * 2 by using doubled Y ----
	tya
	asl
	tay

	lda zpTmp
	sta $d001, Y          ; Sprite y position

	lda #XStartRight & 255
	sta $d000, Y          ; Sprite x low

	lda #1
	sta sprite_flags, Y    ; Enable movement

	lda #0                     ; Initial speed
	sta sprite_dx, Y
	sta sprite_dy, Y

	tya                       ; Save sprite index * 2
	sta anim_sprite_idx, X

	dec freeSprite        ; Allocate and bump
	bpl doInitialRun
	lda #7
	sta freeSprite
	jmp doInitialRun   ; Immediately run first anim step

spawnChar:
	tay
	lda rowStartLo, Y
	sta anim_addr_lo, X
	lda rowStartHi, Y
	ora animateScrHi
	sta anim_addr_hi, X

	; Place initial char at rightmost pos (in Y)
	lda #(charsPerRow - 1)
	sta spawn_x, X

doInitialRun:
	; Force first instruction (delay should be after instructions, not before them)
	jsr runAnimTick

	; Arm delay counter
	lda anim_stepdelay, X
	sta anim_stepwait, X
	rts

animate:
	ldx activeAnim            ; X starts at first might-be-active animating entry

checkAnimSlot:
	lda anim_stepwait, X       ; Delaying until next frame?
	beq runFrame
	bmi animsDone        ; Neg. value => not spawned yet; end of active list

	sec                           ; Decrease next frame wait
	sbc #1
	sta anim_stepwait, X
	bcs checkNextSlot    ; Still is waiting for next frame; check next entry

runFrame:
	lda anim_stepdelay, X      ; Reset frame delay
	sta anim_stepwait, X
	jsr runAnimTick

checkNextSlot:
	inx                           ; X must be preserved!
	bne checkAnimSlot

animsDone:
	rts

	; X = anim slot index
runAnimTick:
	ldy anim_pc, X
	bne runAnimInstr          ; Magic zero end-of-program PC (jump here and stay here...)
	rts

runAnimInstr:
	sty curPc                 ; Save PC to be able to update later
	lda #0                         ; Clear continue-next-instr flag
	sta continueFlag

	lda anim_instrs, Y
	bpl noJump

	clc                           ; JMP instruction - update PC and do next instr
	adc curPc
	beq updatePc       ; END instruction; store PC and bail

	tay                           ; Immediately run next instruction
	jmp runAnimInstr

noJump:
	cmp #64                        ; Check for continuation flag
	bcc execInstr
	and #63
	sta continueFlag

execInstr:
	; TODO: encode instrs as their branch offset
	cmp #0
	beq doNop
	cmp #1
	beq doSetFrame
	cmp #2
	beq doSetCol
	cmp #3
	beq doSetSpeedX
	cmp #4
	beq doSetSpeedY

	jmp noRun

doNop:
	jmp nextAnimInstr

doSetFrame:
	lda anim_operands, Y
	sta anim_cur, X            ; Store updated frame/char index

	; Draw updated character
	lda anim_addr_lo, X
	sta zpTmp
	lda anim_addr_hi, X
	sta zpTmpHi
	lda anim_cur, X            ; Reloading cur; out of registers since X is entry and Y is x pos...
	ldy spawn_x, X
	sta (zpTmp), Y
	jmp nextAnimInstr

doSetCol:
	lda anim_addr_lo, X
	sta zpTmp
	lda anim_addr_hi, X
	and #$03
	ora #$d8
	sta zpTmpHi

	lda anim_operands, Y
	ldy spawn_x, X
	sta (zpTmp), Y
	jmp nextAnimInstr

doSetSpeedX:
	lda anim_operands, Y       ; Stow new speed operand
	ldy anim_sprite_idx, X
	sta sprite_dx, Y
	jmp nextAnimInstr

doSetSpeedY:
	lda anim_operands, Y       ; Stow new speed operand
	ldy anim_sprite_idx, X
	sta sprite_dy, Y
	jmp nextAnimInstr

nextAnimInstr:
	ldy curPc                 ; Processing done; skip to next instruction
	iny
	lda continueFlag
	beq execDone     ; Continue-with-next flag set: do another instr
	jmp runAnimInstr

execDone:
	tya

updatePc:
	sta anim_pc, X         ; Save PC for next tick and end execution of this slot

noRun:
	rts

redrawWaitingCharAnims:
	ldx activeAnim            ; X starts at first might-be-active animating entry

drawNextAnimSlot:
	lda anim_stepwait, X
	bmi drawsDone        ; Neg. value => not spawned yet; end of active list

	; Draw current frame char
	lda anim_addr_lo, X
	sta zpTmp
	lda anim_addr_hi, X
	sta zpTmpHi
	lda anim_cur, X
	ldy spawn_x, X
	sta (zpTmp), Y

	inx
	bne drawNextAnimSlot

drawsDone:
	rts

swapAnimTarget:
	ldx activeAnim            ; X starts at first might-be-active animating entry

swapNextAnim:
	lda spawn_x, X
	bmi swapAnimDone
	lda anim_addr_hi, X
	eor #charBufSwapBits
	sta anim_addr_hi, X
	inx
	bne swapNextAnim

swapAnimDone:
	lda animateScrHi
	eor #charBufSwapBits
	sta animateScrHi
	rts

animSwap:
	; State at start
	;      _
	; [CDEFcY]    [DEFcYZ]

	; Swap, shift and redraw could be merged into a single horrible routine to save cycles, but this is clearer
	jsr swapAnimTarget
	;                  _
	; [CDEFcY]    [DEFcYZ]

	jsr shiftAnims
	;                 _          _
	; [CDEFcY]    [DEFcYZ] / [DEF?YZ] (delayed)

	jsr redrawWaitingCharAnims
	;                 _          _
	; [CDEFcY]    [DEFcYZ] / [DEFcYZ] (delayed)

	jsr spawnStuff
	;                 _ s
	; [CDEFcY]    [DEFcYp]
	rts

moveSprites:
	ldx #14

moveNextSprite:
	lda sprite_flags, X
	beq spriteMoveDone

	lda sprite_dx, X
	clc
	adc scrollSpeed
	beq spriteMoveDone ; Resulting speed is zero; no change

	clc
	bmi moveLeft         ; Speed is negative; treat overflow for x MSB backwards

	adc $d000, X
	sta $d000, X
	bcc spriteMoveDone
	jmp flipMSB

moveLeft:
	adc $d000, X
	sta $d000, X
	bcs spriteMoveDone

	lda bitValuesX2, X     ; Get bit value for current sprite
	tay                       ; Save "our" bit for reuse

	; If MSB = 0, speed negative and about to flip: going off screen => disable?
	; At this point: about to flip = true; speed neg = true, so check MSB.
	and $d010             ; Could use a zp temp and store d010 at the end instead
	bne writeMSB     ; MSB set so still at x > 0 (and < 256)

	sta sprite_flags, X    ; Disable movement and hide sprite (A is zero from prev. AND)
	tya
	eor $d015
	sta $d015

flipMSB:
	lda bitValuesX2, X     ; Get bit value for current sprite

writeMSB:
	eor $d010             ; Could use a zp temp and store d010 at the end instead
	sta $d010

spriteMoveDone:
	dex
	dex
	bpl moveNextSprite
	rts