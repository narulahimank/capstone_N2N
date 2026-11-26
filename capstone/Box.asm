// ============================================================================
// Box.asm — Interactive Box Drawing Program for the Hack Computer
// ============================================================================
// Course      : Nand to Tetris – I (ETCCNT301)
// Student     : Himank Narula
// Roll Number : 2501730152
//
// Parameter Derivations:
//   Personal Constant K = last two digits of roll number = 52
//   K mod 4             = 52 mod 4 = 0
//   Box Starting Row    = Row K = Row 52
//   Box Height          = 20 rows (Row 52 through Row 71 inclusive)
//   Box Width           = 16 × ((K mod 4) + 1) pixels
//                       = 16 × ((0) + 1) = 16 pixels wide from left edge
//   Word Span per Row   = 16 pixels ÷ 16 bits/word = 1 word per row
//   Screen Base Address = 16384 (@SCREEN)
//   Row 52 Offset       = 32 words/row × 52 rows = 1664 words
//   Box Start Address   = 16384 + 1664 = 18048
//
// Program Behaviour:
//   • When ANY key is held down (RAM[KBD] != 0):
//       The box (20 rows × 1 word) is painted in BLACK (color = -1).
//   • When NO key is pressed (RAM[KBD] == 0):
//       The box is CLEARED to WHITE (color = 0).
//   • Program operates in an infinite event loop continuously polling @KBD.
//
// Variables (allocated in RAM starting at RAM[16]):
//   color — pixel pattern: -1 (all 16 bits 1 = black) or 0 (all 0s = white)
//   addr  — pointer to the current screen memory word being written
//   rows  — loop counter counting down from 20 to 1
// ============================================================================

(LOOP)
    // ------------------------------------------------------------------------
    // Step 1: Poll Hardware Keyboard Scan Code Register RAM[24576] (@KBD)
    // ------------------------------------------------------------------------
    @KBD
    D=M                 // D = current key scan code (0 if idle)

    @KEY_PRESSED
    D;JNE               // If scan code != 0, branch to KEY_PRESSED

    // ------------------------------------------------------------------------
    // Step 2: Key is NOT pressed -> Set color to 0 (white / clear)
    // ------------------------------------------------------------------------
    @color
    M=0                 // RAM[color] = 0 (16 white pixels per word)
    @DRAW_BOX
    0;JMP               // Jump to drawing routine

(KEY_PRESSED)
    // ------------------------------------------------------------------------
    // Step 3: Key IS pressed -> Set color to -1 (black / fill)
    // ------------------------------------------------------------------------
    @color
    M=-1                // RAM[color] = -1 (0xFFFF: 16 black pixels per word)

(DRAW_BOX)
    // ------------------------------------------------------------------------
    // Step 4: Initialize Memory Pointer to Starting Row Address (Row 52)
    // Base SCREEN (16384) + (32 words/row * 52 rows) = 18048
    // ------------------------------------------------------------------------
    @18048
    D=A
    @addr
    M=D                 // RAM[addr] = 18048

    // ------------------------------------------------------------------------
    // Step 5: Initialize Row Counter to 20
    // ------------------------------------------------------------------------
    @20
    D=A
    @rows
    M=D                 // RAM[rows] = 20

(ROW_LOOP)
    // ------------------------------------------------------------------------
    // Step 6: Write 16 pixels (1 word) to current screen address
    // ------------------------------------------------------------------------
    @color
    D=M                 // D = color (-1 for black, 0 for white)
    @addr
    A=M                 // A = current screen memory address
    M=D                 // RAM[addr] = color (paints 16 horizontal pixels)

    // ------------------------------------------------------------------------
    // Step 7: Advance address to the same column on the NEXT row (+32 words)
    // ------------------------------------------------------------------------
    @32
    D=A
    @addr
    M=D+M               // addr = D + addr (next row offset)

    // ------------------------------------------------------------------------
    // Step 8: Decrement row counter and loop until 20 rows are completed
    // ------------------------------------------------------------------------
    @rows
    MD=M-1              // rows = rows - 1, and copy result to D register
    @ROW_LOOP
    D;JGT               // If rows > 0, repeat for next row

    // ------------------------------------------------------------------------
    // Step 9: Repeat infinite loop to continually monitor keyboard
    // ------------------------------------------------------------------------
    @LOOP
    0;JMP
