#+feature dynamic-literals
package main

import "core:strings"
import "core:mem"

OPCODE_MNEMONICS := map[string]VM_Opcode {
    "nop" = .NOP,
    "add" = .ADD, 
    "sub" = .SUB, 
    "mul" = .MUL, 
    "div" = .DIV, 
    "mod" = .MODULO, 
    "lit" = .LITERAL,
    "fetch" = .FETCH, 
    "store" = .STORE, 
    "bfetch" = .BYTE_FETCH, 
    "bstore" = .BYTE_STORE, 
    "drop" = .DROP, 
    "dup" = .DUP, 
    "rot" = .ROT, 
    "swap" = .SWAP, 
    "r_to_p" = .R_TO_P, 
    "p_to_r" = .P_TO_R, 
    "eq" = .EQUAL, 
    "lt" = .LESS_THAN, 
    "gt" = .GREATER_THAN, 
    "and" = .AND, 
    "or" = .OR, 
    "not" = .NOT, 
    "dot" = .DOT, 
    "br" = .BRANCH,
    "br0" = .BRANCH0,
    "ret" = .RETURN,
    "call" = .CALL,
    "cell" = .CELL,
}

assemble :: proc(vm: ^VM, source: string) -> VM_Error {
    labels: map[string]int
    scanner_init(&vm.scanner, source)
    for word in scanner_next_word(&vm.scanner) {
        if strings.starts_with(word, ";") {
            scanner_goto_next_line(&vm.scanner)
        }
        word_lowered := strings.to_lower(word, context.temp_allocator)
        if opcode, ok := OPCODE_MNEMONICS[word_lowered]; ok {
            write_byte(vm, cast(u8)opcode)
            switch OPCODE_OPERAND_TYPES[opcode]{
            case .None:
            case .Address, .Cell:
                operand, _ := scanner_next_word(&vm.scanner)
                if number, num_ok := string_to_number(operand); num_ok {
                    write_cell(vm, cast(Cell)number)
                } else if bytecode_offset, found := labels[operand]; found {
                    addr := mem.ptr_offset(
                       raw_data(vm.data[:]),
                       bytecode_offset
                    )
                    write_cell(vm, transmute(Cell)addr)
                }
            case .Branch_Offset:
                operand, _ := scanner_next_word(&vm.scanner)
                if number, num_ok := string_to_number(operand); num_ok {
                    write_i16(vm, cast(i16)number)
                } else if bytecode_offset, found := labels[operand]; found {
                    // TODO: write difference
                }
            }
        } else if len(word) > 1 && strings.ends_with(word, ":") {
            label := word[:len(word)-1]
            assert(label not_in labels)
            labels[label] = len(vm.data)
        }
    }
    return nil
}
