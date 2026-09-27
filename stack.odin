package main

import "core:fmt"
import "core:mem"

Stack :: struct($N: int) {
    data: [N]Cell,
    pointer: ^Cell,
}

stack_push :: proc "contextless" (stk: ^$T/Stack, value: Cell) -> VM_Error {
    end := mem.ptr_offset(raw_data(stk.data[:]), len(stk.data))
    if stk.pointer >= end {
        return .Stack_Overflow
    } else {
        stk.pointer^ = value
        stk.pointer = mem.ptr_offset(stk.pointer, size_of(Cell))
    }
    return nil
}

stack_pop :: proc "contextless" (stk: ^$T/Stack) -> (Cell, VM_Error) {
    if stk.pointer == raw_data(stk.data[:]) {
        return 0, .Stack_Underflow
    }
    stk.pointer = mem.ptr_offset(stk.pointer, -size_of(Cell))
    return stk.pointer^, nil
}

stack_pop2 :: #force_inline proc "contextless" (stk: ^$T/Stack) -> (a: Cell, b: Cell, err: VM_Error) 
{
    b = stack_pop(stk) or_return
    a = stack_pop(stk) or_return
    return
}

stack_peek :: proc(stk: ^$T/Stack, peek_offset: int) -> (Cell, VM_Error) {
    if stk.pointer == raw_data(stk.data[:]) {
        return 0, .Stack_Underflow
    }
    // FIXME: I'm pretty sure this math is wrong! 
    idx := mem.ptr_sub(cast([^]Cell)stk.pointer, raw_data(stk.data[:]))
    assert(peek_offset == 0)
    return stk.data[idx+peek_offset], nil
}

stack_clear :: proc "contextless" (stk: ^$T/Stack) {
    stk.pointer = raw_data(stk.data[:])
}

stack_print :: proc (stk: ^$T/Stack) {
    fmt.print("<stack> ")
    for p := raw_data(stk.data[:]); p < stk.pointer; p = mem.ptr_offset(p, size_of(Cell))
    {
        fmt.print(p[0], "")
    }
    fmt.println("")
}
