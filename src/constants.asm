; Global constants
scr0 = $0400
scr1 = $2400
charBufSwapBits = $20 ; (scr0 ^ scr1) >> 8
colmem = $d800
charsPerRow = 40
levelWidth = 20
lines = 24

; Scroller constants
chunks = 4
rowsPerChunk = 6
chunkSize = charsPerRow * rowsPerChunk

; Anim constants
ANIMSLOTS = 16

; Scroller zero page
ANIMFRAME = $f8
LEVELPOS = $f9
SCROLLX = $fa
SCROLLWORKPTR = $fb
CHARBANK = $fc
zpTmp = $fe
zpTmpHi = $ff

; Anim zero page
freeSprite = $e9
animateScrHi = $ea
activeSpawn = $eb
activeAnim = $ec
continueFlag = $ed
curPc = $ee
