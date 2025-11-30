; Global constants
CHARBUFSWAPBITS = $20 ; (scr0 ^ scr1) >> 8
CHARSPERROW = 40
LEVELWIDTH = 40
CHARLINES = 24

; Scroller constants
scr0 = $0400
scr1 = $2400

; Anim constants
ANIMSLOTS = 16
XSTARTRIGHT = 256 + 56 + 24

; Scroller zero page
animFrame = $f7
levelPos = $f8
scrollSpeed = $f9
scrollX = $fa
scrollWorkPtr = $fb
charBank = $fc
zpTmp = $fe
zpTmpHi = $ff

; Anim zero page
bitValues = $e0 ; - $e7
freeSprite = $e9
animateScrHi = $ea
activeSpawn = $eb
activeAnim = $ec
continueFlag = $ed
curPc = $ee

; VIC stuff
SPRITE_X = $d000
SPRITE_Y = $d001
SPRITE_X_MSB = $d010
SPRITE_ENABLE = $d015
SPRITE_COLOR = $d027
VIC_MEMCFG = $d018
VIC_COLMEM = $d800
JOY_UP = 1
JOY_DOWN = 2
JOY_LEFT = 4
JOY_RIGHT = 8
JOY_BUTTON = 16
SPRITE_PTRS0 = scr0 + 1016
SPRITE_PTRS1 = scr1 + 1016