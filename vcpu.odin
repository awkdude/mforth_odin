package main

Cell   :: int
UCell  :: uint
DCell  :: i128
UDCell :: u128

VM_Error :: enum {
    None,
    Undefined,
    Divide_By_Zero,
    Stack_Underflow,
    Stack_Overflow,
}

VM :: struct {
    memory: []u8,
    data_stack: Stack(16*1024),
    return_stack: Stack(1024),
    ip: Cell,
}

VM_Opcode :: enum {
    ADD,
    SUB,
    MUL,
    DIV,
    LITERAL,
    LOAD,
    STORE,
    BYTE_LOAD,
    BYTE_STORE,
    DROP,
    ROT,
    SWAP,
    R_TO_P,
    P_TO_R,
}
