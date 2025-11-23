level:
    !for r, 0, lines-1 {
        !byte 1, 2, 3, 4, 5, 6, 'X'-'A'+1
        !fill levelWidth - 6, 32
        ;!byte 1,4,1,13, 32, 9,19, 32, 1, 32, 19,5,1,12, 32,32,32,32, 32,32
    }
levelEnd:
