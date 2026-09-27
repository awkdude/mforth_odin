#+test
package main

import "core:testing"
import "core:strings"

@(test)
check_substring :: proc(t: ^testing.T) {
    testing.expect_value(t, string_to_number("5"), 5)
    testing.expect_value(t, string_to_number(""), 0)
    testing.expect_value(t, string_to_number("41442"), 41442)
}
