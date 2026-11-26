#set document(title: "Nand to Tetris Capstone Report - Make the Computer Draw a Box", author: "Himank Narula")

#let show_header = state("show_header", false)

#set page(
  paper: "a4",
  margin: (top: 1.8cm, bottom: 1.8cm, left: 2.0cm, right: 2.0cm),
  header: context {
    if show_header.get() and counter(page).get().first() > 1 {
      grid(
        columns: (1fr, 1fr),
        align(left)[#text(size: 8.5pt, weight: "bold", fill: rgb("#195693"))[Capstone Project: Make the Computer Draw a Box]],
        align(right)[#text(size: 8.5pt, fill: rgb("#4b5563"))[Himank Narula · Roll No: 2501730152 · K = 52]]
      )
      v(-0.4em)
      line(length: 100%, stroke: 0.5pt + rgb("#c6d1dd"))
    }
  },
  footer: context {
    if show_header.get() {
      align(center)[#text(size: 8.5pt, fill: rgb("#64748b"))[Page #counter(page).display() of 4]]
    }
  }
)

#set text(font: "Libertinus Serif", size: 9pt, fill: rgb("#1e1e1e"), spacing: 105%)
#set par(justify: true, leading: 0.55em)

// Styling headings
#show heading.where(level: 1): it => block(spacing: 0.7em)[
  #text(size: 11.5pt, weight: "bold", fill: rgb("#195693"))[#it.body]
]
#show heading.where(level: 2): it => block(spacing: 0.5em)[
  #text(size: 10pt, weight: "bold", fill: rgb("#195693"))[#it.body]
]

// Styling raw code blocks
#show raw.where(block: true): it => block(
  fill: rgb("#fff1f2"),
  stroke: 0.5pt + rgb("#e11d48"),
  inset: 5pt,
  radius: 3pt,
  width: 100%,
  text(font: "DejaVu Sans Mono", size: 7.2pt, fill: rgb("#881337"), it)
)

// Styling tables
#set table(
  stroke: (x, y) => if y == 0 { (bottom: 1.2pt + rgb("#195693"), top: 0.5pt + rgb("#c6d1dd")) } else { 0.4pt + rgb("#e2e8f0") },
  fill: (col, row) => if row == 0 { rgb("#f1f5f9") } else if calc.even(row) { rgb("#f8fafc") } else { none },
  inset: 4pt
)

// =============================================================================
// --- PAGE 1: TITLE, PARAMETERS & PART A (BUILD THE COMPUTER) ---
// =============================================================================

#align(center)[
  #grid(
    columns: (1fr, 3fr),
    gutter: 15pt,
    align(center + horizon)[#image("krmu_logo.png", width: 95%)],
    align(left + horizon)[
      #text(size: 14pt, weight: "bold", fill: rgb("#195693"))[School of Engineering & Technology]\
      #text(size: 11pt, weight: "bold", fill: rgb("#334155"))[K.R. Mangalam University, Gurugram]\
      #text(size: 9.5pt, style: "italic", fill: rgb("#64748b"))[Department of Computer Science & Engineering]
    ]
  )
  #v(0.2cm)
  #line(length: 100%, stroke: 1.2pt + rgb("#195693"))
  #v(0.15cm)
  #text(size: 15pt, weight: "bold", fill: rgb("#0f172a"))[Capstone Project: Make the Computer Draw a Box]\
  #text(size: 10pt, fill: rgb("#475569"))[Nand to Tetris – I (ETCCNT301) — Marks: 10 — Mapped COs: CO1–CO4]
]

#v(0.15cm)

#grid(
  columns: (1fr, 1fr),
  gutter: 10pt,
  block(fill: rgb("#eff6ff"), stroke: 0.6pt + rgb("#93c5fd"), inset: 6pt, radius: 4pt)[
    #text(weight: "bold", fill: rgb("#1e40af"))[Student Credentials:]\
    *Name:* Himank Narula \
    *Roll Number:* `2501730152` \
    *Course & Sem:* B.Tech CSE / 3rd Semester
  ],
  block(fill: rgb("#fefce8"), stroke: 0.6pt + rgb("#fde047"), inset: 6pt, radius: 4pt)[
    #text(weight: "bold", fill: rgb("#854d0e"))[Personal Parameter $K$ Derivation:]\
    $K = "Last two digits of Roll No." = bold(52)$ \
    $K space mod space 3 = 52 space mod space 3 = bold(1)$ (Error Diagnostics Feature) \
    $K space mod space 4 = 52 space mod space 4 = bold(0)$ ($16 times (0+1) = bold(16 "px") "width"$)
  ]
)

#v(0.15cm)
= 1. Project Specifications & Mathematical Parameters Summary

#table(
  columns: (1.5fr, 1.2fr, 2.5fr),
  [*Specification Parameter*], [*Evaluated Value*], [*Mathematical Formula / Mapping Rule*],
  [Personal Constant ($K$)], [$K = 52$], [Derived from registration number `2501730152`],
  [Box Starting Row], [Row 52], [Top raster row index: $"Row" = K = 52$],
  [Box Height], [20 rows], [Fixed height spanning Row 52 through Row 71 inclusive],
  [Box Pixel Width], [16 pixels], [$16 times ((K space mod space 4) + 1) = 16 times (0 + 1) = 16 "pixels from left edge"$],
  [Word Span per Row], [1 word / row], [$16 "pixels" / 16 "bits/word" = 1 "16-bit word per scanline"$],
  [Screen Base Memory Address], [Address 16384], [Base memory-mapped screen buffer (`@SCREEN`)],
  [Row 52 Offset Address], [1664 words], [$32 "words/row" times 52 "rows" = 1664 "words"$],
  [Box Start Address in RAM], [Address 18048], [Absolute memory address: $16384 + 1664 = bold(18048)$],
  [Assembler Extra Feature], [Feature 1 ($K space mod space 3 = 1$)], [Non-crashing line-by-line syntax error diagnostics with line numbers]
)

= 2. Part A – Build the Computer (`CPU.hdl`, `Memory.hdl`, `Computer.hdl`)

The complete Hack Computer architecture was integrated by interconnecting our lab chips (logic gates, ALU, registers, RAM, and Program Counter) into three top-level modules:
1. *Central Processing Unit (`CPU.hdl`):* Decodes A- and C-instructions, routes operands between internal `ARegister`, `DRegister`, and memory input (`inM`), executes computations via the `ALU`, determines conditional branching (`JGT`, `JEQ`, `JLT`, etc.), and advances the 15-bit `PC`.
2. *Unified Memory (`Memory.hdl`):* Decodes 15-bit addresses to arbitrate between `RAM16K` (`0x0000–0x3FFF`), memory-mapped `Screen` buffer (`0x4000–0x5FFF`), and keyboard scan register `Keyboard` (`0x6000` / 24576).
3. *Top-Level Computer (`Computer.hdl`):* Wires `ROM32K(address=pc, out=instruction)` directly to the `CPU`, closing the feedback loop between CPU data memory lines (`outM`, `writeM`, `addressM`) and the `Memory` chip.

#align(center)[
  #image("hack_architecture_diagram.png", width: 75%)
  #v(-0.4em)
  #text(size: 7.5pt, style: "italic", fill: rgb("#4b5563"))[*Figure 1:* Architectural block diagram of the Hack Computer (`Computer.hdl`) wiring CPU, ROM32K, and unified Memory.]
]

#pagebreak()
#show_header.update(true)

// =============================================================================
// --- PAGE 2: HARDWARE VERIFICATION & PART B (TWO-PASS ASSEMBLER) ---
// =============================================================================

== 2.1 Hardware Verification Test Evidence (Part A)
All hardware chip descriptions were checked against the official Nand2Tetris test scripts in the Hardware Simulator. Every test suite completed successfully with zero comparison failures:

#grid(
  columns: (1fr, 1fr),
  gutter: 8pt,
  figure(image("assets/CPU success.png", width: 95%), caption: [*CPU.tst*: Comparison ended successfully.]),
  figure(image("assets/Memory Success.png", width: 95%), caption: [*Memory.tst*: Comparison ended successfully.])
)
#v(0.1cm)
#grid(
  columns: (1fr, 1fr, 1fr),
  gutter: 6pt,
  figure(image("assets/ComputerAdd success.png", width: 98%), caption: [*ComputerAdd.tst* success]),
  figure(image("assets/ComputerMax Success.png", width: 98%), caption: [*ComputerMax.tst* success]),
  figure(image("assets/ComputerRect success.png", width: 98%), caption: [*ComputerRect.tst* success])
)

= 3. Part B – Write a Small Assembler in Python (`assembler.py`)

The custom assembler translates symbolic Hack assembly programs (`.asm`) into 16-bit binary machine code (`.hack`) through an architecturally decoupled two-pass pipeline:
- *First Reading (Pass 1):* Strips inline comments (`//`) and whitespace. Identifies label definitions `(LABEL)` and records their target ROM address (the line number of the next executable instruction) in `symbol_table` without incrementing the ROM instruction counter.
- *Second Reading (Pass 2):* Translates instructions into 16-bit binary. For A-instructions (`@symbol`), numeric literals are converted directly to 15-bit binary, while new variables are sequentially assigned RAM addresses starting at $16, 17, 18, dots$. For C-instructions (`dest=comp;jump`), tokens are looked up in `COMP_TABLE`, `DEST_TABLE`, and `JUMP_TABLE` to synthesize `111` + 7-bit `comp` + 3-bit `dest` + 3-bit `jump`.
- *Extra Feature for $K space mod space 3 = 1$:* Gracefully catches malformed assembly instructions and prints clear, human-readable diagnostics with the original source line number (e.g. `Line 7: invalid instruction`) instead of crashing with Python stack traces. Output files are withheld if errors are detected.

== 3.1 Assembler Benchmark Parity Verification (`compare.py`)
Our assembler was tested against official Nand2Tetris benchmarks (`Add.asm`, `Max.asm`, `Rect.asm`, `Pong.asm`). The emitted machine code was verified against the official assembler output with 100% bitwise parity:

#grid(
  columns: (1.1fr, 1.4fr),
  gutter: 10pt,
  table(
    columns: (1fr, 1.4fr),
    [*Benchmark*], [*Verification Result*],
    [`Add.asm`], [Exact Match (6 lines)],
    [`Max.asm`], [Exact Match (16 lines)],
    [`Rect.asm`], [Exact Match (25 lines)],
    [`Pong.asm`], [Exact Match (27,483 lines)]
  ),
  block(fill: rgb("#f8fafc"), stroke: 0.5pt + rgb("#cbd5e1"), inset: 6pt, radius: 3pt)[
    #text(size: 7.5pt, weight: "bold", fill: rgb("#0f172a"))[Automated Parity Output (`compare.py`):] \
    #text(font: "DejaVu Sans Mono", size: 7pt, fill: rgb("#166534"))[
      Add  -> MATCH ( 6 lines )\
      Max  -> MATCH ( 16 lines )\
      Rect -> MATCH ( 25 lines )\
      Pong -> MATCH ( 27483 lines )
    ]
  ]
)

#v(0.1cm)
== 3.2 Extra Feature Demonstration: Line Diagnostic Reporting
When fed invalid code (`BadInstruction.asm`), `assembler.py` cleanly reports the defect line without crashing:
```text
Assembling: BadInstruction.asm
Total source lines: 9 | Instructions after stripping comments/labels: 7
Line 7: invalid instruction 'INVALID_INSTRUCTION_HERE' — unknown comp mnemonic 'INVALID_INSTRUCTION_HERE'
Assembly completed with 1 error(s). Output file NOT written due to errors.
```

#pagebreak()

// =============================================================================
// --- PAGE 3: PART C (WRITE THE BOX PROGRAM) & SCREEN MEMORY ---
// =============================================================================

= 4. Part C – Write the Box Program (`Box.asm`)

The interactive display program `Box.asm` was authored in Hack assembly language. While any key is held down on the keyboard, a black box appears at the specified coordinates; when released, the box disappears.

== 4.1 Screen Memory Mapping & Raster Derivations for $K = 52$
The Hack display is a monochrome raster bitmap of 256 rows by 512 columns (32 16-bit words per row). Screen memory starts at RAM address $16384$ (`SCREEN`).
- *Starting Row:* Row $K = 52$.
- *Vertical Height:* 20 rows (Rows 52 through 71 inclusive).
- *Horizontal Span:* $16 times ((52 space mod space 4) + 1) = 16 times (0 + 1) = bold(16 "pixels")$ (exactly 1 word / row at column 0).
- *Starting Memory Address:* $"SCREEN" + 32 times 52 = 16384 + 1664 = bold(18048)$.
- *Ending Memory Address:* $18048 + (19 times 32) = bold(18656)$ (Row 71).

#align(center)[
  #image("screen_memory_diagram.png", width: 78%)
  #v(-0.4em)
  #text(size: 7.5pt, style: "italic", fill: rgb("#4b5563"))[*Figure 2:* Screen memory mapping for $K = 52$ showing the 16×20 box position starting at RAM[18048].]
]

== 4.2 Interactive Box Assembly Implementation (`Box.asm`)
The program runs an infinite polling loop sampling `@KBD` (RAM address 24576):
```hack
(LOOP)
    @KBD
    D=M                 // Sample keyboard scan code register
    @KEY_PRESSED
    D;JNE               // Key pressed (scan != 0) -> Paint black
    @color
    M=0                 // Key idle -> Paint white (clear box)
    @DRAW_BOX
    0;JMP
(KEY_PRESSED)
    @color
    M=-1                // -1 in 2's complement = 1111111111111111 (16 black pixels)
(DRAW_BOX)
    @18048              // SCREEN + 32 * 52 = 18048
    D=A
    @addr
    M=D                 // addr = 18048
    @20
    D=A
    @rows
    M=D                 // rows = 20
(ROW_LOOP)
    @color
    D=M
    @addr
    A=M
    M=D                 // Write 16 pixels (1 word) to current screen address
    @32
    D=A
    @addr
    M=D+M               // Advance address by 32 words to next row
    @rows
    MD=M-1              // rows = rows - 1
    @ROW_LOOP
    D;JGT               // Loop if rows > 0
    @LOOP
    0;JMP               // Repeat keyboard polling
```

== 4.3 Box Assembly & CPU Emulator Verification
`Box.asm` was converted into `Box.hack` using our *own assembler* from Part B (`assembler.py`):
```text
$ python3 assembler.py Box.asm
Assembling: Box.asm | Total source lines: 106 | Instructions: 33
Assembly completed with 0 error(s). Output written to: Box.hack
```

// =============================================================================
// --- PAGE 4: TEST SCREENSHOTS, MISTAKE FIXED & VIVA GUIDE ---
// =============================================================================

== 4.4 CPU Emulator Execution Evidence
`Box.hack` was loaded into the Nand2Tetris CPU Emulator with animation set to "No display" and speed to Fast. Holding down a key renders the exact solid 16×20 black box at Row 52, while releasing it instantaneously clears the canvas:

#align(center)[
  #image("assets/cpu emulator box.png", width: 84%)
  #v(-0.4em)
  #text(size: 7.5pt, style: "italic", fill: rgb("#4b5563"))[*Figure 3:* CPU Emulator execution: solid black box rendered at Row 52 (16 px wide × 20 rows tall) for $K = 52$.]
]

#v(0.15cm)
= 5. Paragraph on One Mistake Diagnosed and Fixed

#block(fill: rgb("#fef2f2"), stroke: (left: 3pt + rgb("#ef4444"), rest: 0.5pt + rgb("#fecaca")), inset: 7pt, radius: (right: 4pt))[
  #text(weight: "bold", fill: rgb("#b91c1c"))[Mnemonic Operand Order Violation in Hack ALU (`M=M+D` vs `M=D+M`):]\
  During the initial authoring of the raster scanline advance in `Box.asm`, line 92 was written as `@32; D=A; @addr; M=M+D`. When compiled with our custom assembler, the translation halted with the diagnostic message: `Line 92: invalid instruction 'M=M+D' — unknown comp mnemonic 'M+D'`. Upon auditing the Hack machine language specification, I identified that the Hack ALU architecture strictly pairs its $x$-input with the `D` register and its $y$-input with either `A` or `M`. As a direct hardware constraint, commutative addition between $D$ and memory is uniquely encoded as `D+M` (`c-bits = 000010`, $a=1$), whereas `M+D` is not a defined opcode mnemonic. Changing line 92 to `M=D+M` resolved the syntax error, demonstrating the value of our assembler's line-precise diagnostic feature and reinforcing how hardware instruction set architectures enforce assembly constraints.
]

= 6. Five-Minute Viva Voce Preparation & On-the-Spot Modifications Guide

To prepare for the 5-minute technical evaluation, the table below provides instant code changes for common viva prompts:

#table(
  columns: (1.5fr, 1.2fr, 2.5fr),
  [*Viva Modification Prompt*], [*Target in Box.asm*], [*Exact Code Edit & Mathematical Reason*],
  [Move box down by 10 rows (to Row 62)], [`(DRAW_BOX)` line 61], [Change `@18048` to `@18368` (Offset: $32 times 10 = 320$; $18048 + 320 = 18368$).],
  [Move box up by 20 rows (to Row 32)], [`(DRAW_BOX)` line 61], [Change `@18048` to `@17408` (Offset: $32 times 20 = 640$; $18048 - 640 = 17408$).],
  [Make box taller (30 rows tall)], [`(DRAW_BOX)` line 68], [Change `@20` to `@30` to increase row loop countdown from 20 to 30.],
  [Make box wider (32 pixels / 2 words)], [`(ROW_LOOP)`], [Add write to second word: `@addr; A=M+1; M=D` to paint columns 0 and 1.],
  [Invert key behavior (disappears on key)], [`(LOOP)`], [Swap values: set `@color; M=-1` on key release and `M=0` on key press.]
)

= 7. Conclusion & Submission Checklist
All components mandated by the Capstone Project specification have been completed, verified, and packaged:
- *Hardware Chips:* `CPU.hdl`, `Memory.hdl`, `Computer.hdl` pass all official hardware simulator tests.
- *Two-Pass Assembler:* `assembler.py` achieves 100% bitwise parity on benchmarks and enforces $K space mod space 3 = 1$ diagnostics.
- *Interactive Box Program:* `Box.asm` compiles cleanly to `Box.hack` with our own assembler and draws the exact $K = 52$ box.
- *Directory Submission:* Packaged in `/home/tushar/himank/capstone_N2N/` and mirror folder `capstone/`.
