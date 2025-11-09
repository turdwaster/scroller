; Read-only structures
anim_y: 		!byte  0, 120, 10, 11, 12, 255
anim_start: 	!byte  1,  67, 86, 86, 86
anim_end:   	!byte  4,  71, 89, 89, 89    ; Index after last frame (D => loop 'ABC')
anim_stepdelay: !byte  15, 24, 7, 7, 7

rowStartLo:    !for r, 0, lines-1 { !byte (r * charsPerRow) & $ff }
rowStartHi:    !for r, 0, lines-1 { !byte (r * charsPerRow) >> 8  }

; Calculated/mutated
spawn_wait: 	!byte    0, 5,  15,  0,  0, 255 ; Relative to last spawn!
				!fill ANIMSLOTS-3, $e1
spawn_x:		!fill ANIMSLOTS, $e3
anim_stepwait:	!fill ANIMSLOTS, $e6
anim_cur:		!fill ANIMSLOTS, $e2
anim_addr_lo: 	!fill ANIMSLOTS, $e4
anim_addr_hi: 	!fill ANIMSLOTS, $e5

; ------------ Start of current @asm import ------------

resetAnims:
	lda #0
	sta activeAnim
	sta activeSpawn

	; Hi byte of visible/animated char segment
	lda #(scr0 >> 8)
	sta animateScrHi
	rts

	; Called *after* screen is completely scroll-shifted since it assumes that content has moved left already
shiftAnims:
	ldx activeAnim

findNextActiveAnim:
	ldy spawn_x, X
	bmi allShifted           ; x < 0: tombstone, end scan
	bne shiftAnimLeft        ; x >= 0: still on screen and can be shifted right away
	inx                               ; x == 0, so will go off screen now; bump active anim and try next
	stx activeAnim
	bne findNextActiveAnim   ; Unconditional branch next (inx will be > 0)

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
	bne animCheckShiftable   ; Unconditionally check next

allShifted:
	rts

spawnStuff:
	ldx activeSpawn

checkSpawn:
	lda spawn_wait, X
	bne noSpawnReady ; Active spawn wait count has not reached 0 yet; wait and exit

	; Spawn wait count is zero - do spawn (could use trampoline here...!)
	jsr spawnUnit            ; Preserve or reload X!
	inx                      ; Spawn done - move to next entry
	bne checkSpawn  ; Unconditional branch to processing of next entry

noSpawnReady:
	dec spawn_wait, X     ; Waiting - tick active spawn wait time down
	stx activeSpawn      ; Update active ptr to new entry in case we spawned (or same if nothing spawned)
	rts

	; X holds index in spawn structure
spawnUnit:
	; Init char row offset and calculate char cell address (Y is rows from top)
	ldy anim_y, X
	lda rowStartLo, Y
	sta anim_addr_lo, X
	sta zpTmp
	lda rowStartHi, Y
	ora animateScrHi
	sta anim_addr_hi, X
	sta zpTmpHi

	; Place initial char at rightmost pos (in Y)
	lda #(charsPerRow - 1)
	sta spawn_x, X

	; Plot initial char at this pos
	tay
	lda anim_start, X
	sta (zpTmp), Y
	sta anim_cur, X

	; Arm delay counter
	lda anim_stepdelay, X
	sta anim_stepwait, X
	rts

animate:
	ldx activeAnim            ; X starts at first might-be-active animating entry

checkAnimSlot:
	; TODO: use loopwait < 0 as tombstone instead and skip loading spawn_x until needed later!
	ldy spawn_x, X
	bmi animsDone        ; Neg. value => not spawned yet; end of active list

	lda anim_stepwait, X       ; Delaying until next frame?
	beq advanceFrame

	sec                           ; Decrease next frame wait
	sbc #1
	sta anim_stepwait, X
	bcs checkNextSlot    ; Still is waiting for next frame; check next entry

advanceFrame:
	lda anim_stepdelay, X      ; Reset frame delay
	sta anim_stepwait, X

	lda anim_cur, X            ; Get address of start of row in current frame
	clc
	adc #1
	cmp anim_end, X
	bne drawFrame

	lda anim_start, X          ; Restart at first frame

drawFrame:
	; Store updated frame/char index
	sta anim_cur, X

	; Draw updated frame
	lda anim_addr_lo, X
	sta zpTmp
	lda anim_addr_hi, X
	sta zpTmpHi
	lda anim_cur, X            ; Reloading cur; out of registers since X is entry and Y is x pos...
	sta (zpTmp), Y

checkNextSlot:
	inx
	bne checkAnimSlot

animsDone:
	rts

	; TODO: merge with swapAnimTarget!
redrawWaitingCharAnims:
	ldx activeAnim            ; X starts at first might-be-active animating entry

drawNextAnimSlot:
	; TODO: use loopwait < 0 as tombstone instead and skip loading spawn_x until needed later!
	ldy spawn_x, X
	bmi drawsDone        ; Neg. value => not spawned yet; end of active list

	lda anim_stepwait, X       ; If not delayed, was redrawn in last animate call anyway
	beq notWaiting

	; Draw current frame char
	lda anim_addr_lo, X
	sta zpTmp
	lda anim_addr_hi, X
	sta zpTmpHi
	lda anim_cur, X            ; Reloading cur; out of registers since X is entry and Y is x pos...
	sta (zpTmp), Y

notWaiting:
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
	; State after animate
	;      _
	; [CDEFcY]    [DEFbYZ]

	jsr swapAnimTarget
	;                  _
	; [CDEFcY]    [DEFbYZ]

	jsr shiftAnims
	;                 _
	; [CDEFcY]    [DEFbYZ]

	jsr redrawWaitingCharAnims
	jsr animate
	;                 _ 
	; [CDEFcY]    [DEFbYZ]

	jsr spawnStuff
	;                 _ s
	; [CDEFcY]    [DEFbYp]
	rts
