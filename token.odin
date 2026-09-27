package main

import "core:strings"

Token :: struct {
    type: Token_Type,
    lexeme: string,
}

// TODO: Sort these by type
Token_Type :: enum {
    PLUS,
    MINUS,
    COLON,
    SEMICOLON,
    DUP,
    EQUAL,
    PAREN_LEFT,
    PAREN_RIGHT,
    NUMBER,
    OVER,
    MODULO,
    ROT,
    DIV,
    AT_SIGN,
    SWAP,
    BANG,
    ASTERISK,
    IF,
    ELSE,
    ENDIF,
    DOT_QUOTE,
    QUOTE,
    ERROR,
    EOF
}

token_from_lexeme :: proc(lexeme: string) -> (token: Token) {
    token.lexeme = lexeme
    lower_lexeme := strings.to_lower(lexeme, context.temp_allocator)
    switch lower_lexeme {
    case "+":
        token.type = .PLUS
    case "-":
        token.type = .MINUS
    case ":":
        token.type = .COLON
    case ";":
        token.type = .SEMICOLON
    case "dup":
        token.type = .DUP
    case:
        token.type = .ERROR
    }
    return token
}
