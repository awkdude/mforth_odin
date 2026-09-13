package main

import "core:unicode"
import "core:strings"

// NOTE: Only works for ASCII
Scanner :: struct {
    str: string,
    offset: int,
}

scanner_next_word :: proc(scanner: ^Scanner) -> (string, bool) {
    if scanner.offset >= len(scanner.str) {
        return "", false
    }
    // Skip any spaces before next character
    for ; scanner.offset < len(scanner.str); scanner.offset += 1 { 
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

scanner_next_char :: proc(scanner: ^Scanner) -> (rune, bool) {
    if scanner.offset < len(scanner.str) {
        return cast(rune)scanner.str[scanner.offset], true
    }
    return 0, false
}
