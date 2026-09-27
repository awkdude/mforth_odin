package main

import "odinlib:util"
import "core:text/edit"

Shortcut_Proc :: #type proc()

Shortcut :: struct {
    modifier: Maybe(util.Modifier_Key),
    keycode: u32,
    action: union { 
        rawptr, 
        edit.Command,
    },
}

SHORTCUTS := []Shortcut{
    {
        nil,
        util.KEY_ESCAPE, 
        cast(rawptr)proc() {
            lo, hi := edit.sorted_selection(&app.edit_state)
            app.edit_state.selection = {lo, lo}
        }
    },
    {
        nil,
        util.KEY_PAGEUP,
        cast(rawptr)proc() {
            app.font_path_index = util.wrap(app.font_path_index+1, len(FONT_PATHS))
            change_font()
        }
    },
    {
        nil,
        util.KEY_PAGEDOWN,
        cast(rawptr)proc() {
            app.colorscheme_index = util.wrap(app.colorscheme_index+1, len(COLORSCHEMES))
        }
    },
    {
        .Control,
        util.KEY_PLUS,
        cast(rawptr)proc() {
            app.font_pixel_height += 1
            change_font() 
        }
    },
    {
        .Control,
        util.KEY_MINUS,
        cast(rawptr)proc() {
            app.font_pixel_height -= 1
            change_font() 
        }
    },
    {.Shift, util.KEY_LEFT, .Select_Left},
    {nil, util.KEY_LEFT, .Left},
    {.Shift, util.KEY_RIGHT, .Select_Right},
    {nil, util.KEY_RIGHT, .Right},
    {nil, util.KEY_DELETE, .Delete},
    {.Control, util.KEY_BACKSPACE, .Delete_Word_Left},
    {nil, util.KEY_BACKSPACE, .Backspace},
    {nil, util.KEY_HOME, .Start},
    {nil, util.KEY_END, .End},
    {.Control, util.KEY_C, .Copy},
    {.Control, util.KEY_V, .Paste},
}

check_key_shortcut :: proc(
    key_event: util.Window_Event,
    modifier: Maybe(util.Modifier_Key)) -> bool
{
    if !(key_event.type == .Key && key_event.key.pressed) do return false
    for sh in SHORTCUTS {
        if key_event.key.keycode == sh.keycode && modifier == sh.modifier {
            switch action in sh.action {
            case rawptr:
                ac := cast(proc())action
                ac()
            case edit.Command:
                edit.perform_command(&app.edit_state, action)
            }
            return true
        }
    }
    return false
}
