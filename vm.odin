package main

import "core:fmt"
import "core:mem"
import "core:strings"

when size_of(int) == 8 {
    Cell   :: i64le
    UCell  :: u64le
    DCell  :: i128le
    UDCell :: u128le
} else when size_of(int) == 4 {
    Cell   :: i32le
    UCell  :: u32le
    DCell  :: i64le
    UDCell :: u64le
}

BRANCH_OFFSET_SIZE :: 2

VM_Error :: enum {
    None,
    Done,
    Undefined,
    Divide_By_Zero,
    Stack_Underflow,
    Stack_Overflow,
}

VM :: struct {
    data: [dynamic]u8,
    data_stack: Stack(16*1024),
    return_stack: Stack(1024),
    ip: ^u8,
    get_key: proc() -> (u32, bool),
    output_str: proc(text: string),
    scanner: Scanner,
}

VM_Opcode :: enum u8 {
    NOP,
    ADD, //+
    SUB, // -
    MUL, // *
    DIV, // /
    MODULO, // %
    LITERAL,
    FETCH, // @
    STORE, // !
    BYTE_FETCH, // @u8
    BYTE_STORE, // !u8
    DROP, // drop
    DUP, // dup
    ROT, // rot
    SWAP, // swap
    R_TO_P, // r>
    P_TO_R, // >r
    EQUAL, // =
    LESS_THAN, // <
    GREATER_THAN, // >
    AND, // and
    OR, // or
    NOT, // not
    DOT, // .
    KEY, // key
    BRANCH,
    BRANCH0,
    RETURN,
    CALL,
    CELL,
}

Opcode_Operand_Type :: enum {
    None,
    Address,
    Branch_Offset,
    Cell,
} 

OPCODE_OPERAND_TYPES := #partial [VM_Opcode]Opcode_Operand_Type {
    .LITERAL = .Cell,
    .BRANCH = .Branch_Offset,
    .BRANCH0 = .Branch_Offset,
    .CALL = .Address,
}

disassemble_instruction :: proc(buf: []u8, ip: ^u8, base: ^u8 = nil) -> (string, ^u8) {
    ip := cast([^]u8)ip
    offset: int
    builder := strings.builder_from_bytes(buf[:])
    opcode := cast(VM_Opcode)ip[0]
    fmt.sbprintf(&builder, "%08x ", mem.ptr_sub(cast(^u8)ip, base))
    fmt.sbprintf(&builder, "%v ", opcode)
    offset += 1
    switch OPCODE_OPERAND_TYPES[opcode] {
    case .None:
    case .Cell:
        value := cell_at_address(&ip[offset])
        fmt.sbprintf(&builder, "%v", value)
        offset += size_of(Cell)
    case .Branch_Offset:
        value := i16_at_address(&ip[offset])
        fmt.sbprintf(&builder, "%v", value)
        offset += BRANCH_OFFSET_SIZE
    case .Address:
        value := cell_at_address(&ip[offset])
        when size_of(Cell) == 8 {
            fmt.sbprintf(&builder, "$%016x", value)
        } else {
            fmt.sbprintf(&builder, "$%08x", value)
        }
        offset += size_of(Cell)
    }
    return strings.to_string(builder), mem.ptr_offset(ip, offset)
}

vm_init :: proc(vm: ^VM) {
    vm.data = make([dynamic]u8, 0, 8*mem.Megabyte)
    vm.ip = raw_data(vm.data)
    stack_clear(&vm.data_stack)
    stack_clear(&vm.return_stack)
}

vm_run :: proc(vm: ^VM) -> VM_Error {
    // disasm: Disassembler
    // disassembler_init(&disasm, vm.data[:])
    ip: ^u8 = raw_data(vm.data[:])
    end := mem.ptr_offset(ip, len(vm.data))
    buf: [128]u8
    // for ip < end {
    //     disasm_output: string
    //     disasm_output, ip = disassemble_instruction(buf[:], ip, raw_data(vm.data[:]))
    //     fmt.printfln("%s", disasm_output)
    // }
    for {
        // disasm_output: string
        disasm_output, _ := disassemble_instruction(buf[:], vm.ip, raw_data(vm.data[:]))
        fmt.printfln("%s", disasm_output)
        vm_execute_next(vm) or_return
        stack_print(&vm.data_stack)
    }
}

interpret :: proc(vm: ^VM, source: string) {
    if compile(vm, source) == nil {
        vm_run(vm)
    }
}

write_byte :: proc(vm: ^VM, byte: u8) -> VM_Error {
    append(&vm.data, byte)
    return nil
}

write_i16 :: proc(vm: ^VM, value: i16) -> VM_Error {
    append(&vm.data, (u8)(value & 0xff))
    append(&vm.data, (u8)((value >> 8) & 0xff))
    return nil
}

write_cell :: proc(vm: ^VM, cell: Cell) -> VM_Error {
    when size_of(Cell) == 8 {
        b0 := (u8)((cell >> 00) & 0xff)
        b1 := (u8)((cell >> 08) & 0xff)
        b2 := (u8)((cell >> 16) & 0xff)
        b3 := (u8)((cell >> 24) & 0xff)
        b4 := (u8)((cell >> 32) & 0xff)
        b5 := (u8)((cell >> 40) & 0xff)
        b6 := (u8)((cell >> 48) & 0xff)
        b7 := (u8)((cell >> 56) & 0xff)
        append(&vm.data, b0)
        append(&vm.data, b1)
        append(&vm.data, b2)
        append(&vm.data, b3)
        append(&vm.data, b4)
        append(&vm.data, b5)
        append(&vm.data, b6)
        append(&vm.data, b7)
    } else when size_of(Cell) == 4 {
        b0 := (u8)((cell >> 00) & 0xff)
        b1 := (u8)((cell >> 08) & 0xff)
        b2 := (u8)((cell >> 16) & 0xff)
        b3 := (u8)((cell >> 24) & 0xff)
        append(&vm.data, b0)
        append(&vm.data, b1)
        append(&vm.data, b2)
        append(&vm.data, b3)
    }
    return nil
}

advance_byte :: proc "contextless" (vm: ^VM) -> (u8, VM_Error) {
    end := mem.ptr_offset(raw_data(vm.data), len(vm.data))
    if vm.ip >= end {
        return 0, .Done
    }
    byte := vm.ip^ // vm.data[vm.ip]
    vm.ip = mem.ptr_offset(vm.ip, 1)
    return byte, nil
}

cell_at_address :: proc "contextless" (addr: [^]u8) -> Cell {
    value: Cell
    when size_of(Cell) == 8 {
        b0 := cast(Cell)addr[0]
        b1 := cast(Cell)addr[1]
        b2 := cast(Cell)addr[2]
        b3 := cast(Cell)addr[3]
        b4 := cast(Cell)addr[4]
        b5 := cast(Cell)addr[5]
        b6 := cast(Cell)addr[6]
        b7 := cast(Cell)addr[7]
        value = (b0 | (b1 << 8) | (b2 << 16) | (b3 << 24) | (b4 << 32) | (b5 << 40) | (b6 << 48) | (b7 << 56))
    } else when size_of(Cell) == 4 {
        b0 := cast(Cell)addr[0]
        b1 := cast(Cell)addr[1]
        b2 := cast(Cell)addr[2]
        b3 := cast(Cell)addr[3]
        value = (b0 | (b1 << 8) | (b2 << 16) | (b3 << 24))
    }
    return value
}

advance_i16 :: proc "contextless" (vm: ^VM) -> (i16, VM_Error) {
    addr := cast([^]u8)vm.ip 
    if mem.ptr_sub(addr, raw_data(vm.data[:])) >= len(vm.data) {
        return 0, .Done
    }
    value := i16_at_address(addr)
    vm.ip = mem.ptr_offset(vm.ip, 2)
    return value, nil
}

i16_at_address :: proc "contextless" (addr: [^]u8) -> i16 {
    return (cast(^i16)addr)^
}

advance_cell :: proc "contextless" (vm: ^VM) -> (Cell, VM_Error) {
    addr := cast([^]u8)vm.ip 
    if mem.ptr_sub(addr, raw_data(vm.data[:])) >= len(vm.data) {
        return 0, .Done
    }
    value := cell_at_address(addr)
    vm.ip = mem.ptr_offset(vm.ip, size_of(Cell))
    return value, nil
}

vm_execute_next :: proc(vm: ^VM) -> VM_Error {
    opcode := advance_byte(vm) or_return
    switch cast(VM_Opcode)opcode {
    case .NOP:
    case .ADD:
        a, b := stack_pop2(&vm.data_stack) or_return
        stack_push(&vm.data_stack, a + b) or_return
    case .SUB:
        a, b := stack_pop2(&vm.data_stack) or_return
        stack_push(&vm.data_stack, a - b) or_return
    case .MUL:
        a, b := stack_pop2(&vm.data_stack) or_return
        stack_push(&vm.data_stack, a * b) or_return
    case .DIV:
        a, b := stack_pop2(&vm.data_stack) or_return
        if b == 0 {
            return .Divide_By_Zero
        }
        stack_push(&vm.data_stack, a / b) or_return
    case .MODULO:
        a, b := stack_pop2(&vm.data_stack) or_return
        if b == 0 {
            return .Divide_By_Zero
        }
        stack_push(&vm.data_stack, a % b) or_return
    case .FETCH:
        cell := stack_pop(&vm.data_stack) or_return
        addr := transmute(^Cell)cell
        stack_push(&vm.data_stack, addr^) or_return
    case .STORE:
        cell := stack_pop(&vm.data_stack) or_return
        value := stack_pop(&vm.data_stack) or_return
        addr := transmute(^Cell)cell
        addr^ = value
    case .BYTE_FETCH:
        cell := stack_pop(&vm.data_stack) or_return
        addr := transmute(^u8)cell
        stack_push(&vm.data_stack, cast(Cell)(addr^)) or_return
    case .BYTE_STORE:
        cell := stack_pop(&vm.data_stack) or_return
        value := stack_pop(&vm.data_stack) or_return
        addr := transmute(^u8)cell
        addr^ = cast(u8)value
    case .LITERAL:
        value := advance_cell(vm) or_return
        stack_push(&vm.data_stack, value) or_return
    case .DUP:
        // a := stack_peek(&vm.data_stack, 0) or_return
        a := stack_pop(&vm.data_stack) or_return
        stack_push(&vm.data_stack, a) or_return
        stack_push(&vm.data_stack, a) or_return
    case .SWAP:
        b := stack_pop(&vm.data_stack) or_return
        a := stack_pop(&vm.data_stack) or_return
        stack_push(&vm.data_stack, b) or_return
        stack_push(&vm.data_stack, a) or_return
    case .ROT:
        a := stack_pop(&vm.data_stack) or_return
        b := stack_pop(&vm.data_stack) or_return
        c := stack_pop(&vm.data_stack) or_return
        stack_push(&vm.data_stack, b) or_return
        stack_push(&vm.data_stack, a) or_return
        stack_push(&vm.data_stack, c) or_return
    case .R_TO_P:
        value := stack_pop(&vm.return_stack) or_return
        stack_push(&vm.data_stack, value) or_return
    case .P_TO_R:
        value := stack_pop(&vm.data_stack) or_return
        stack_push(&vm.return_stack, value) or_return
    case .EQUAL:
        b := stack_pop(&vm.data_stack) or_return
        a := stack_pop(&vm.data_stack) or_return
        stack_push(&vm.data_stack, a == b ? 1 : 0)
    case .LESS_THAN:
        b := stack_pop(&vm.data_stack) or_return
        a := stack_pop(&vm.data_stack) or_return
        stack_push(&vm.data_stack, a < b ? 1 : 0)
    case .GREATER_THAN:
        b := stack_pop(&vm.data_stack) or_return
        a := stack_pop(&vm.data_stack) or_return
        stack_push(&vm.data_stack, a > b ? 1 : 0)
    case .AND:
        b := stack_pop(&vm.data_stack) or_return
        a := stack_pop(&vm.data_stack) or_return
        stack_push(&vm.data_stack, a & b)
    case .OR:
        b := stack_pop(&vm.data_stack) or_return
        a := stack_pop(&vm.data_stack) or_return
        stack_push(&vm.data_stack, a | b)
    case .NOT:
        a := stack_pop(&vm.data_stack) or_return
        stack_push(&vm.data_stack, (a == 0) ? 1 : 0)
    case .DOT:
        value := stack_pop(&vm.data_stack) or_return
        vm.output_str(fmt.tprintf("%v", value))
    case .KEY:
        key: u32
        ok: bool
        for {
            key, ok = vm.get_key()
            if ok do break
        }
        stack_push(&vm.data_stack, cast(Cell)key)
    case .DROP:
        stack_pop(&vm.data_stack) or_return
    case .BRANCH:
        offset := advance_i16(vm) or_return
        vm.ip = mem.ptr_offset(vm.ip, cast(int)offset)
    case .BRANCH0:
        value := stack_pop(&vm.data_stack) or_return
        offset := advance_i16(vm) or_return
        if value == 0 {
            vm.ip = mem.ptr_offset(vm.ip, cast(int)offset)
        }
    case .RETURN:
        value := stack_pop(&vm.return_stack) or_return
        vm.ip = transmute(^u8)value
    case .CALL:
        value := advance_cell(vm) or_return
        stack_push(&vm.return_stack, transmute(Cell)vm.ip) or_return
        vm.ip = transmute(^u8)value
    case .CELL:
        stack_push(&vm.data_stack, size_of(Cell)) or_return
    case:
        return .Undefined
    }
    return nil
}
