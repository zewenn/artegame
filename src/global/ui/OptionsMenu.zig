const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;
const clay = lm.deps.clay;

const AudioManager = @import("../audio/AudioManager.zig");
const SaveSystem = @import("../save/SaveSystem.zig");
const DevicePrompts = @import("../input/DevicePrompts.zig");
const ControlScheme = @import("../input/ControlScheme.zig");
const HUD = @import("../HUD.zig");
const utility_button = @import("buttons/utility_button.zig");

/// Tabs available in the options menu.
pub const OptionsTab = enum {
    audio,
    display,
    controls,
};

/// Volume channels adjustable in the audio tab.
pub const VolumeType = enum {
    master,
    music,
    sfx,
};

/// Currently active options tab.
pub var options_tab: OptionsTab = .audio;

/// Element ID index offset for tab bar buttons to avoid collision with row indices.
pub const TAB_BUTTON_INDEX_OFFSET: usize = 100;

/// Currently selected row index within the active tab.
pub var selected_index: usize = 0;

/// Previously selected row index used to trigger audio feedback on selection changes.
pub var previous_selected_index: usize = 0;

var stick_moved_x: bool = false;
var stick_moved_y: bool = false;
var just_opened: bool = false;
var back_button_clicked: bool = false;

const NavigationInputState = struct {
    navigate_up: bool,
    navigate_down: bool,
    navigate_left: bool,
    navigate_right: bool,
    select_pressed: bool,
    back_pressed: bool,
    tab_previous: bool,
    tab_next: bool,
};

const ControlBinding = struct {
    action: []const u8,
    keyboard_and_mouse: []const u8,
    gamepad: []const u8,
};

/// Resets the options menu state to default audio tab and zero selection.
pub fn reset() void {
    options_tab = .audio;
    selected_index = 0;
    previous_selected_index = 0;
    stick_moved_x = false;
    stick_moved_y = false;
    just_opened = true;
}

/// Draws the options menu panel, processes user input, and returns true if the menu was requested to close.
pub fn draw(ui_scale: f32, window_size: lm.Vector2, allocator: ?std.mem.Allocator) bool {
    back_button_clicked = false;

    const should_exit = if (just_opened) should_exit: {
        just_opened = false;
        break :should_exit false;
    } else handleInput();

    const panel_width_pixels = @min(window_size.x - 48, @round(680 * ui_scale));
    const panel_height_pixels = @min(window_size.y - 48, @round(520 * ui_scale));
    const panel_padding_pixels = lm.tou16(@round(20 * ui_scale));
    const title_font_size = lm.tou16(@max(18, @round(20 * ui_scale)));

    ui.new(.{
        .id = .ID("shared-options-panel"),
        .layout = .{
            .sizing = .{
                .w = .fixed(panel_width_pixels),
                .h = .fixed(panel_height_pixels),
            },
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = lm.tou16(@round(14 * ui_scale)),
            .padding = .all(panel_padding_pixels),
        },
        .background_color = ui.color(16, 18, 25, 250),
        .corner_radius = .all(12 * ui_scale),
        .border = .{
            .color = ui.color(55, 62, 80, 200),
            .width = .outside(1),
        },
    })({
        drawTitle(title_font_size);
        drawOptionsTabs(ui_scale);

        switch (options_tab) {
            .audio => drawAudioTab(panel_width_pixels, ui_scale, allocator),
            .display => drawDisplayTab(panel_width_pixels, ui_scale),
            .controls => drawControlsTab(panel_width_pixels, ui_scale),
        }

        drawBackButton(ui_scale);
    });

    if (selected_index != previous_selected_index) {
        AudioManager.playSfxPitched("audio/sfx/click.wav", 0.35, 0.1);
        previous_selected_index = selected_index;
    }

    if (should_exit or back_button_clicked) {
        AudioManager.playSfxPitched("audio/sfx/click.wav", 0.5, 0.0);
        return true;
    }

    return false;
}

fn drawTitle(title_font_size: u16) void {
    ui.new(.{
        .id = .ID("opt-title-wrap"),
        .layout = .{ .child_alignment = .{ .x = .center } },
    })({
        ui.text("SETTINGS & OPTIONS", .{
            .color = ui.color(240, 200, 100, 255),
            .font_size = title_font_size,
            .letter_spacing = 2,
            .alignment = .center,
            .font_id = ui.fontID("ui/fonts/Silkscreen-Bold.ttf"),
        });
    });
}

fn drawOptionsTabs(ui_scale: f32) void {
    const tab_font_size = lm.tou16(@max(11, @round(13 * ui_scale)));
    const is_gamepad = DevicePrompts.isGamepad();
    const previous_hint = if (is_gamepad) "LB" else "Q";
    const next_hint = if (is_gamepad) "RB" else "E";

    ui.new(.{
        .id = .ID("opt-tabs-bar"),
        .layout = .{
            .direction = .left_to_right,
            .child_gap = lm.tou16(@round(8 * ui_scale)),
            .child_alignment = .{ .y = .center },
        },
    })({
        drawTabHintBadge("opt-tab-hint-left", previous_hint, ui_scale);

        var active_tab_button_index: usize = TAB_BUTTON_INDEX_OFFSET + @backingInt(options_tab);

        utility_button.draw(
            TAB_BUTTON_INDEX_OFFSET + @backingInt(OptionsTab.audio),
            "AUDIO",
            &active_tab_button_index,
            activateTabButton,
            tab_font_size,
            1,
        );
        utility_button.draw(
            TAB_BUTTON_INDEX_OFFSET + @backingInt(OptionsTab.display),
            "DISPLAY",
            &active_tab_button_index,
            activateTabButton,
            tab_font_size,
            1,
        );
        utility_button.draw(
            TAB_BUTTON_INDEX_OFFSET + @backingInt(OptionsTab.controls),
            "CONTROLS",
            &active_tab_button_index,
            activateTabButton,
            tab_font_size,
            1,
        );

        drawTabHintBadge("opt-tab-hint-right", next_hint, ui_scale);
    });
}

fn activateTabButton(button_index: usize) void {
    if (button_index < TAB_BUTTON_INDEX_OFFSET) return;
    const tab_index = button_index - TAB_BUTTON_INDEX_OFFSET;
    const tabs = [_]OptionsTab{ .audio, .display, .controls };
    if (tab_index >= tabs.len) return;
    setTab(tabs[tab_index]);
}

fn drawTabHintBadge(identifier_string: []const u8, hint: []const u8, ui_scale: f32) void {
    const is_gamepad = DevicePrompts.isGamepad();
    clay.UI()(.{
        .id = .ID(identifier_string),
        .layout = .{
            .padding = .axes(
                lm.tou16(@max(2, @round(3 * ui_scale))),
                lm.tou16(@max(4, @round(6 * ui_scale))),
            ),
            .child_alignment = .{ .x = .center, .y = .center },
        },
        .background_color = if (is_gamepad) ui.color(55, 60, 75, 200) else ui.color(35, 40, 52, 200),
        .corner_radius = .all(if (is_gamepad) 8 * ui_scale else 4 * ui_scale),
        .border = .{
            .color = if (is_gamepad) ui.color(120, 130, 150, 180) else ui.color(70, 80, 100, 180),
            .width = .outside(1),
        },
    })({
        ui.text(hint, .{
            .color = ui.color(190, 200, 220, 230),
            .font_size = lm.tou16(@max(9, @round(10 * ui_scale))),
            .letter_spacing = 1,
        });
    });
}

fn drawAudioTab(panel_width_pixels: f32, ui_scale: f32, allocator: ?std.mem.Allocator) void {
    const content_width_pixels = panel_width_pixels - @round(48 * ui_scale);
    const row_height_pixels = @round(42 * ui_scale);

    ui.new(.{
        .id = .ID("opt-audio-content"),
        .layout = .{
            .sizing = .{ .w = .fixed(content_width_pixels) },
            .direction = .top_to_bottom,
            .child_gap = lm.tou16(@round(8 * ui_scale)),
            .child_alignment = .{ .x = .center },
        },
    })({
        drawVolumeRow(0, .master, "Master Volume", AudioManager.master_volume, content_width_pixels, row_height_pixels, ui_scale, allocator);
        drawVolumeRow(1, .music, "Music Volume", AudioManager.music_volume, content_width_pixels, row_height_pixels, ui_scale, allocator);
        drawVolumeRow(2, .sfx, "SFX Volume", AudioManager.sfx_volume, content_width_pixels, row_height_pixels, ui_scale, allocator);
        drawMuteRow(3, content_width_pixels, row_height_pixels, ui_scale);
    });
}

fn drawVolumeRow(
    index: usize,
    kind: VolumeType,
    label: []const u8,
    value: f32,
    row_width_pixels: f32,
    row_height_pixels: f32,
    ui_scale: f32,
    allocator: ?std.mem.Allocator,
) void {
    const is_selected = (selected_index == index);
    const percentage = @as(u32, @intFromFloat(@round(value * 100.0)));
    const button_size_pixels = @round(HUD.UTILITY_BUTTON_BASE_H * ui_scale);
    const bar_total_width_pixels = @round(160 * ui_scale);
    const bar_height_pixels = @round(10 * ui_scale);
    const gap_width_pixels = @round(10 * ui_scale);

    const percentage_text = if (allocator) |current_allocator|
        std.fmt.allocPrint(current_allocator, "{d}%", .{percentage}) catch "0%"
    else
        "0%";

    clay.UI()(.{
        .id = .IDI("opt-vol-row-", @intCast(index)),
        .layout = .{
            .sizing = .{
                .w = .fixed(row_width_pixels),
                .h = .fixed(row_height_pixels),
            },
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .padding = .axes(
                lm.tou16(@round(4 * ui_scale)),
                lm.tou16(@round(16 * ui_scale)),
            ),
        },
        .background_color = if (clay.hovered() or is_selected)
            ui.hex(0x2a1e23ff)
        else
            ui.hex(0x0c0c0cff),
        .corner_radius = .all(6 * ui_scale),
        .border = .{
            .color = if (clay.hovered() or is_selected)
                ui.color(240, 200, 100, 200)
            else
                ui.color(40, 46, 60, 120),
            .width = .outside(if (clay.hovered() or is_selected) 2 else 1),
        },
    })({
        if (clay.hovered()) selected_index = index;

        drawVolumeLabel(index, label, is_selected, ui_scale);
        drawVolumeStepButton(index, kind, -0.05, "-", button_size_pixels, ui_scale, "opt-vol-dec-");
        drawVolumeGap("opt-vol-gap-1-", index, gap_width_pixels);
        drawVolumeProgressBar(index, value, is_selected, bar_total_width_pixels, bar_height_pixels, ui_scale);
        drawVolumeGap("opt-vol-gap-2-", index, gap_width_pixels);
        drawVolumeStepButton(index, kind, 0.05, "+", button_size_pixels, ui_scale, "opt-vol-inc-");
        drawVolumePercentage(index, percentage_text, is_selected, ui_scale);
    });
}

fn drawVolumeLabel(index: usize, label: []const u8, is_selected: bool, ui_scale: f32) void {
    ui.new(.{
        .id = .IDI("opt-vol-label-", @intCast(index)),
        .layout = .{ .sizing = .{ .w = .fixed(@round(180 * ui_scale)) } },
    })({
        ui.text(label, .{
            .color = if (is_selected) ui.color(255, 235, 170, 255) else ui.color(220, 225, 235, 255),
            .font_size = lm.tou16(@max(12, @round(13 * ui_scale))),
            .letter_spacing = 1,
            .font_id = ui.fontID("ui/fonts/Silkscreen-Regular.ttf"),
        });
    });
}

fn drawVolumeStepButton(
    index: usize,
    kind: VolumeType,
    delta: f32,
    symbol: []const u8,
    button_size_pixels: f32,
    ui_scale: f32,
    identifier_prefix: []const u8,
) void {
    const button_id = clay.ElementId.IDI(identifier_prefix, @intCast(index));
    const is_hovered = clay.pointerOver(button_id);
    clay.UI()(.{
        .id = button_id,
        .layout = .{
            .sizing = .{ .w = .fixed(button_size_pixels), .h = .fixed(button_size_pixels) },
            .child_alignment = .{ .x = .center, .y = .center },
        },
        .background_color = if (clay.hovered() or is_hovered) ui.color(50, 58, 78, 255) else ui.color(30, 35, 48, 220),
    })({
        if ((clay.hovered() or is_hovered) and lm.mouse.getButtonDown(.left)) {
            selected_index = index;
            adjustVolume(kind, delta);
        }
        ui.text(symbol, .{
            .color = ui.color(255, 255, 255, 255),
            .font_size = lm.tou16(@max(14, @round(16 * ui_scale))),
            .alignment = .center,
        });
    });
}

fn drawVolumeGap(identifier_prefix: []const u8, index: usize, width_pixels: f32) void {
    ui.new(.{
        .id = clay.ElementId.IDI(identifier_prefix, @intCast(index)),
        .layout = .{ .sizing = .{ .w = .fixed(width_pixels) } },
    })({});
}

fn drawVolumeProgressBar(
    index: usize,
    value: f32,
    is_selected: bool,
    bar_total_width_pixels: f32,
    bar_height_pixels: f32,
    ui_scale: f32,
) void {
    const bar_filled_width_pixels = @max(0.0, bar_total_width_pixels * value);

    ui.new(.{
        .id = .IDI("opt-vol-bar-", @intCast(index)),
        .layout = .{
            .sizing = .{ .w = .fixed(bar_total_width_pixels), .h = .fixed(bar_height_pixels) },
            .direction = .left_to_right,
        },
        .background_color = ui.color(24, 28, 38, 255),
        .corner_radius = .all(4 * ui_scale),
    })({
        drawVolumeBarFill(index, bar_filled_width_pixels, is_selected, ui_scale);
    });
}

fn drawVolumeBarFill(
    index: usize,
    filled_width_pixels: f32,
    is_selected: bool,
    ui_scale: f32,
) void {
    if (filled_width_pixels <= 0.5) return;

    const fill_color = if (AudioManager.mute)
        ui.color(140, 60, 60, 220)
    else if (is_selected)
        ui.color(240, 200, 100, 255)
    else
        ui.color(70, 140, 230, 255);

    ui.new(.{
        .id = .IDI("opt-vol-fill-", @intCast(index)),
        .layout = .{ .sizing = .{ .w = .fixed(filled_width_pixels), .h = .percent(1) } },
        .background_color = fill_color,
        .corner_radius = .all(4 * ui_scale),
    })({});
}

fn drawVolumePercentage(
    index: usize,
    percentage_text: []const u8,
    is_selected: bool,
    ui_scale: f32,
) void {
    ui.new(.{
        .id = .IDI("opt-vol-pct-", @intCast(index)),
        .layout = .{
            .sizing = .{ .w = .fixed(@round(56 * ui_scale)) },
            .child_alignment = .{ .x = .right, .y = .center },
        },
    })({
        ui.text(percentage_text, .{
            .color = if (is_selected) ui.color(240, 200, 100, 255) else ui.color(180, 185, 200, 255),
            .font_size = lm.tou16(@max(12, @round(13 * ui_scale))),
            .alignment = .right,
        });
    });
}

fn drawMuteRow(index: usize, row_width_pixels: f32, row_height_pixels: f32, ui_scale: f32) void {
    const is_selected = (selected_index == index);
    const is_muted = AudioManager.mute;

    clay.UI()(.{
        .id = .IDI("opt-mute-row-", @intCast(index)),
        .layout = .{
            .sizing = .{
                .w = .fixed(row_width_pixels),
                .h = .fixed(row_height_pixels),
            },
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .padding = .axes(
                lm.tou16(@round(4 * ui_scale)),
                lm.tou16(@round(16 * ui_scale)),
            ),
        },
        .background_color = if (clay.hovered() or is_selected)
            ui.color(28, 33, 46, 220)
        else
            ui.color(20, 23, 31, 160),
        .corner_radius = .all(6 * ui_scale),
        .border = .{
            .color = if (clay.hovered() or is_selected)
                ui.color(240, 200, 100, 200)
            else
                ui.color(40, 46, 60, 120),
            .width = .outside(if (clay.hovered() or is_selected) 2 else 1),
        },
    })({
        if (clay.hovered()) {
            selected_index = index;
        }

        ui.new(.{
            .id = .ID("opt-mute-label-wrap"),
            .layout = .{ .sizing = .{ .w = .fixed(@round(180 * ui_scale)) } },
        })({
            ui.text("Mute All Audio", .{
                .color = if (is_selected) ui.color(255, 235, 170, 255) else ui.color(220, 225, 235, 255),
                .font_size = lm.tou16(@max(12, @round(13 * ui_scale))),
                .letter_spacing = 1,
            });
        });

        const mute_caption = if (is_muted) "MUTED" else "UNMUTED";
        const badge_font_size = lm.tou16(@max(9, @round(10 * ui_scale)));
        utility_button.draw(index, mute_caption, &selected_index, activateMuteButton, badge_font_size, 1);
    });
}

fn activateMuteButton(_: usize) void {
    toggleMuteAudio();
}

fn drawDisplayTab(panel_width_pixels: f32, ui_scale: f32) void {
    const content_width_pixels = panel_width_pixels - @round(48 * ui_scale);
    const row_height_pixels = @round(44 * ui_scale);

    ui.new(.{
        .id = .ID("opt-display-content"),
        .layout = .{
            .sizing = .{ .w = .fixed(content_width_pixels) },
            .direction = .top_to_bottom,
            .child_gap = lm.tou16(@round(10 * ui_scale)),
            .child_alignment = .{ .x = .center },
        },
    })({
        drawFullscreenRow(content_width_pixels, row_height_pixels, ui_scale);
    });
}

fn drawFullscreenRow(content_width_pixels: f32, row_height_pixels: f32, ui_scale: f32) void {
    const is_selected = (selected_index == 0);
    const is_fullscreen = lm.window.fullscreen.get();

    clay.UI()(.{
        .id = .ID("opt-fullscreen-row"),
        .layout = .{
            .sizing = .{
                .w = .fixed(content_width_pixels),
                .h = .fixed(row_height_pixels),
            },
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .padding = .axes(
                lm.tou16(@round(4 * ui_scale)),
                lm.tou16(@round(16 * ui_scale)),
            ),
        },
        .background_color = if (clay.hovered() or is_selected)
            ui.color(28, 33, 46, 220)
        else
            ui.color(20, 23, 31, 160),
        .corner_radius = .all(6 * ui_scale),
        .border = .{
            .color = if (clay.hovered() or is_selected)
                ui.color(240, 200, 100, 200)
            else
                ui.color(40, 46, 60, 120),
            .width = .outside(if (clay.hovered() or is_selected) 2 else 1),
        },
    })({
        if (clay.hovered()) {
            selected_index = 0;
        }

        ui.new(.{
            .id = .ID("opt-fullscreen-label-wrap"),
            .layout = .{ .sizing = .{ .w = .fixed(@round(220 * ui_scale)) } },
        })({
            ui.text("Display Mode", .{
                .color = if (is_selected) ui.color(255, 235, 170, 255) else ui.color(220, 225, 235, 255),
                .font_size = lm.tou16(@max(12, @round(13 * ui_scale))),
                .letter_spacing = 1,
            });
        });

        const fullscreen_caption = if (is_fullscreen) "FULLSCREEN" else "WINDOWED";
        const badge_font_size = lm.tou16(@max(9, @round(10 * ui_scale)));
        utility_button.draw(0, fullscreen_caption, &selected_index, activateFullscreenButton, badge_font_size, 1);
    });
}

fn activateFullscreenButton(_: usize) void {
    toggleFullscreenMode();
}

fn drawControlsTab(panel_width_pixels: f32, ui_scale: f32) void {
    const content_width_pixels = panel_width_pixels - @round(48 * ui_scale);
    const header_font_size = lm.tou16(@max(11, @round(12 * ui_scale)));
    const row_font_size = lm.tou16(@max(10, @round(12 * ui_scale)));
    const row_height_pixels = @round(36 * ui_scale);
    const is_gamepad = DevicePrompts.isGamepad();
    const active_scheme = ControlScheme.getControlScheme();
    const is_keyboard_only = (active_scheme == .keyboard_only);

    const bindings = [_]ControlBinding{
        .{ .action = "Move", .keyboard_and_mouse = "W, A, S, D", .gamepad = "Left Stick" },
        .{ .action = "Aim / Look", .keyboard_and_mouse = if (is_keyboard_only) "Arrow Keys (8-Way)" else "Mouse Cursor", .gamepad = "Right Stick" },
        .{ .action = "Light Attack", .keyboard_and_mouse = if (is_keyboard_only) "Arrow Keys" else "Left Mouse Button", .gamepad = "Right Trigger (RT)" },
        .{ .action = "Heavy Attack", .keyboard_and_mouse = if (is_keyboard_only) "Shift + Arrow Keys" else "Right Mouse Button", .gamepad = "Left Trigger (LT)" },
        .{ .action = "Dash", .keyboard_and_mouse = "Spacebar", .gamepad = "A Button (South)" },
        .{ .action = "Cast Spell 1", .keyboard_and_mouse = "Q Key", .gamepad = "Left Bumper (LB)" },
        .{ .action = "Cast Spell 2", .keyboard_and_mouse = "E Key", .gamepad = "Right Bumper (RB)" },
        .{ .action = "Interact", .keyboard_and_mouse = "F Key", .gamepad = "X Button (West)" },
        .{ .action = "Pause / Menu", .keyboard_and_mouse = "Escape", .gamepad = "Start / Options" },
    };

    ui.new(.{
        .id = .ID("opt-controls-content"),
        .layout = .{
            .sizing = .{ .w = .fixed(content_width_pixels) },
            .direction = .top_to_bottom,
            .child_gap = lm.tou16(@round(3 * ui_scale)),
        },
    })({
        drawControlSchemeRow(content_width_pixels, row_height_pixels, ui_scale);
        drawControlsTableHeader(content_width_pixels, header_font_size, ui_scale);

        for (bindings, 0..) |binding, binding_index| {
            drawControlBindingRow(binding, binding_index, content_width_pixels, row_font_size, is_gamepad, ui_scale);
        }
    });
}

fn drawControlSchemeRow(content_width_pixels: f32, row_height_pixels: f32, ui_scale: f32) void {
    const active_scheme = ControlScheme.getControlScheme();
    const is_selected = (selected_index == 0);

    clay.UI()(.{
        .id = .ID("opt-scheme-row"),
        .layout = .{
            .sizing = .{
                .w = .fixed(content_width_pixels),
                .h = .fixed(row_height_pixels),
            },
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .padding = .axes(
                lm.tou16(@round(4 * ui_scale)),
                lm.tou16(@round(16 * ui_scale)),
            ),
        },
        .background_color = if (clay.hovered() or is_selected)
            ui.color(28, 33, 46, 220)
        else
            ui.color(20, 23, 31, 160),
        .corner_radius = .all(6 * ui_scale),
        .border = .{
            .color = if (clay.hovered() or is_selected)
                ui.color(240, 200, 100, 200)
            else
                ui.color(40, 46, 60, 120),
            .width = .outside(if (clay.hovered() or is_selected) 2 else 1),
        },
    })({
        if (clay.hovered()) {
            selected_index = 0;
        }

        ui.new(.{
            .id = .ID("opt-scheme-label-wrap"),
            .layout = .{ .sizing = .{ .w = .fixed(@round(220 * ui_scale)) } },
        })({
            ui.text("Control Scheme", .{
                .color = if (is_selected) ui.color(255, 235, 170, 255) else ui.color(220, 225, 235, 255),
                .font_size = lm.tou16(@max(12, @round(13 * ui_scale))),
                .letter_spacing = 1,
            });
        });

        const badge_font_size = lm.tou16(@max(8, @round(8 * ui_scale)));
        utility_button.draw(0, active_scheme.displayName(), &selected_index, activateControlSchemeButton, badge_font_size, 0);
    });
}

fn activateControlSchemeButton(_: usize) void {
    toggleControlScheme();
}

fn drawControlsTableHeader(content_width_pixels: f32, header_font_size: u16, ui_scale: f32) void {
    const is_gamepad = DevicePrompts.isGamepad();
    const active_scheme = ControlScheme.getControlScheme();
    const is_keyboard_only = (active_scheme == .keyboard_only);

    ui.new(.{
        .id = .ID("opt-ctrl-header"),
        .layout = .{
            .sizing = .{ .w = .fixed(content_width_pixels), .h = .fixed(@round(22 * ui_scale)) },
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .padding = .axes(0, lm.tou16(@round(8 * ui_scale))),
        },
        .background_color = ui.color(25, 30, 42, 220),
        .corner_radius = .all(4 * ui_scale),
    })({
        drawControlsHeaderCell("opt-table-header-1", @round(160 * ui_scale), "ACTION", ui.color(240, 200, 100, 255), header_font_size);

        const keyboard_and_mouse_header = if (!is_gamepad)
            (if (is_keyboard_only) "KEYBOARD ONLY (ACTIVE)" else "KEYBOARD & MOUSE (ACTIVE)")
        else
            active_scheme.displayName();
        const keyboard_color = if (!is_gamepad) ui.color(255, 235, 140, 255) else ui.color(150, 160, 180, 200);
        drawControlsHeaderCell("opt-table-header-2", @round(190 * ui_scale), keyboard_and_mouse_header, keyboard_color, header_font_size);

        const gamepad_header = if (is_gamepad) "CONTROLLER (ACTIVE)" else "CONTROLLER";
        const gamepad_color = if (is_gamepad) ui.color(255, 235, 140, 255) else ui.color(150, 160, 180, 200);
        drawControlsHeaderGrowCell("opt-table-header-3", gamepad_header, gamepad_color, header_font_size);
    });
}

fn drawControlsHeaderCell(
    identifier_string: []const u8,
    width_pixels: f32,
    header_text: []const u8,
    text_color: clay.Color,
    font_size: u16,
) void {
    ui.new(.{
        .id = .ID(identifier_string),
        .layout = .{ .sizing = .{ .w = .fixed(width_pixels) } },
    })({
        ui.text(header_text, .{
            .color = text_color,
            .font_size = font_size,
            .letter_spacing = 1,
        });
    });
}

fn drawControlsHeaderGrowCell(
    identifier_string: []const u8,
    header_text: []const u8,
    text_color: clay.Color,
    font_size: u16,
) void {
    ui.new(.{
        .id = .ID(identifier_string),
        .layout = .{ .sizing = .{ .w = .grow } },
    })({
        ui.text(header_text, .{
            .color = text_color,
            .font_size = font_size,
            .letter_spacing = 1,
        });
    });
}

fn drawControlBindingRow(
    binding: ControlBinding,
    binding_index: usize,
    content_width_pixels: f32,
    row_font_size: u16,
    is_gamepad: bool,
    ui_scale: f32,
) void {
    const is_even = (binding_index % 2 == 0);
    const background = if (is_even) ui.color(18, 21, 28, 180) else ui.color(14, 16, 22, 180);

    ui.new(.{
        .id = .IDI("opt-control-row-", @intCast(binding_index)),
        .layout = .{
            .sizing = .{ .w = .fixed(content_width_pixels), .h = .fixed(@round(20 * ui_scale)) },
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .padding = .axes(0, lm.tou16(@round(8 * ui_scale))),
        },
        .background_color = background,
    })({
        drawBindingCell("opt-cell-action-", binding_index, @round(160 * ui_scale), binding.action, ui.color(225, 230, 240, 255), row_font_size);

        const keyboard_color = if (!is_gamepad) ui.color(240, 245, 255, 255) else ui.color(140, 150, 170, 180);
        drawBindingCell("opt-cell-kbm-", binding_index, @round(190 * ui_scale), binding.keyboard_and_mouse, keyboard_color, row_font_size);

        const gamepad_color = if (is_gamepad) ui.color(240, 245, 255, 255) else ui.color(140, 150, 170, 180);
        drawBindingGrowCell("opt-cell-pad-", binding_index, binding.gamepad, gamepad_color, row_font_size);
    });
}

fn drawBindingCell(
    identifier_prefix: []const u8,
    binding_index: usize,
    width_pixels: f32,
    cell_text: []const u8,
    text_color: clay.Color,
    font_size: u16,
) void {
    ui.new(.{
        .id = clay.ElementId.IDI(identifier_prefix, @intCast(binding_index)),
        .layout = .{ .sizing = .{ .w = .fixed(width_pixels) } },
    })({
        ui.text(cell_text, .{
            .color = text_color,
            .font_size = font_size,
        });
    });
}

fn drawBindingGrowCell(
    identifier_prefix: []const u8,
    binding_index: usize,
    cell_text: []const u8,
    text_color: clay.Color,
    font_size: u16,
) void {
    ui.new(.{
        .id = clay.ElementId.IDI(identifier_prefix, @intCast(binding_index)),
        .layout = .{ .sizing = .{ .w = .grow } },
    })({
        ui.text(cell_text, .{
            .color = text_color,
            .font_size = font_size,
        });
    });
}

fn drawBackButton(ui_scale: f32) void {
    const back_index = getBackIndex();
    const back_label = if (DevicePrompts.isGamepad()) "BACK" else "BACK";
    const font_size = lm.tou16(@max(9, @round(11 * ui_scale)));
    utility_button.draw(back_index, back_label, &selected_index, activateBackButton, font_size, 1);
}

fn activateBackButton(_: usize) void {
    back_button_clicked = true;
}

fn handleInput() bool {
    const input_state = readNavigationState();
    if (input_state.back_pressed) {
        return true;
    }

    if (handleTabInput(input_state)) {
        return false;
    }

    const back_index = getBackIndex();
    updateVerticalSelection(input_state.navigate_up, input_state.navigate_down, back_index);

    return switch (options_tab) {
        .audio => handleAudioTabAction(input_state, back_index),
        .display => handleDisplayTabAction(input_state, back_index),
        .controls => handleControlsTabAction(input_state, back_index),
    };
}

fn readNavigationState() NavigationInputState {
    DevicePrompts.update();

    var state: NavigationInputState = .{
        .navigate_up = lm.keyboard.getKeyDown(.up) or lm.keyboard.getKeyDown(.w),
        .navigate_down = lm.keyboard.getKeyDown(.down) or lm.keyboard.getKeyDown(.s),
        .navigate_left = lm.keyboard.getKeyDown(.left) or lm.keyboard.getKeyDown(.a),
        .navigate_right = lm.keyboard.getKeyDown(.right) or lm.keyboard.getKeyDown(.d),
        .select_pressed = lm.keyboard.getKeyDown(.enter),
        .back_pressed = lm.keyboard.getKeyDown(.escape),
        .tab_previous = lm.keyboard.getKeyDown(.q),
        .tab_next = lm.keyboard.getKeyDown(.e) or lm.keyboard.getKeyDown(.tab),
    };

    if (!lm.gamepad.isAvailable(0)) {
        return state;
    }

    applyGamepadInput(&state);
    return state;
}

fn applyGamepadInput(state: *NavigationInputState) void {
    state.navigate_up = state.navigate_up or lm.gamepad.getButtonDown(0, .left_face_up);
    state.navigate_down = state.navigate_down or lm.gamepad.getButtonDown(0, .left_face_down);
    state.navigate_left = state.navigate_left or lm.gamepad.getButtonDown(0, .left_face_left);
    state.navigate_right = state.navigate_right or lm.gamepad.getButtonDown(0, .left_face_right);
    state.select_pressed = state.select_pressed or lm.gamepad.getButtonDown(0, .right_face_down);
    state.back_pressed = state.back_pressed or lm.gamepad.getButtonDown(0, .right_face_right) or
        lm.gamepad.getButtonDown(0, .middle_right) or lm.gamepad.getButtonDown(0, .middle);
    state.tab_previous = state.tab_previous or lm.gamepad.getButtonDown(0, .left_trigger_1);
    state.tab_next = state.tab_next or lm.gamepad.getButtonDown(0, .right_trigger_1);

    const stick = lm.gamepad.getStickVector(0, .left, 0.25);
    applyGamepadStickY(stick.y, &state.navigate_up, &state.navigate_down);
    applyGamepadStickX(stick.x, &state.navigate_left, &state.navigate_right);
}

fn applyGamepadStickY(stick_y: f32, navigate_up: *bool, navigate_down: *bool) void {
    if (@abs(stick_y) <= 0.5) {
        stick_moved_y = false;
        return;
    }
    if (stick_moved_y) return;

    if (stick_y < -0.5) navigate_up.* = true;
    if (stick_y > 0.5) navigate_down.* = true;
    stick_moved_y = true;
}

fn applyGamepadStickX(stick_x: f32, navigate_left: *bool, navigate_right: *bool) void {
    if (@abs(stick_x) <= 0.5) {
        stick_moved_x = false;
        return;
    }
    if (stick_moved_x) return;

    if (stick_x < -0.5) navigate_left.* = true;
    if (stick_x > 0.5) navigate_right.* = true;
    stick_moved_x = true;
}

fn handleTabInput(state: NavigationInputState) bool {
    if (state.tab_previous) {
        cycleTab(-1);
        return true;
    }
    if (state.tab_next) {
        cycleTab(1);
        return true;
    }
    return false;
}

fn updateVerticalSelection(navigate_up: bool, navigate_down: bool, back_index: usize) void {
    if (navigate_up) {
        selected_index = if (selected_index == 0) back_index else selected_index - 1;
    }
    if (navigate_down) {
        selected_index = if (selected_index >= back_index) 0 else selected_index + 1;
    }
}

fn handleAudioTabAction(state: NavigationInputState, back_index: usize) bool {
    if (state.navigate_left) {
        adjustSelectedAudioVolume(-0.05);
    }
    if (state.navigate_right) {
        adjustSelectedAudioVolume(0.05);
    }
    if (state.select_pressed) {
        if (selected_index == 3) {
            toggleMuteAudio();
        } else if (selected_index == back_index) {
            return true;
        }
    }
    return false;
}

fn adjustSelectedAudioVolume(delta: f32) void {
    switch (selected_index) {
        0 => adjustVolume(.master, delta),
        1 => adjustVolume(.music, delta),
        2 => adjustVolume(.sfx, delta),
        3 => toggleMuteAudio(),
        else => {},
    }
}

fn handleDisplayTabAction(state: NavigationInputState, back_index: usize) bool {
    const is_action_pressed = state.navigate_left or state.navigate_right or state.select_pressed;
    if (!is_action_pressed) return false;

    if (selected_index == 0) {
        toggleFullscreenMode();
        return false;
    }
    if (selected_index == back_index) {
        return true;
    }
    return false;
}

fn handleControlsTabAction(state: NavigationInputState, back_index: usize) bool {
    const is_action_pressed = state.navigate_left or state.navigate_right or state.select_pressed;
    if (!is_action_pressed) return false;

    if (selected_index == 0) {
        toggleControlScheme();
        return false;
    }
    if (selected_index == back_index) {
        return true;
    }
    return false;
}

/// Sets the current active tab and resets row selection.
pub fn setTab(tab: OptionsTab) void {
    if (options_tab == tab) return;

    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.45, 0.05);
    options_tab = tab;
    selected_index = 0;
    previous_selected_index = 0;
}

/// Cycles the current tab forward or backward by delta.
pub fn cycleTab(delta: i32) void {
    const current = @as(i32, @intCast(@backingInt(options_tab)));
    const tab_count: i32 = 3;
    const next_value = @mod(current + delta, tab_count);
    setTab(@fromBackingInt(@intCast(@as(usize, @intCast(next_value)))));
}

/// Returns the index of the back button for the currently active tab.
pub fn getBackIndex() usize {
    return switch (options_tab) {
        .audio => 4,
        .display => 1,
        .controls => 1,
    };
}

/// Adjusts the volume of the specified channel by delta and persists the updated settings.
pub fn adjustVolume(kind: VolumeType, delta: f32) void {
    switch (kind) {
        .master => AudioManager.setMasterVolume(AudioManager.master_volume + delta),
        .music => AudioManager.setMusicVolume(AudioManager.music_volume + delta),
        .sfx => AudioManager.setSfxVolume(AudioManager.sfx_volume + delta),
    }
    SaveSystem.updateSettings(
        AudioManager.master_volume,
        AudioManager.music_volume,
        AudioManager.sfx_volume,
        AudioManager.mute,
    );
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.35, 0.15);
}

/// Toggles master audio mute state and persists settings.
pub fn toggleMuteAudio() void {
    AudioManager.toggleMute();
    SaveSystem.updateSettings(
        AudioManager.master_volume,
        AudioManager.music_volume,
        AudioManager.sfx_volume,
        AudioManager.mute,
    );
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.5, 0.05);
}

/// Toggles the application between windowed and fullscreen display modes.
pub fn toggleFullscreenMode() void {
    lm.window.fullscreen.toggle();
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.5, 0.05);
}

/// Toggles the active input control scheme and persists settings.
pub fn toggleControlScheme() void {
    const next_scheme: ControlScheme.ControlScheme = switch (ControlScheme.getControlScheme()) {
        .keyboard_and_mouse => .keyboard_only,
        .keyboard_only => .keyboard_and_mouse,
    };
    ControlScheme.setControlScheme(next_scheme);
    SaveSystem.updateControlScheme(next_scheme);
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.5, 0.05);
}

test "OptionsMenu tab cycling and back index resolution" {
    reset();
    try std.testing.expectEqual(OptionsTab.audio, options_tab);
    try std.testing.expectEqual(@as(usize, 4), getBackIndex());

    cycleTab(1);
    try std.testing.expectEqual(OptionsTab.display, options_tab);
    try std.testing.expectEqual(@as(usize, 1), getBackIndex());

    cycleTab(1);
    try std.testing.expectEqual(OptionsTab.controls, options_tab);
    try std.testing.expectEqual(@as(usize, 1), getBackIndex());

    cycleTab(1);
    try std.testing.expectEqual(OptionsTab.audio, options_tab);

    cycleTab(-1);
    try std.testing.expectEqual(OptionsTab.controls, options_tab);
}

test "OptionsMenu toggleControlScheme cycles scheme and updates SaveSystem" {
    ControlScheme.setControlScheme(.keyboard_and_mouse);
    toggleControlScheme();
    try std.testing.expectEqual(ControlScheme.ControlScheme.keyboard_only, ControlScheme.getControlScheme());
    toggleControlScheme();
    try std.testing.expectEqual(ControlScheme.ControlScheme.keyboard_and_mouse, ControlScheme.getControlScheme());
}

test "OptionsMenu volume clamping bounds" {
    AudioManager.setMasterVolume(0.95);
    adjustVolume(.master, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), AudioManager.master_volume, 0.001);

    adjustVolume(.master, -1.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), AudioManager.master_volume, 0.001);

    AudioManager.setMasterVolume(1.0);
}
