Run scrolling and animation according to a 16-step schedule:

| FRAME | SCROLLX | move() | animate   | spawnStuff | scroll              | MoveToNext |
|-------|---------|--------|-----------|------------|---------------------|------------|
| 0     | 7       | move() | animate() |            | moveChunk1a         |            |
| 1     | 6       | move() |           |            | moveChunk1b         | Yes        |
| 2     | 5       | move() | animate() |            | moveChunk1c         |            |
| 3     | 4       | move() |           |            | moveChunk1d         | Yes        |
| 4     | 3       | move() | animate() |            | fillColumn1         |            |
| 5     | 2       | move() |           |            | bumpLevelPtr        | Yes        |
| 6     | 1       | move() | animate() | spawn()    | animSwap            |            |
| 7     | 0       | move() |           |            | moveColorsAndSwap   | Yes        |
| 8     | 7       | move() | animate() |            | moveChunk2a         |            |
| 9     | 6       | move() |           |            | moveChunk2b         | Yes        |
| 10    | 5       | move() | animate() |            | moveChunk2c         |            |
| 11    | 4       | move() |           |            | moveChunk2d         | Yes        |
| 12    | 3       | move() | animate() |            | fillColumn2         |            |
| 13    | 2       | move() |           |            | bumpLevelPtr        | Yes        |
| 14    | 1       | move() | animate() | spawn()    | animSwap            |            |
| 15    | 0       | move() |           |            | moveColorsAndSwap   | Yes        |
