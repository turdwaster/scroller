; Read-only structures
anim_y: 		!byte   0,   0, 10, 11, 12, 255
anim_start: 	!byte  86,  67, 86, 86, 86
anim_end:   	!byte  89,  71, 89, 89, 89    ; Index after last frame (D => loop 'ABC')
anim_loopdelay: !byte   0,   4,  0,  0,  0

rowStartLo:    !for r, 0, lines-1 { !byte (r * charsPerRow) & $ff }
rowStartHi:    !for r, 0, lines-1 { !byte (r * charsPerRow) >> 8  }

; Calculated/mutated
spawn_wait: 	!byte    0,   5,  15,  0,  0, 255 ; Relative to last spawn!
				!fill ANIMSLOTS-3, $e1
anim_cur:		!fill ANIMSLOTS, $e2
anim_x:			!fill ANIMSLOTS, $e3
anim_addr_lo: 	!fill ANIMSLOTS, $e4
anim_addr_hi: 	!fill ANIMSLOTS, $e5
anim_loopwait:	!fill ANIMSLOTS, $e6

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
	ldy anim_x, X
	bmi allShifted           ; x < 0: tombstone, end scan
	bne shiftAnimLeft        ; x >= 0: still on screen and can be shifted right away
	inx                               ; x == 0, so will go off screen now; bump active anim and try next
	stx activeAnim
	bne findNextActiveAnim   ; Unconditional branch next (inx will be > 0)

animCheckShiftable:
	ldy anim_x, X
	bmi allShifted           ; Tombstone; passed last active animation; exit
	; Can't put a tombstone on non-top anim since that ends the list, and can't move activeAnim either...

shiftAnimLeft:
	dey
	tya
	sta anim_x, X

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
	lda #charsPerRow - 1
	sta anim_x, X

	; Plot initial char at this pos
	tay
	lda anim_start, X
	sta (zpTmp), Y
	sta anim_cur, X

	; Arm delay counter
	lda anim_loopdelay, X
	sta anim_loopwait, X
	rts

animate:
	ldx activeAnim       ; X starts at first might-be-active animating entry

checkAnimSlot:
	ldy anim_x, X
	bmi animsDone    ; Neg. value => not spawned yet; end of active list

	; Advance frame (i.e. char number)
	; Get address of start of row in current frame
	lda anim_cur, X
	clc
	adc #1
	cmp anim_end, X
	bne drawFrame

	; Wait for restart (costly, reading current char each delay... store it in struct?)
	lda anim_loopwait, X
	beq animRestart
	sec
	sbc #1
	sta anim_loopwait, X
	bpl unitDone         ; Keep delaying restart while positive

animRestart:
	; Restart animation loop
	lda anim_loopdelay, X      ; Arm loop delay
	sta anim_loopwait, X
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
	inx
	bne checkAnimSlot

unitDone:
	inx
	bne checkAnimSlot    ; Unconditionally check next entry

animsDone:
	rts

swapAnimTarget:
	ldx activeAnim       ; X starts at first might-be-active animating entry
swapNextAnim:
	lda anim_x, X
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
	;__dumpAnimStates(1000);
	;      _
	; [CDEFbY]    [DEFbYZ]

	jsr animate
	;      _
	; [CDEFcY]    [DEFbYZ]
	;__dumpAnimStates(1001);

	jsr swapAnimTarget
	;                  _
	; [CDEFcY]    [DEFbYZ]
	;__dumpAnimStates(1002);

	jsr shiftAnims
	;                 _
	; [CDEFcY]    [DEFbYZ]
	;__dumpAnimStates(1003);

	jsr animate
	;                 _ 
	; [CDEFcY]    [DEFbYZ]
	;__dumpAnimStates(1004);

	jsr spawnStuff
	;                 _ s
	; [CDEFcY]    [DEFbYp]
	;__dumpAnimStates(1005);
	rts
