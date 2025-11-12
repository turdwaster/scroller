; Read-only structures
anim_y: 		!byte  0,  1, 10, 11, 12, 255
anim_stepdelay: !byte 15, 24,  7,  7,  7
anim_firstInstr:!byte  1,  1,  1,  1,  1

anim_instrs: 	!byte  0,  1,  1,  1, 256-3
anim_operands: 	!byte  0, 86, 87, 88,     0

rowStartLo:    !for r, 0, lines-1 { !byte (r * charsPerRow) & $ff }
rowStartHi:    !for r, 0, lines-1 { !byte (r * charsPerRow) >> 8  }

; Calculated/mutated
				!align ANIMSLOTS-1, 0, 0
spawn_wait: 	!byte  0, 5,  15,  0,  0 ; Relative to last spawn!
				!align ANIMSLOTS-1, 0, 255
spawn_x:		!fill ANIMSLOTS, $e2
anim_stepwait:	!fill ANIMSLOTS, $e3
anim_cur:		!fill ANIMSLOTS, $e4
anim_addr_lo: 	!fill ANIMSLOTS, $e5
anim_addr_hi: 	!fill ANIMSLOTS, $e6
anim_pc:		!fill ANIMSLOTS, $e7

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

	lda #255
	sta anim_stepwait, X           ; Mark as inactive (went off screen)
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
	lda anim_firstInstr, X
	sta anim_pc, X
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
	lda rowStartHi, Y
	ora animateScrHi
	sta anim_addr_hi, X

	; Place initial char at rightmost pos (in Y)
	lda #(charsPerRow - 1)
	sta spawn_x, X

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
	beq noRun  ; Magic zero no-program-here instruction (will go away)

runAnimInstr:
	sty curPc                 ; Save PC to be able to update later
	lda #0                         ; Clear continue-next-instr flag
	sta continueFlag

	lda anim_instrs, Y

	beq nextAnimInstr  ; NOP instruction
	bpl normalInstr

	cmp #255 - 64
	bcs reallyAJmp       ; Bit 7 set and bit 6 clear: flag that we should do next instr when done
	and #63
	sta continueFlag
	bne normalInstr      ; Unconditionally execute as normal instruction

reallyAJmp:
	clc                           ; JMP instruction - update PC and do next instr
	adc curPc
	tay
	bne runAnimInstr     ; Zero PC is special, so unconditional (zero jump = fall-thru)

normalInstr:
	; TODO: encode instrs as their branch offset
	cmp #1
	bne notSetFrame
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
	clc
	bcc nextAnimInstr

notSetFrame:
nextAnimInstr:
	ldy curPc                 ; Processing done; skip to next instruction
	iny
	lda continueFlag
	bne runAnimInstr     ; Continue-with-next flag set: do another instr

	; Save PC for next tick and end execution of this slot
	tya
	sta anim_pc, X

noRun:
	rts

redrawWaitingCharAnims:
	ldx activeAnim            ; X starts at first might-be-active animating entry

drawNextAnimSlot:
	lda anim_stepwait, X
	beq notWaiting     ; If not delayed, was redrawn in last animate call anyway
	bmi drawsDone        ; Neg. value => not spawned yet; end of active list

	; Draw current frame char
	lda anim_addr_lo, X
	sta zpTmp
	lda anim_addr_hi, X
	sta zpTmpHi
	lda anim_cur, X
	ldy spawn_x, X
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

	jsr animate
	;                 _          _
	; [CDEFcY]    [DEFcYZ] / [DEFbYZ] (delayed)

	jsr spawnStuff
	;                 _ s
	; [CDEFcY]    [DEFaYp]
	rts
