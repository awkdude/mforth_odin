#+test
package main

import "core:testing"
import "core:strings"

@(test)
check_substring :: proc(t: ^testing.T) {
    s, ok := strings.substring("abc", 1, 0)
    testing.expect(t, !ok)
}
