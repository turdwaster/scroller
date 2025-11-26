; Global constants
scr0 = $0400
scr1 = $2400
charBufSwapBits = $20 ; (scr0 ^ scr1) >> 8
colmem = $d800
charsPerRow = 40
levelWidth = 20
lines = 24

JOY_UP = 1
JOY_DOWN = 2
JOY_LEFT = 4
JOY_RIGHT = 8
JOY_BUTTON = 16

; Scroller constants
chunks = 4
rowsPerChunk = 6
chunkSize = charsPerRow * rowsPerChunk

; Anim constants
ANIMSLOTS = 16
XStartRight = 256 + 56 + 24

; Scroller zero page
ANIMFRAME = $f7
LEVELPOS = $f8
scrollSpeed = $f9
SCROLLX = $fa
SCROLLWORKPTR = $fb
CHARBANK = $fc
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
