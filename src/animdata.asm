; Nice to haves
rowStartLo:    	!for r, 0, lines-1 { !byte (r * charsPerRow) & $ff }
rowStartHi:    	!for r, 0, lines-1 { !byte (r * charsPerRow) >> 8  }
bitValues:		!byte 1, 2, 4, 8, 16, 32, 64, 128

; Read-only anim structure, interleaved by ANIMSLOTS
spawn_wait: 	!byte  5,  0,  0,  15,  5,  5,  5 ; Relative to last spawn!
				!align ANIMSLOTS-1, 0, 255
anim_y:			!byte   0,  1,  2, 128 + 25, 128 + 50 , 128 + 75, 128 + 100, 255
				!align ANIMSLOTS-1, 0, 0
anim_stepdelay: !byte  25, 25, 25, 2, 4, 6, 8
				!align ANIMSLOTS-1, 0, 0
anim_firstInstr:!byte   1,  6, 11,  springy,  springy,  springy,  springy

; Instructions

anim_instrs: 	!byte  0, 65,2, 1,    0,    256-4
				!byte  0, 65,2, 1,    256-4
				!byte  1, 0,    65,2, 256-4
sprprg:			!byte 3, 3, 3, 3, 3, 3, 3, 3, 256-8

springy = sprprg - anim_instrs

anim_operands: 	!byte  0, 81,2, 32,    0,    0
				!byte  0, 81,7, 32,    0
				!byte 32,    0, 81,5,  0
				!byte 0, 255, 254, 255, 0, 1, 2, 1

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
