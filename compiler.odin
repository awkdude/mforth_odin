package main

import "core:mem"
import "core:fmt"

compile :: proc(vm: ^VM, source: string) -> VM_Error {
    scanner_init(&vm.scanner, source)
    dict: map[string]int
    compile_mode: bool
    for lexeme in scanner_next_word(&vm.scanner) {
        switch lexeme {
        case "+":
            write_byte(vm, cast(u8)VM_Opcode.ADD)
        case "-":
            write_byte(vm, cast(u8)VM_Opcode.SUB)
        case "*":
            write_byte(vm, cast(u8)VM_Opcode.MUL)
        case "/":
            write_byte(vm, cast(u8)VM_Opcode.DIV)
        case "mod":
            write_byte(vm, cast(u8)VM_Opcode.MODULO)
        case ".":
            write_byte(vm, cast(u8)VM_Opcode.DOT)
        case ". \"":
            // TODO:
        case "@":
            write_byte(vm, cast(u8)VM_Opcode.FETCH)
        case "!":
            write_byte(vm, cast(u8)VM_Opcode.STORE)
        case "@u8":
            write_byte(vm, cast(u8)VM_Opcode.BYTE_FETCH)
        case "!u8":
            write_byte(vm, cast(u8)VM_Opcode.BYTE_STORE)
        case "swap":
            write_byte(vm, cast(u8)VM_Opcode.SWAP)
        case "dup":
            write_byte(vm, cast(u8)VM_Opcode.DUP)
        case "=":
            write_byte(vm, cast(u8)VM_Opcode.EQUAL)
        case "<":
            write_byte(vm, cast(u8)VM_Opcode.LESS_THAN)
        case ">":
            write_byte(vm, cast(u8)VM_Opcode.GREATER_THAN)
        case "(":
            scanner_skip_to_char(&vm.scanner, ')')
        case ":":
            assert(!compile_mode)
            compile_mode = true
            word_name, _ := scanner_next_word(&vm.scanner)
            dict[word_name] = len(vm.data)
        case ";":
            assert(compile_mode)
            compile_mode = false
            write_byte(vm, cast(u8)VM_Opcode.RETURN)
            vm.ip = mem.ptr_offset(raw_data(vm.data[:]), len(vm.data))
        case "begin":
            stack_push(&vm.data_stack, transmute(Cell)len(vm.data))
        case "again":
            bytecode_offset, _ := stack_pop(&vm.data_stack)
            write_byte(vm, cast(u8)VM_Opcode.BRANCH)
            write_i16(vm, cast(i16)(bytecode_offset - (Cell)(len(vm.data)+2)))
        case:
            if bytecode_offset, found := dict[lexeme]; found {
                addr := mem.ptr_offset(raw_data(vm.data[:]), bytecode_offset)
                write_byte(vm, cast(u8)VM_Opcode.CALL)
                write_cell(vm, transmute(Cell)addr)
            } else if number, num_ok := string_to_number(lexeme); num_ok {
                write_byte(vm, cast(u8)VM_Opcode.LITERAL)
                write_cell(vm, cast(Cell)number)
            } else {
                // TODO: report error
            }
        }
    }
    return nil
}
