; Nice to haves
rowStartLo:    	!for r, 0, CHARLINES-1 { !byte (r * CHARSPERROW) & $ff }
rowStartHi:    	!for r, 0, CHARLINES-1 { !byte (r * CHARSPERROW) >> 8  }
bitValuesX2:	!byte 1, 1, 2, 2, 4, 4, 8, 8, 16, 16, 32, 32, 64, 64, 128, 128

; Interleaved anim structure, filled from flat_anims
spawn_wait: 	!fill ANIMSLOTS, 0
anim_y:			!fill ANIMSLOTS, 0
anim_stepdelay: !fill ANIMSLOTS, 0
anim_firstInstr:!fill ANIMSLOTS, 0

; Calculated/mutated
spawn_x:		!fill ANIMSLOTS, $e2
anim_stepwait:	!fill ANIMSLOTS, $e3
anim_cur:		!fill ANIMSLOTS, $e4
anim_addr_lo: 	!fill ANIMSLOTS, $e5
anim_addr_hi: 	!fill ANIMSLOTS, $e6
anim_pc:		!fill ANIMSLOTS, $e7
anim_hitInstr:	!fill ANIMSLOTS, 0

; Repurposed sprite anim state
anim_sprite_idx = anim_addr_lo

; Sprite states
sprite_flags:	!fill 16, $e8
sprite_dx:		!fill 16, $e8
sprite_dy = sprite_dx + 1

!macro tile .wait, .charY, .delay, .pc {
	!byte .wait
	!byte .charY
	!byte .delay
	!byte .pc - anim_instrs
}

!macro sprt .wait, .y, .delay, .pc {
	!byte .wait
	!byte (.y / 2) | 128
	!byte .delay
	!byte .pc - anim_instrs
}

flat_anims:	+sprt  0, 50,  0, init_player
			+tile  5,  0, 25, anim_instrs + 3
			+tile  0,  1, 25, anim_instrs + 8
			+tile  0,  2, 25, anim_instrs + 13
			+tile 18, 22,  3, gasgasgas
			+tile  5, 21,  3, gasgasgas
			+sprt  8, 50,  3, sprprg
flat_anims_end:

; Instructions
anim_instrs:	!byte 0 ; Sentinel byte
init_player:	!byte 5, 256-2
 				!byte 65,2, 1,    0,    256-4
				!byte  1, 	65,2, 1,    256-4
				!byte  1, 	0,    65,2, 256-4

sprprg:			!byte 3 + 64, 4, 3, 3, 3, 3 + 64, 4, 3, 3, 3, 256-10

gasgasgas:		!byte 1, 2, 2, 2, 64+2, 256-5

gascan = gasgasgas - anim_instrs

anim_operands: 	!byte 0 ; Sentinel byte
				!byte piggy/64, 0
				!byte 81,  2, 32,  0, 0
				!byte 32, 81,  7, 32, 0
				!byte 32,  0, 81,  5, 0
				!byte 0, 1, 255, 254, 255, 0, 255, 1, 2, 1, 0
				!byte 64, 2, 10, 1, 10, 0

