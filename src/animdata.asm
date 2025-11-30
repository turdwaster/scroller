; Nice to haves
rowStartLo:    	!for r, 0, CHARLINES-1 { !byte (r * CHARSPERROW) & $ff }
rowStartHi:    	!for r, 0, CHARLINES-1 { !byte (r * CHARSPERROW) >> 8  }
bitValuesX2:	!byte 1, 1, 2, 2, 4, 4, 8, 8, 16, 16, 32, 32, 64, 64, 128, 128

; Read-only anim structure, interleaved by ANIMSLOTS
spawn_wait: 	!byte  0			; Player
				!byte  5, 0, 0		; Traffic light
				!byte  15, 5, 5, 5	; Loons
				!align ANIMSLOTS-1, 0, 255
anim_y:			!byte  50 | 128
				!byte  0, 1, 2
				!byte  128 + 25, 128 + 50 , 128 + 75, 128 + 100
				!align ANIMSLOTS-1, 0, 0
anim_stepdelay: !byte  0
				!byte  25, 25, 25
				!byte  2, 4, 6, 8
				!align ANIMSLOTS-1, 0, 0
anim_firstInstr:!byte  1
				!byte  3, 8, 13
				!byte  springy,  springy,  springy,  springy

; Instructions
anim_instrs:	!byte 0, 5, 256-2
 				!byte 65,2, 1,    0,    256-4
				!byte  1, 	65,2, 1,    256-4
				!byte  1, 	0,    65,2, 256-4
sprprg:			!byte 3 + 64, 4, 3, 3, 3, 3 + 64, 4, 3, 3, 3, 256-10

springy = sprprg - anim_instrs

anim_operands: 	!byte 0, piggy/64, 0
				!byte 81,2, 32,   0,    0
				!byte 32,   81,7, 32,   0
				!byte 32,    0,   81,5, 0
				!byte 0, 1, 255, 254, 255, 0, 255, 1, 2, 1

; Calculated/mutated
spawn_x:		!fill ANIMSLOTS, $e2
anim_stepwait:	!fill ANIMSLOTS, $e3
anim_cur:		!fill ANIMSLOTS, $e4
anim_addr_lo: 	!fill ANIMSLOTS, $e5
anim_addr_hi: 	!fill ANIMSLOTS, $e6
anim_pc:		!fill ANIMSLOTS, $e7

sprite_flags:	!fill 16, $e8
sprite_dx:		!fill 16, $e8

sprite_dy = sprite_dx + 1
anim_sprite_idx = anim_addr_lo
