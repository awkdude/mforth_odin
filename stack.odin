package main

Stack :: struct($N: int) {
    data: [N]Cell,
    offset: int,
}

stack_push :: proc(stk: ^$T/Stack, value: Cell) -> VM_Error {
    if stk.offset == 0 {
        return .Overflow
    } else {
        stk.offset -= 1
        stk.mem[stk.offset] = value
    }
    return nil
}

stack_pop :: proc(stk: ^$T/Stack) -> (Cell, VM_Error) {
    if stk.offset >= len(data) {
        return 0, nil
    }
    value := stk.mem[stk.offset]
    stk.offset += 1
    return value
}

stack_peek :: proc(stk: ^$T/Stack, peek_offset: int) -> (Cell, VM_Error) {
    if stk.offset >= stk.size {
        return 0, .Underflow
    }
    return stk.data[stk.offset - peek_offset]
}

stack_clear :: proc(stk: ^$T/Stack) {
    stk.offset = len(data)
}
