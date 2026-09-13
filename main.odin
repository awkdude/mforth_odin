package main

import "odinlib:util"
import "core:time"
import "core:unicode"
import "core:log"
import "core:math"
import "core:slice"
import "core:os"
import "core:strings"
import "core:text/edit"
import stbtt "vendor:stb/truetype"

PLATFORM_BACKEND :: #config(BACKEND, "native")

COLOR_BLACK   :: Color4f {0.0, 0.0, 0.0, 1.0}
COLOR_WHITE   :: Color4f {1.0, 1.0, 1.0, 1.0}
COLOR_GREY    :: Color4f {0.5, 0.5, 0.5, 1.0}
COLOR_MAGENTA :: Color4f {1.0, 0.0, 1.0, 1.0}
COLOR_GREEN   :: Color4f {0.0, 1.0, 0.0, 1.0}


Key_Shortcut :: struct {
    modifier: Maybe(util.Modifier_Key),
    keycode: u32,
    command: edit.Command,
}

FONT_PATHS := []string{
    "FSEX302.ttf",
    "consola.ttf",
}

default_text := "Hello, World! This is suppose to be a simple Forth REPL. This is written in Odin and uses some builtin libraries"

Colorscheme_Element :: enum {
    Background,
    Plain_Text,
    Selected_Text,
    Selection_Box,
    Caret,
    Builtin_Word,
    Comment,
}

Colorscheme :: struct {
    name: string,
    elements: [Colorscheme_Element]Color4f,
}

COLORSCHEMES := []Colorscheme {
    {
        name="light",
        elements={
            .Background=COLOR_WHITE,
            .Plain_Text=COLOR_BLACK,
            .Selected_Text=COLOR_GREEN,
            .Selection_Box=COLOR_MAGENTA,
            .Caret=COLOR_MAGENTA,
            .Builtin_Word=Color4f{0.6, 0.0, 0.05, 1.0},
            .Comment=COLOR_GREY,
        }
    },
    {
        name="dark",
        elements={
            .Background=COLOR_BLACK,
            .Plain_Text=COLOR_WHITE,
            .Selected_Text=COLOR_GREEN,
            .Selection_Box=COLOR_MAGENTA,
            .Caret=COLOR_MAGENTA,
            .Builtin_Word=Color4f{0.9, 0.0, 0.05, 1.0},
            .Comment=Color4f{0.7, 0.7, 0.7, 1.0},
        }
    }
}

App_Init :: struct {
    platform_command_proc: proc(_: util.Platform_Command),
    pixel_format: util.Pixel_Format,
}

App_Update :: struct {
    window_dims: util.vec2,
    framebuffer: util.Pixmap,
}

App_Context :: struct {
    running: bool,
    init_info: App_Init,
    update_info: App_Update,
    frame_index: int,
    cursor_blink_frame_counter: int,
    cursor_blink_state: bool,
    input_state: util.Input_State,
    colorscheme_index: int,
    font_data: []u8,
    font_info: stbtt.fontinfo,
    // text_buffer: [dynamic; 1024]u8,
    // text_buffer_cursor: int,
    font_path_index: int,
    font_pixmap: util.Pixmap,
    char_dims: vec2f,
    baked_chars: [96]stbtt.bakedchar,
    render_group: Render_Group,
    edit_state: edit.State,
    edit_builder: strings.Builder,
    input_rune: Maybe(rune),
    font_scale: f32,
    font_pixel_height: i32,
    font_ascent, font_descent, font_line_gap: i32
}

app: ^App_Context

app_init :: proc(init_info: App_Init) -> bool {
    app = new(App_Context)
    app.init_info = init_info
    app.running = true
    app.edit_builder = strings.builder_make()
    // strings.write_string(&app.edit_builder, default_text)
    edit.init(&app.edit_state, context.allocator, context.allocator)
    edit.setup_once(&app.edit_state, &app.edit_builder)
    app.edit_state.get_clipboard = proc(_: rawptr) -> (string, bool) {
        return get_clipboard_text()
    }
    app.edit_state.set_clipboard = proc(_: rawptr, text: string) -> bool {
        return set_clipboard_text(text)
    }
    log.debug("Char dims:", app.char_dims)
    change_font()
    rg_init()
    s := Scanner{str=": ( n -- n ) double 1 2 +   ;  "}
    for str in scanner_next_word(&s) {
        log.debugf("Len: %v; %s", len(str), str)
    }
    return true
}

colorscheme_elem_color :: #force_inline proc "contextless" (element_type: Colorscheme_Element) -> Color4f {
    return COLORSCHEMES[app.colorscheme_index].elements[element_type]
}

app_update_render :: proc(update_info: App_Update) -> bool {
    app.update_info = update_info
    edit.update_time(&app.edit_state)
    rg_clear(colorscheme_elem_color(.Background))
    pen_pos: util.vec2f
    rg_texture(app.font_pixmap)
    rg_color(colorscheme_elem_color(.Plain_Text))
    if len(strings.to_string(app.edit_builder)) == 0 {
        rg_blit({0, 0})
    }
    if key_mod_pair_is_pressed(.Control, util.KEY_C) {
        edit.perform_command(&app.edit_state, .Copy)
    }
    if key_mod_pair_is_pressed(.Control, util.KEY_V) {
        edit.perform_command(&app.edit_state, .Paste)
    }
    text := strings.to_string(app.edit_builder)
    if app.cursor_blink_state {
        selection_color := colorscheme_elem_color(.Caret)
        selection_color.a = 0.3
        rg_fill_rect(
            Rect{
                x=cast(i32)app.char_dims.x*cast(i32)app.edit_state.selection[0],
                y=cast(i32)0,
                w=cast(i32)app.char_dims.x,
                h=cast(i32)app.char_dims.y
            },
            selection_color
        )
    }
    in_selection: bool
    rg_begin_multithread()
    for c, i in text {
        if c == 0 {
            break
        }
        bc := app.baked_chars[c-32]
        advance_width, left_side_bearing: i32
        stbtt.GetCodepointHMetrics(&app.font_info, c, &advance_width, &left_side_bearing)
        y := (i32)(cast(f32)app.font_ascent + bc.yoff)
        h := cast(i32)(bc.y1 - bc.y0)
        sel_lo, sel_hi := edit.sorted_selection(&app.edit_state)
        if !in_selection {
            if i >= sel_lo && i <= sel_hi {
                in_selection = true
                if app.cursor_blink_state {
                    rg_color(colorscheme_elem_color(.Selected_Text))
                }
            }
        } else {
            if i > sel_hi {
                in_selection = false
                rg_color(colorscheme_elem_color(.Plain_Text))
            }
        }
        rg_blit(
            cast(vec2)pen_pos+{(i32)(cast(f32)left_side_bearing*app.font_scale), y},
            Rect{
                x=cast(i32)bc.x0,
                y=cast(i32)bc.y0,
                w=cast(i32)(bc.x1 - bc.x0),
                h=h,
            },
        )
        pen_pos.x += bc.xadvance
    }
    rg_end_multithread()
    app.cursor_blink_frame_counter -= 1
    if app.cursor_blink_frame_counter <= 0 {
        reset_cursor_blink_state()
    }
    rg_to_output(update_info.framebuffer)
    app.frame_index += 1
    app.input_state.transient = {}
    return app.running
}

reset_cursor_blink_state :: proc(set_state: Maybe(bool) = nil) {
    if set_state, ok := set_state.?; ok {
        app.cursor_blink_state = set_state
    } else {
        app.cursor_blink_state = !app.cursor_blink_state 
    }
    app.cursor_blink_frame_counter = 30
}

app_handle_event :: proc(event: util.Window_Event) {
    util.set_input_state_from_event(&app.input_state, event)
    #partial switch event.type {
    case .Key:
        if event.key.keycode == util.KEY_F4 || event.key.keycode == util.KEY_F5 {
            app.running = false
        }
        if event.key.pressed {
            switch event.key.keycode {
            case util.KEY_ESCAPE:
                // TODO: make no selection
                lo, hi := edit.sorted_selection(&app.edit_state)
                app.edit_state.selection = {lo, lo}
            case util.KEY_PAGEUP:
                app.font_path_index = util.wrap(app.font_path_index+1, len(FONT_PATHS))
                change_font()
            case util.KEY_PAGEDOWN:
                app.colorscheme_index = util.wrap(app.colorscheme_index+1, len(COLORSCHEMES))
            case util.KEY_NR_PLUS:
                if modifier_is_held(.Control) {
                    app.font_pixel_height += 1
                    change_font()
                }
            case util.KEY_NR_MINUS:
                if modifier_is_held(.Control) {
                    app.font_pixel_height -= 1
                    change_font()
                }
            case util.KEY_LEFT:
                if modifier_is_held(.Shift) {
                    edit.perform_command(&app.edit_state, .Select_Left)
                } else {
                    edit.perform_command(&app.edit_state, .Left)
                }
            case util.KEY_RIGHT:
                if modifier_is_held(.Shift) {
                    edit.perform_command(&app.edit_state, .Select_Right)
                } else {
                    edit.perform_command(&app.edit_state, .Right)
                }
            case util.KEY_DELETE:
                edit.perform_command(&app.edit_state, .Delete)
            case util.KEY_BACKSPACE:
                if modifier_is_held(.Control) {
                    edit.perform_command(&app.edit_state, .Delete_Word_Left)
                } else {
                    edit.perform_command(&app.edit_state, .Backspace)
                }
            case util.KEY_HOME:
                edit.perform_command(&app.edit_state, .Start)
            case util.KEY_END:
                edit.perform_command(&app.edit_state, .End)
            }
        }
        reset_cursor_blink_state(true)
    case .Char_Input:
        if !modifier_is_held(.Control) && !modifier_is_held(.Alt) {
            c := event.char_codepoint - 32 
            if c >= 0 && c < 96 {
                edit.input_rune(&app.edit_state, cast(rune)event.char_codepoint)
                reset_cursor_blink_state(true)
            }
        }
    case .Window_Close:
        app.running = false
    }
}

change_font :: proc() {
    app.font_pixel_height = math.clamp(app.font_pixel_height, 16, 64)
    font_path := FONT_PATHS[app.font_path_index]
    if app.font_data != nil {
        delete(app.font_data)
        app.font_data = nil
    }
    read_err: os.Error
    app.font_data, read_err = os.read_entire_file_from_path(font_path, context.allocator)
    assert(read_err == nil)
    assert(cast(bool)stbtt.InitFont(&app.font_info, raw_data(app.font_data), 0))
    if app.font_pixmap.pixels == nil {
        app.font_pixmap = util.make_pixmap(1024, 1024, util.Pixel_Format{bytes_per_pixel=1})
    }
    stbtt.BakeFontBitmap(
        raw_data(app.font_data),
        0,
        cast(f32)app.font_pixel_height,
        cast([^]u8)app.font_pixmap.pixels,
        app.font_pixmap.w,
        app.font_pixmap.h,
        32,
        96,
        raw_data(app.baked_chars[:]),
    )
    app.char_dims = {}
    for bc in app.baked_chars {
        diff_x := (f32)(bc.x1 - bc.x0)
        diff_y := (f32)(bc.y1 - bc.y0)
        if diff_x > app.char_dims.x {
            app.char_dims.x = diff_x
        }
        if diff_y > app.char_dims.y {
            app.char_dims.y = diff_y
        }
    }
    app.font_scale = stbtt.ScaleForPixelHeight(&app.font_info, cast(f32)app.font_pixel_height)
    stbtt.GetFontVMetrics(&app.font_info, &app.font_ascent, &app.font_descent, &app.font_line_gap)
    app.font_ascent = (i32)(cast(f32)app.font_ascent*app.font_scale)
    app.font_descent = (i32)(cast(f32)app.font_descent*app.font_scale)
}

key_mod_pair_is_pressed :: proc "contextless" (
    modifier: util.Modifier_Key, key: u32) -> bool
{
    return modifier_is_held(modifier) && util.bit_test(app.input_state.keys_pressed[:], key)
}

modifier_is_held :: proc "contextless" (modifier: util.Modifier_Key) -> bool {
    switch modifier {
    case .Shift:
        return util.bit_test(app.input_state.keyboard[:], util.KEY_LSHIFT) || util.bit_test(app.input_state.keyboard[:], util.KEY_RSHIFT)
    case .Control:
        return util.bit_test(app.input_state.keyboard[:], util.KEY_LCONTROL) || util.bit_test(app.input_state.keyboard[:], util.KEY_RCONTROL)
    case .Alt:
        return util.bit_test(app.input_state.keyboard[:], util.KEY_LALT) || util.bit_test(app.input_state.keyboard[:], util.KEY_RALT)
    }
    return false
}
