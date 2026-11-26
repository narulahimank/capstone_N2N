#!/usr/bin/env python3
"""
===============================================================================
Hack Assembler — Nand to Tetris Capstone Project (ETCCNT301)
===============================================================================
Author:       Himank Narula
Roll Number:  2501730152
Personal K:   52  (last two digits of roll number: 2501730152 -> K = 52)
Extra Spec:   K mod 3 = 52 mod 3 = 1
              -> Feature 1: Line-by-line error reporting with line numbers
                 (e.g., "Line 7: invalid instruction") instead of crashing.

Description:
  Translates symbolic Hack assembly (.asm) programs into 16-bit binary
  machine instructions (.hack) executable on the Hack Computer hardware.

Translation Architecture (Two-Pass Assembler):
  • Pass 1:
      1. Strips comments (// ...) and ignores empty/whitespace-only lines.
      2. Identifies label definitions '(LABEL)' and records their target
         ROM addresses (pointing to the subsequent instruction) without
         incrementing the program counter.
      3. Builds the sanitized instruction queue with original physical
         line numbers preserved for syntax diagnostics.
  • Pass 2:
      1. Translates A-instructions (@value or @symbol):
         - Numeric constants (e.g. @52, @16384) -> 15-bit binary literal
         - Predefined symbols (SP, LCL, ARG, THIS, THAT, R0-R15, SCREEN, KBD)
         - User labels resolved to their ROM target addresses
         - Dynamic variables allocated sequentially in RAM starting at RAM[16]
      2. Translates C-instructions (dest=comp;jump):
         - Deconstructs dest, comp, jump mnemonics
         - Converts to binary format: 111 + 7-bit comp + 3-bit dest + 3-bit jump
      3. Error Handling (K mod 3 = 1):
         - Catches malformed tokens gracefully, reports the exact physical
           line number and description, collects all errors, and safely
           prevents emission of corrupt .hack files.

Usage:
  python3 assembler.py <filename.asm>
===============================================================================
"""

import sys
import os

# =============================================================================
# LOOKUP TABLES FOR HACK MACHINE LANGUAGE
# =============================================================================

# COMP TABLE: 7-bit representation (a-bit + 6 ALU control bits)
# When a=0, ALU accesses register A; when a=1, ALU accesses memory operand M.
COMP_TABLE = {
    # a = 0 (operations with register A)
    "0":   "0101010",
    "1":   "0111111",
    "-1":  "0111010",
    "D":   "0001100",
    "A":   "0110000",
    "!D":  "0001101",
    "!A":  "0110001",
    "-D":  "0001111",
    "-A":  "0110011",
    "D+1": "0011111",
    "A+1": "0110111",
    "D-1": "0001110",
    "A-1": "0110010",
    "D+A": "0000010",
    "D-A": "0010011",
    "A-D": "0000111",
    "D&A": "0000000",
    "D|A": "0010101",
    # a = 1 (operations with memory operand M = RAM[A])
    "M":   "1110000",
    "!M":  "1110001",
    "-M":  "1110011",
    "M+1": "1110111",
    "M-1": "1110010",
    "D+M": "1000010",
    "D-M": "1010011",
    "M-D": "1000111",
    "D&M": "1000000",
    "D|M": "1010101",
}

# DEST TABLE: 3 bits (d1 d2 d3 -> A D M write enables)
DEST_TABLE = {
    "null": "000",   # Value is not stored
    "M":    "001",   # Memory RAM[A]
    "D":    "010",   # Data Register D
    "MD":   "011",   # RAM[A] and D Register
    "A":    "100",   # Address Register A
    "AM":   "101",   # A Register and RAM[A]
    "AD":   "110",   # A Register and D Register
    "AMD":  "111",   # A Register, D Register, and RAM[A]
}

# JUMP TABLE: 3 bits (j1 j2 j3 -> <0, =0, >0 branching triggers)
JUMP_TABLE = {
    "null": "000",   # Sequential execution (no jump)
    "JGT":  "001",   # Jump if ALU out > 0
    "JEQ":  "010",   # Jump if ALU out == 0
    "JGE":  "011",   # Jump if ALU out >= 0
    "JLT":  "100",   # Jump if ALU out < 0
    "JNE":  "101",   # Jump if ALU out != 0
    "JLE":  "110",   # Jump if ALU out <= 0
    "JMP":  "111",   # Unconditional jump
}

# PRE-DEFINED ARCHITECTURAL SYMBOLS
PREDEFINED_SYMBOLS = {
    "SP":     0,       # Stack pointer
    "LCL":    1,       # Local base pointer
    "ARG":    2,       # Argument base pointer
    "THIS":   3,       # This segment pointer
    "THAT":   4,       # That segment pointer
    "SCREEN": 16384,   # Video memory-mapped display buffer base
    "KBD":    24576,   # Memory-mapped keyboard register
}

# Virtual registers R0 through R15 map directly to RAM[0] through RAM[15]
for i in range(16):
    PREDEFINED_SYMBOLS[f"R{i}"] = i


# =============================================================================
# HELPER PARSING FUNCTIONS
# =============================================================================

def clean_line(raw_line: str) -> str:
    """
    Strips inline comments (// ...) and surrounding whitespace.
    """
    comment_idx = raw_line.find("//")
    if comment_idx != -1:
        raw_line = raw_line[:comment_idx]
    return raw_line.strip()


def first_pass(lines: list) -> tuple:
    """
    Pass 1:
      1. Strips comments and blank lines.
      2. Extracts pseudo-instruction labels (LABEL), binding them to the
         ROM address of the immediately following instruction.
      3. Returns clean instruction tuples (line_number, instruction_str)
         and the initialized symbol table.
    """
    symbol_table = dict(PREDEFINED_SYMBOLS)
    clean_lines = []
    rom_address = 0

    for line_number, raw_line in enumerate(lines, start=1):
        line = clean_line(raw_line)
        if not line:
            continue

        if line.startswith("(") and line.endswith(")"):
            label = line[1:-1].strip()
            if not label:
                print(f"Line {line_number}: invalid instruction '{line}' — empty label declaration")
                continue
            symbol_table[label] = rom_address
        else:
            clean_lines.append((line_number, line))
            rom_address += 1

    return clean_lines, symbol_table


def parse_a_instruction(symbol: str, symbol_table: dict, next_var_addr: int) -> tuple:
    """
    Translates an A-instruction (@symbol or @number).
    Returns (16-bit binary string, updated next_var_addr).
    """
    if symbol.isdigit():
        value = int(symbol)
        if value > 32767:
            raise ValueError(f"numeric constant '{value}' exceeds 15-bit address limit (0..32767)")
    else:
        # Symbolic identifier
        if symbol not in symbol_table:
            # Allocate new variable in RAM starting at 16
            symbol_table[symbol] = next_var_addr
            next_var_addr += 1
        value = symbol_table[symbol]

    binary = format(value, "016b")
    return binary, next_var_addr


def parse_c_instruction(instruction: str) -> str:
    """
    Translates a C-instruction (dest=comp;jump).
    Returns 16-bit binary string format: 111 a cccccc ddd jjj.
    """
    dest_part = ""
    jump_part = ""
    comp_part = instruction

    # Extract jump field
    if ";" in comp_part:
        comp_part, jump_part = comp_part.split(";", 1)
        jump_part = jump_part.strip()
    else:
        jump_part = "null"

    # Extract destination field
    if "=" in comp_part:
        dest_part, comp_part = comp_part.split("=", 1)
        dest_part = dest_part.strip()
    else:
        dest_part = "null"

    comp_part = comp_part.strip()

    # Syntax verification
    if comp_part not in COMP_TABLE:
        raise ValueError(f"unknown comp mnemonic '{comp_part}'")
    if dest_part not in DEST_TABLE:
        raise ValueError(f"unknown dest mnemonic '{dest_part}'")
    if jump_part not in JUMP_TABLE:
        raise ValueError(f"unknown jump mnemonic '{jump_part}'")

    comp_bits = COMP_TABLE[comp_part]
    dest_bits = DEST_TABLE[dest_part]
    jump_bits = JUMP_TABLE[jump_part]

    return "111" + comp_bits + dest_bits + jump_bits


def second_pass(clean_lines: list, symbol_table: dict) -> tuple:
    """
    Pass 2:
      Converts instructions into 16-bit binary strings.
      Implements K mod 3 = 1 extra feature: non-crashing line diagnostics.
    """
    machine_code = []
    next_var_addr = 16
    error_count = 0

    for line_number, instruction in clean_lines:
        try:
            if instruction.startswith("@"):
                token = instruction[1:].strip()
                if not token:
                    raise ValueError("missing symbol/constant after '@'")
                binary, next_var_addr = parse_a_instruction(token, symbol_table, next_var_addr)
            else:
                binary = parse_c_instruction(instruction)
            machine_code.append(binary)
        except ValueError as err:
            # Feature 1 diagnostic reporting:
            print(f"Line {line_number}: invalid instruction '{instruction}' — {err}")
            error_count += 1

    return machine_code, error_count


def assemble(input_path: str) -> bool:
    """
    Orchestrates the two-pass assembly process and serializes output.
    """
    if not os.path.exists(input_path):
        print(f"Error: input file '{input_path}' not found.")
        return False

    with open(input_path, "r") as f:
        lines = f.readlines()

    print(f"Assembling: {input_path}")
    print(f"Total source lines: {len(lines)}")

    clean_lines, symbol_table = first_pass(lines)
    print(f"Instructions after stripping comments/labels: {len(clean_lines)}")

    machine_code, error_count = second_pass(clean_lines, symbol_table)

    if error_count > 0:
        print(f"\nAssembly completed with {error_count} error(s).")
        print("Output file NOT written due to errors.")
        return False

    output_path = input_path[:-4] + ".hack" if input_path.endswith(".asm") else input_path + ".hack"
    with open(output_path, "w") as f:
        for code in machine_code:
            f.write(code + "\n")

    print(f"\nAssembly completed with 0 error(s).")
    print(f"Output written to: {output_path}")
    print(f"Total instructions: {len(machine_code)}")
    return True


def main():
    if len(sys.argv) != 2:
        print("Usage: python3 assembler.py <filename.asm>")
        sys.exit(1)

    success = assemble(sys.argv[1])
    sys.exit(0 if success else 1)


if __name__ == "__main__":
    main()
