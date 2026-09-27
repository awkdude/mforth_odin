package main

import "odinlib:util"
import "core:time"
import "core:unicode"
import "core:log"
import "core:fmt"
import "core:math"
import "core:slice"
import "core:mem"
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
    Current_Line,
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
            .Current_Line=Color4f{0.9, 0.9, 0.9, 1.0},
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
            .Current_Line=Color4f{0.2, 0.2, 0.2, 1.0},
            .Caret=COLOR_MAGENTA,
            .Builtin_Word=Color4f{0.9, 0.0, 0.05, 1.0},
            .Comment=Color4f{0.7, 0.7, 0.7, 1.0},
        }
    }
}

App_Init :: struct {
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
    packed_chars: [96]stbtt.bakedchar,
    // packed_chars: [96]stbtt.packedchar,
    render_group: Render_Group,
    edit_state: edit.State,
    edit_builder: strings.Builder,
    input_rune: Maybe(rune),
    start_pos: vec2f,
    caret_rect: Rect,
    font_pack_context: stbtt.pack_context,
    font_scale: f32,
    font_pixel_height: i32,
    font_ascent, font_descent, font_line_gap: i32,
    font_yadvance: f32,
    mouse_cursor: util.Mouse_Cursor_Type,
    exit_on_key_press: bool,
    vm: VM,
    history: [dynamic; 1*mem.Megabyte]u8,
}

app: ^App_Context

app_init :: proc(init_info: App_Init) -> bool {
    app = new(App_Context)
    app.init_info = init_info
    app.running = true
    app.edit_builder = strings.builder_make()
    strings.write_string(&app.edit_builder, default_text)
    edit.init(&app.edit_state, context.allocator, context.allocator)
    edit.setup_once(&app.edit_state, &app.edit_builder)
    app.edit_state.get_clipboard = proc(_: rawptr) -> (string, bool) {
        return get_clipboard_text()
    }
    app.edit_state.set_clipboard = proc(_: rawptr, text: string) -> bool {
        return set_clipboard_text(text)
    }
    do_platform_command({type=.Change_Window_Icon, path="forth.ico"})
    log.debug("Char dims:", app.char_dims)
    app.font_pixel_height = 32
    change_font()
    rg_init()
    vm_init(&app.vm)
    app.vm.output_str = proc(text: string) {
        fmt.printfln(text)
    }
    // assemble(&app.vm,
    //     "br 3 sq: dup mul ret lit 4 call sq dot lit 12 call sq dot")
    // compile(&app.vm, ": sq dup * ; 4 sq . 12 sq .")
    compile(&app.vm, ": sq dup * ; begin 4 sq . again")
    // write_byte(&app.vm, cast(u8)VM_Opcode.LITERAL)
    // write_cell(&app.vm, 100)
    // write_byte(&app.vm, cast(u8)VM_Opcode.LITERAL)
    // write_cell(&app.vm, 20)
    // write_byte(&app.vm, cast(u8)VM_Opcode.MUL)
    // write_byte(&app.vm, cast(u8)VM_Opcode.DOT)
    // write_byte(&app.vm, cast(u8)VM_Opcode.BRANCH)
    // write_i16(&app.vm, -23)
    if err := vm_run(&app.vm); err != .Done {
        log.errorf("VM_Error: %v", err)
    }
    fmt.println("DONE")
    for {}

    if len(os.args) > 1 {
        source_text, err := os.read_entire_file_from_path(os.args[1], context.allocator)
        if err == nil {
            source_text := cast(string)source_text
            strings.builder_reset(&app.edit_builder)
            strings.write_string(&app.edit_builder, source_text)
            interpret(&app.vm, source_text)
            app.exit_on_key_press = true
        }
    }
    return true
}

Textbox_Iterator :: struct {
    text: string,
    index: int,
    start_pos, pen_pos: vec2f,
    content_dims: vec2f,
    reached_carriage_return: bool,
    line: int,
    skip_newline: bool,
}

Textbox_Char :: struct {
    pos, dims, draw_pos: vec2f,
    src_rect: Rect,
    index: int,
    line: int,
    codepoint: rune,
    printable: bool,
}

textbox_iterator_init :: proc(
    tbi: ^Textbox_Iterator,
    text: string,
    start_pos: vec2f,
    content_dims: vec2) 
{
    tbi.text = text
    tbi.index = 0
    tbi.start_pos = start_pos
    tbi.pen_pos = start_pos
    tbi.content_dims = cast(vec2f)content_dims
    tbi.reached_carriage_return = false
}

textbox_iterator_next_char :: proc(tbi: ^Textbox_Iterator) -> (Textbox_Char, bool) {
    next_line :: #force_inline proc(tbi: ^Textbox_Iterator) {
        tbi.pen_pos.x = tbi.start_pos.x
        tbi.pen_pos.y += app.font_yadvance
    }
    if tbi.index >= len(tbi.text) {
        return {}, false
    }
    ch := cast(rune)tbi.text[tbi.index]
    tbc := Textbox_Char {
        codepoint=ch,
        pos=tbi.pen_pos,
        index=tbi.index,
    }
    tbi.index += 1
    if ch == 0 {
       return {}, false 
    } else if ch == '\r' {
        next_line(tbi)
        tbi.reached_carriage_return = true
        return tbc, true
    } else if ch == '\n' {
        if !tbi.reached_carriage_return {
            next_line(tbi)
        }
        return tbc, true
    }
    // tbi.reached_carriage_return = false
    pc_index := ch - 32
    if pc_index < 0 || pc_index >= len(app.packed_chars) {
        // FIXME:
        assert(false)
    }
    tbc.printable = true
    pc := app.packed_chars[pc_index]
    advance_width, left_side_bearing: i32
    stbtt.GetCodepointHMetrics(&app.font_info, ch, &advance_width, &left_side_bearing)
    if (tbi.pen_pos.x + cast(f32)pc.xadvance) > tbi.content_dims.x {
        next_line(tbi)
    }
    y := (cast(f32)app.font_ascent + pc.yoff)
    tbc.src_rect = Rect{
        x=cast(i32)pc.x0,
        y=cast(i32)pc.y0,
        w=cast(i32)(pc.x1 - pc.x0),
        h=cast(i32)(pc.y1 - pc.y0),
    }
    tbc.draw_pos = tbi.pen_pos + {(cast(f32)left_side_bearing*app.font_scale), y}
    tbc.dims = {pc.xadvance, app.font_yadvance}
    tbi.pen_pos.x += pc.xadvance
    return tbc, true
} 

colorscheme_elem_color :: #force_inline proc "contextless" (element_type: Colorscheme_Element) -> Color4f {
    return COLORSCHEMES[app.colorscheme_index].elements[element_type]
}

app_update :: proc(update_info: App_Update) -> bool {
    app.update_info = update_info
    edit.update_time(&app.edit_state)
    tbi: Textbox_Iterator
    text := strings.to_string(app.edit_builder)
    textbox_iterator_init(
        &tbi,
        text,
        app.start_pos,
        {app.update_info.framebuffer.w, app.update_info.framebuffer.h}
    )
    hovered_char_index := -1
    for tbc in textbox_iterator_next_char(&tbi) {
        if hovered_char_index == -1 {
            mouse_in_char := util.point_in_rect(
               app.input_state.mouse_position,
               Rect{
                   cast(i32)tbc.pos.x,
                   cast(i32)tbc.pos.y,
                   cast(i32)tbc.dims.x,
                   cast(i32)tbc.dims.y
               }
            )
            if mouse_in_char {
                hovered_char_index = tbc.index
            }
        }
    }
    if hovered_char_index != -1 && .Left in app.input_state.mouse_buttons {
        app.edit_state.selection = {hovered_char_index, hovered_char_index}
        reset_cursor_blink_state(true)
    }
    app.frame_index += 1
    app.input_state.transient = {}
    return app.running
}

app_render :: proc() {
    rg_clear(colorscheme_elem_color(.Background))
    pen_pos: util.vec2f
    rg_texture(app.font_pixmap)
    rg_color(colorscheme_elem_color(.Plain_Text))
    if len(strings.to_string(app.edit_builder)) == 0 {
        rg_blit({0, 0})
    }
    text := strings.to_string(app.edit_builder)
    // Draw caret
    if app.cursor_blink_state {
        selection_color := colorscheme_elem_color(.Caret)
        selection_color.a = 0.3
        rg_fill_rect(
            app.caret_rect,
            selection_color
        )
    }
    in_selection: bool
    hovered_char_index := -1
    reached_carriage_return: bool
    tbi: Textbox_Iterator
    textbox_iterator_init(
        &tbi,
        text,
        app.start_pos,
        {app.update_info.framebuffer.w, app.update_info.framebuffer.h}
    )

    for tbc in textbox_iterator_next_char(&tbi) {
        if tbc.printable {
            rg_blit(
                cast(vec2)tbc.draw_pos,
                tbc.src_rect,
            )
        }
        if tbc.index == app.edit_state.selection[0] {
            app.caret_rect = Rect {
                cast(i32)tbc.pos.x,
                cast(i32)tbc.pos.y,
                cast(i32)tbc.dims.x,
                cast(i32)tbc.dims.y,
            }
        }
    }
    app.cursor_blink_frame_counter -= 1
    if app.cursor_blink_frame_counter <= 0 {
        reset_cursor_blink_state()
    }
    rg_to_output(app.update_info.framebuffer)
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
            case util.KEY_TAB:
                if modifier_is_held(.Shift) {
                    app.start_pos.x -= 10
                } else {
                    app.start_pos.x += 10
                }
                app.start_pos.x = math.clamp(app.start_pos.x, 0, 100)
            }
            modifier: Maybe(util.Modifier_Key)
            if modifier_is_held(.Shift) {
                modifier = .Shift
            } else if modifier_is_held(.Control) {
                modifier = .Control
            } else if modifier_is_held(.Alt) {
                modifier = .Alt
            }
            check_key_shortcut(event, modifier)
        }
        reset_cursor_blink_state(true)
    case .Char_Input:
        if !modifier_is_held(.Control) && !modifier_is_held(.Alt) {
            codepoint := event.char_codepoint
            valid_input_char := (codepoint >= 32 && codepoint < 127) || codepoint == '\n' || codepoint == '\r'
            if valid_input_char {
                if codepoint == '\r' {
                    codepoint = '\n'
                }
                edit.input_rune(&app.edit_state, cast(rune)codepoint)
                reset_cursor_blink_state(true)
            }
        }
    case .Mouse_Button:
        if event.mouse_button.button == .Right {
            app.start_pos.y += 10
        } else if event.mouse_button.button == .Middle {
            app.start_pos.y -= 10
        }
        app.start_pos.x = math.clamp(app.start_pos.x, 0, 100)
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
        raw_data(app.packed_chars[:]),
    )
    when false {
        app.font_pack_context = {}
        assert(cast(bool)stbtt.PackBegin(
            &app.font_pack_context,
            cast([^]u8)app.font_pixmap.pixels,
            app.font_pixmap.w,
            app.font_pixmap.h,
            app.font_pixmap.pitch,
            1,
            nil 
        ))
        stbtt.PackSetOversampling(&app.font_pack_context, 2, 2)
        assert(cast(bool)stbtt.PackFontRange(
            &app.font_pack_context,
            raw_data(app.font_data),
            0,
            cast(f32)app.font_pixel_height,
            32,
            95,
            raw_data(app.packed_chars[:]),
        ))
        stbtt.PackEnd(&app.font_pack_context)
    }
    app.char_dims = {}
    for pc in app.packed_chars {
        diff_x := (f32)(pc.x1 - pc.x0)
        diff_y := (f32)(pc.y1 - pc.y0)
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
    app.font_yadvance = (f32)(app.font_ascent - app.font_descent + app.font_line_gap)
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
