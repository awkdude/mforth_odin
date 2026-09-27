package main

import "core:unicode"
import "core:strings"

// NOTE: Only works for ASCII
Scanner :: struct {
    str: string,
    line, column: int,
    offset: int,
    is_file: bool,
}

// TODO: make some proc that increments one char, which increments line and column number, then use this proc for these procs

scanner_init :: proc(scanner: ^Scanner, source: string) {
    scanner.line = 1
    scanner.column = 1
    scanner.str = source
}

scanner_next_word :: proc(scanner: ^Scanner) -> (string, bool) #optional_ok {
    if scanner.offset >= len(scanner.str) {
        return "", false
    }
    // Skip any spaces before next character
    for ; scanner.offset < len(scanner.str); scanner.offset += 1 {
        if scanner.str[scanner.offset] == '\n' {
            scanner.line += 1
            scanner.column = 1
        }
        if !unicode.is_space(cast(rune)scanner.str[scanner.offset]) {
            break
        }
    }
    token_start := scanner.offset
    for ; scanner.offset < len(scanner.str); scanner.offset += 1 {
        if unicode.is_space(cast(rune)scanner.str[scanner.offset]) {
            break
        }
    }
    token_end := scanner.offset
    if token_end == token_start {
        return "", false
    }
    return strings.substring(scanner.str, token_start, token_end)
}

scanner_next_char :: proc(scanner: ^Scanner) -> (rune, bool) #optional_ok {
    if scanner.offset < len(scanner.str) {
        offset := scanner.offset
        scanner.offset += 1
        return cast(rune)scanner.str[offset], true
    }
    return 0, false
}

scanner_skip_to_char :: proc "contextless" (scanner: ^Scanner, char: u8) -> (string, bool)
{
    start := scanner.offset
    for scanner.str[scanner.offset] != char {
        scanner.offset += 1
    }
    str := scanner.str[start:scanner.offset]
    scanner.offset += 1
    return str, scanner.offset < len(scanner.str)
}

scanner_goto_next_line :: proc "contextless" (scanner: ^Scanner) -> (string, bool) {
    return scanner_skip_to_char(scanner, '\n')
}

string_to_number :: proc (str: string, radix: int = 10) -> (int, bool) #optional_ok {
    value: int
    assert(radix == 10)
    is_neg: bool
    i: int
    if len(str) == 0 do return 0, false
    if str[i] == '-' {
        is_neg = true
        i += 1
    }
    switch radix {
    case 10:
        for ; i < len(str); i += 1 {
            if !(str[i] >= '0' && str[i] <= '9') {
                return 0, false
            }
            value *= 10
            value += (int)(str[i] - '0')
        }
    }
    return value, true
}
