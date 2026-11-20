const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;
const clay = lm.deps.clay;

const AudioManager = @import("../audio/AudioManager.zig");
const SaveSystem = @import("../save/SaveSystem.zig");
const DevicePrompts = @import("../input/DevicePrompts.zig");
const ControlScheme = @import("../input/ControlScheme.zig");
const theme = @import("theme.zig");
const sprite_button = @import("buttons/sprite_button.zig");
const menu_navigation = @import("menu_navigation.zig");
const color_scheme = @import("color_scheme.zig");

/// Tabs available in the options menu.
pub const OptionsTab = enum {
    audio,
    display,
    controls,

    /// Display label rendered on the tab button.
    pub fn caption(self: OptionsTab) []const u8 {
        return switch (self) {
            .audio => "AUDIO",
            .display => "DISPLAY",
            .controls => "CONTROLS",
        };
    }
};

/// Volume channels adjustable in the audio tab.
pub const VolumeType = enum {
    master,
    music,
    sfx,

    /// Display label rendered on the audio slider row.
    pub fn label(self: VolumeType) []const u8 {
        return switch (self) {
            .master => "Master Volume",
            .music => "Music Volume",
            .sfx => "SFX Volume",
        };
    }

    /// Current normalized [0, 1] volume value from AudioManager.
    pub fn value(self: VolumeType) f32 {
        return switch (self) {
            .master => AudioManager.master_volume,
            .music => AudioManager.music_volume,
            .sfx => AudioManager.sfx_volume,
        };
    }
};

pub const TAB_COUNT: usize = @typeInfo(OptionsTab).@"enum".field_names.len;
pub const VOLUME_COUNT: usize = @typeInfo(VolumeType).@"enum".field_names.len;
pub const MUTE_ROW_INDEX: usize = VOLUME_COUNT;
pub const AUDIO_BACK_INDEX: usize = VOLUME_COUNT + 1;

/// Element ID index offset for tab bar buttons to avoid collision with row indices.
pub const TAB_BUTTON_INDEX_OFFSET: usize = 100;

/// Currently active options tab.
pub var options_tab: OptionsTab = .audio;

/// Shared navigation selection, stick latching, and open-guard state.
pub var navigation: menu_navigation.NavigationState = .{};

var back_button_clicked: bool = false;

const ToggleRowSpec = struct {
    row_id: []const u8,
    row_index: usize,
    label_id: []const u8,
    label_text: []const u8,
    label_width_pixels: f32,
    button_caption: []const u8,
    action: sprite_button.ActionFn,
    font_size_override: ?u16 = null,
    letter_spacing: u16 = 1,
};

const ControlRowSpec = struct {
    action_name: []const u8,
    prompt_action: ?DevicePrompts.PromptAction = null,
    static_keyboard_and_mouse: []const u8 = "",
    static_keyboard_only: []const u8 = "",
    static_gamepad: []const u8 = "",
};

const control_row_specs = [_]ControlRowSpec{
    .{
        .action_name = "Move",
        .static_keyboard_and_mouse = "W, A, S, D",
        .static_keyboard_only = "W, A, S, D",
        .static_gamepad = "Left Stick",
    },
    .{
        .action_name = "Aim / Look",
        .static_keyboard_and_mouse = "Mouse Cursor",
        .static_keyboard_only = "Arrow Keys (8-Way)",
        .static_gamepad = "Right Stick",
    },
    .{ .action_name = "Light Attack", .prompt_action = .attack_primary },
    .{ .action_name = "Heavy Attack", .prompt_action = .attack_secondary },
    .{ .action_name = "Dash", .prompt_action = .dash },
    .{ .action_name = "Cast Spell 1", .prompt_action = .spell_0 },
    .{ .action_name = "Cast Spell 2", .prompt_action = .spell_1 },
    .{ .action_name = "Switch Weapon", .prompt_action = .switch_weapon },
    .{ .action_name = "Interact", .prompt_action = .interact },
    .{ .action_name = "Pause / Menu", .prompt_action = .pause },
};

/// Resets the options menu state to default audio tab and zero selection.
pub fn reset() void {
    options_tab = .audio;
    navigation.reset(true);
}

/// Draws the options menu panel, processes user input, and returns true if the menu was requested to close.
pub fn draw(ui_scale: f32, window_size: lm.Vector2, allocator: ?std.mem.Allocator) bool {
    _ = allocator;
    back_button_clicked = false;

    const should_exit = if (navigation.consumeJustOpened()) false else handleInput();

    const panel_width_pixels = @min(window_size.x - 48, @round(170.0 * ui_scale));
    const panel_height_pixels = @min(window_size.y - 48, @round(130.0 * ui_scale));
    const panel_padding_pixels = lm.tou16(@round(5.0 * ui_scale));

    ui.new(.{
        .id = .ID("shared-options-panel"),
        .layout = .{
            .sizing = .{
                .w = .fixed(panel_width_pixels),
                .h = .fixed(panel_height_pixels),
            },
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = lm.tou16(@round(3.5 * ui_scale)),
            .padding = .all(panel_padding_pixels),
        },
        .background_color = color_scheme.panel_background,
        .corner_radius = .all(3.0 * ui_scale),
        .border = .{
            .color = color_scheme.panel_border,
            .width = .outside(1),
        },
    })({
        drawTitle(theme.scaledU16(5.0, 10, ui_scale));
        drawOptionsTabs(ui_scale);
        drawActiveTabContent(panel_width_pixels, ui_scale);
        drawBackButton(ui_scale);
    });

    navigation.syncSelectionAudio();

    if (should_exit or back_button_clicked) {
        AudioManager.playSfxPitched("audio/sfx/click.wav", 0.5, 0.0);
        return true;
    }

    return false;
}

fn drawActiveTabContent(panel_width_pixels: f32, ui_scale: f32) void {
    switch (options_tab) {
        .audio => drawAudioTab(panel_width_pixels, ui_scale),
        .display => drawDisplayTab(panel_width_pixels, ui_scale),
        .controls => drawControlsTab(panel_width_pixels, ui_scale),
    }
}

fn drawTitle(title_font_size: u16) void {
    ui.new(.{
        .id = .ID("opt-title-wrap"),
        .layout = .{ .child_alignment = .{ .x = .center } },
    })({
        ui.text("SETTINGS & OPTIONS", .{
            .color = color_scheme.accent_gold,
            .font_size = title_font_size,
            .letter_spacing = 2,
            .alignment = .center,
            .font_id = theme.boldFontId(),
        });
    });
}

fn drawOptionsTabs(ui_scale: f32) void {
    const tab_font_size = theme.scaledU16(3.25, 6, ui_scale);
    const previous_hint = DevicePrompts.getActionPrompt(.tab_prev).label;
    const next_hint = DevicePrompts.getActionPrompt(.tab_next).label;

    ui.new(.{
        .id = .ID("opt-tabs-bar"),
        .layout = .{
            .direction = .left_to_right,
            .child_gap = lm.tou16(@round(2.0 * ui_scale)),
            .child_alignment = .{ .y = .center },
        },
    })({
        drawTabHintBadge("opt-tab-hint-left", previous_hint, ui_scale);

        var active_tab_button_index: usize = TAB_BUTTON_INDEX_OFFSET + @intFromEnum(options_tab);
        inline for (std.enums.values(OptionsTab)) |tab| {
            sprite_button.draw(
                .utility,
                TAB_BUTTON_INDEX_OFFSET + @intFromEnum(tab),
                tab.caption(),
                &active_tab_button_index,
                activateTabButton,
                ui_scale,
                .{ .font_size_override = tab_font_size },
            );
        }

        drawTabHintBadge("opt-tab-hint-right", next_hint, ui_scale);
    });
}

fn activateTabButton(button_index: usize) void {
    if (button_index < TAB_BUTTON_INDEX_OFFSET) return;
    const tab_index = button_index - TAB_BUTTON_INDEX_OFFSET;
    const tabs = std.enums.values(OptionsTab);
    if (tab_index >= tabs.len) return;
    setTab(tabs[tab_index]);
}

fn drawTabHintBadge(identifier_string: []const u8, hint: []const u8, ui_scale: f32) void {
    const is_gamepad = DevicePrompts.isGamepad();
    clay.UI()(.{
        .id = .ID(identifier_string),
        .layout = .{
            .padding = .axes(
                theme.scaledU16(0.75, 1, ui_scale),
                theme.scaledU16(1.5, 2, ui_scale),
            ),
            .child_alignment = .{ .x = .center, .y = .center },
        },
        .background_color = if (is_gamepad) color_scheme.badge_gamepad_background else color_scheme.badge_keyboard_background,
        .corner_radius = .all(if (is_gamepad) 2.0 * ui_scale else 1.0 * ui_scale),
        .border = .{
            .color = if (is_gamepad) color_scheme.badge_gamepad_border else color_scheme.badge_keyboard_border,
            .width = .outside(1),
        },
    })({
        ui.text(hint, .{
            .color = color_scheme.badge_text,
            .font_size = theme.scaledU16(2.5, 5, ui_scale),
            .letter_spacing = 1,
            .font_id = theme.boldFontId(),
        });
    });
}

fn drawAudioTab(panel_width_pixels: f32, ui_scale: f32) void {
    const content_width_pixels = panel_width_pixels - @round(12.0 * ui_scale);
    const row_height_pixels = @round(10.5 * ui_scale);

    ui.new(.{
        .id = .ID("opt-audio-content"),
        .layout = .{
            .sizing = .{ .w = .fixed(content_width_pixels) },
            .direction = .top_to_bottom,
            .child_gap = lm.tou16(@round(2.0 * ui_scale)),
            .child_alignment = .{ .x = .center },
        },
    })({
        inline for (std.enums.values(VolumeType)) |volume_type| {
            drawVolumeRow(@intFromEnum(volume_type), volume_type, content_width_pixels, row_height_pixels, ui_scale);
        }

        drawToggleRow(.{
            .row_id = "opt-mute-row",
            .row_index = MUTE_ROW_INDEX,
            .label_id = "opt-mute-label-wrap",
            .label_text = "Mute All Audio",
            .label_width_pixels = @round(45.0 * ui_scale),
            .button_caption = if (AudioManager.mute) "MUTED" else "UNMUTED",
            .action = activateMuteButton,
            .font_size_override = theme.scaledU16(2.5, 5, ui_scale),
        }, content_width_pixels, row_height_pixels, ui_scale);
    });
}

fn drawVolumeRow(
    index: usize,
    volume_type: VolumeType,
    row_width_pixels: f32,
    row_height_pixels: f32,
    ui_scale: f32,
) void {
    const is_selected = (navigation.selected_index == index);
    const value = volume_type.value();
    const percentage = @as(u32, @intFromFloat(@round(value * 100.0)));
    const button_size_pixels = @round(theme.UTILITY_BUTTON_BASE_HEIGHT * ui_scale);
    const bar_total_width_pixels = @round(40.0 * ui_scale);
    const bar_height_pixels = @round(2.5 * ui_scale);
    const gap_width_pixels = @round(2.5 * ui_scale);
    const row_id = clay.ElementId.IDI("opt-vol-row-", @intCast(index));
    const is_highlighted = clay.pointerOver(row_id) or is_selected;

    clay.UI()(.{
        .id = row_id,
        .layout = .{
            .sizing = .{
                .w = .fixed(row_width_pixels),
                .h = .fixed(row_height_pixels),
            },
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .padding = .axes(
                lm.tou16(@round(1.0 * ui_scale)),
                lm.tou16(@round(4.0 * ui_scale)),
            ),
        },
        .background_color = if (is_highlighted)
            color_scheme.row_selected_warm_background
        else
            color_scheme.row_dark_background,
        .corner_radius = .all(1.5 * ui_scale),
        .border = .{
            .color = if (is_highlighted)
                color_scheme.accent_gold_border
            else
                color_scheme.row_idle_border,
            .width = .outside(if (is_highlighted) 2 else 1),
        },
    })({
        if (clay.hovered()) navigation.selected_index = index;

        drawVolumeLabel(index, volume_type.label(), is_selected, ui_scale);
        drawVolumeStepButton(index, volume_type, -0.05, "-", button_size_pixels, ui_scale, "opt-vol-dec-");
        drawVolumeGap("opt-vol-gap-1-", index, gap_width_pixels);
        drawVolumeProgressBar(index, value, is_selected, bar_total_width_pixels, bar_height_pixels, ui_scale);
        drawVolumeGap("opt-vol-gap-2-", index, gap_width_pixels);
        drawVolumeStepButton(index, volume_type, 0.05, "+", button_size_pixels, ui_scale, "opt-vol-inc-");
        drawVolumePercentage(index, percentage, is_selected, ui_scale);
    });
}

fn drawVolumeLabel(index: usize, label: []const u8, is_selected: bool, ui_scale: f32) void {
    ui.new(.{
        .id = .IDI("opt-vol-label-", @intCast(index)),
        .layout = .{ .sizing = .{ .w = .fixed(@round(45.0 * ui_scale)) } },
    })({
        ui.text(label, .{
            .color = if (is_selected) color_scheme.text_highlight_gold else color_scheme.text_primary,
            .font_size = theme.scaledU16(3.25, 6, ui_scale),
            .letter_spacing = 1,
            .font_id = theme.regularFontId(),
        });
    });
}

fn drawVolumeStepButton(
    index: usize,
    volume_type: VolumeType,
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
        .background_color = if (is_hovered) color_scheme.step_button_hovered_background else color_scheme.step_button_idle_background,
    })({
        if ((clay.hovered() or is_hovered) and lm.mouse.getButtonDown(.left)) {
            navigation.selected_index = index;
            adjustVolume(volume_type, delta);
        }
        ui.text(symbol, .{
            .color = color_scheme.text_bright,
            .font_size = theme.scaledU16(4.0, 8, ui_scale),
            .alignment = .center,
            .font_id = theme.boldFontId(),
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
        .background_color = color_scheme.progress_trough_background,
        .corner_radius = .all(1.0 * ui_scale),
    })({
        drawVolumeBarFill(index, bar_filled_width_pixels, is_selected, ui_scale);
    });
}

fn drawVolumeBarFill(index: usize, filled_width_pixels: f32, is_selected: bool, ui_scale: f32) void {
    if (filled_width_pixels <= 0.5) return;

    const fill_color = if (AudioManager.mute)
        color_scheme.progress_fill_muted
    else if (is_selected)
        color_scheme.accent_gold
    else
        color_scheme.progress_fill_active;

    ui.new(.{
        .id = .IDI("opt-vol-fill-", @intCast(index)),
        .layout = .{ .sizing = .{ .w = .fixed(filled_width_pixels), .h = .percent(1) } },
        .background_color = fill_color,
        .corner_radius = .all(1.0 * ui_scale),
    })({});
}

fn drawVolumePercentage(index: usize, percentage: u32, is_selected: bool, ui_scale: f32) void {
    ui.new(.{
        .id = .IDI("opt-vol-pct-", @intCast(index)),
        .layout = .{
            .sizing = .{ .w = .fixed(@round(14.0 * ui_scale)) },
            .child_alignment = .{ .x = .right, .y = .center },
        },
    })({
        ui.textFmt("{d}%", .{percentage}, .{
            .color = if (is_selected) color_scheme.accent_gold else color_scheme.text_secondary,
            .font_size = theme.scaledU16(3.25, 6, ui_scale),
            .alignment = .right,
            .font_id = theme.regularFontId(),
        });
    });
}

fn drawToggleRow(
    spec: ToggleRowSpec,
    row_width_pixels: f32,
    row_height_pixels: f32,
    ui_scale: f32,
) void {
    const is_selected = (navigation.selected_index == spec.row_index);
    const row_id = clay.ElementId.ID(spec.row_id);
    const is_highlighted = clay.pointerOver(row_id) or is_selected;

    clay.UI()(.{
        .id = row_id,
        .layout = .{
            .sizing = .{
                .w = .fixed(row_width_pixels),
                .h = .fixed(row_height_pixels),
            },
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .padding = .axes(
                lm.tou16(@round(1.0 * ui_scale)),
                lm.tou16(@round(4.0 * ui_scale)),
            ),
        },
        .background_color = if (is_highlighted)
            color_scheme.row_selected_background
        else
            color_scheme.row_idle_background,
        .corner_radius = .all(1.5 * ui_scale),
        .border = .{
            .color = if (is_highlighted)
                color_scheme.accent_gold_border
            else
                color_scheme.row_idle_border,
            .width = .outside(if (is_highlighted) 2 else 1),
        },
    })({
        if (clay.hovered()) {
            navigation.selected_index = spec.row_index;
        }

        ui.new(.{
            .id = .ID(spec.label_id),
            .layout = .{ .sizing = .{ .w = .fixed(spec.label_width_pixels) } },
        })({
            ui.text(spec.label_text, .{
                .color = if (is_selected) color_scheme.text_highlight_gold else color_scheme.text_primary,
                .font_size = theme.scaledU16(3.25, 6, ui_scale),
                .letter_spacing = 1,
                .font_id = theme.regularFontId(),
            });
        });

        sprite_button.draw(
            .utility,
            spec.row_index,
            spec.button_caption,
            &navigation.selected_index,
            spec.action,
            ui_scale,
            .{
                .font_size_override = spec.font_size_override,
                .letter_spacing = spec.letter_spacing,
            },
        );
    });
}

fn activateMuteButton(_: usize) void {
    toggleMuteAudio();
}

fn drawDisplayTab(panel_width_pixels: f32, ui_scale: f32) void {
    const content_width_pixels = panel_width_pixels - @round(12.0 * ui_scale);
    const row_height_pixels = @round(11.0 * ui_scale);

    ui.new(.{
        .id = .ID("opt-display-content"),
        .layout = .{
            .sizing = .{ .w = .fixed(content_width_pixels) },
            .direction = .top_to_bottom,
            .child_gap = lm.tou16(@round(2.5 * ui_scale)),
            .child_alignment = .{ .x = .center },
        },
    })({
        drawToggleRow(.{
            .row_id = "opt-fullscreen-row",
            .row_index = 0,
            .label_id = "opt-fullscreen-label-wrap",
            .label_text = "Display Mode",
            .label_width_pixels = @round(55.0 * ui_scale),
            .button_caption = if (lm.window.fullscreen.get()) "FULLSCREEN" else "WINDOWED",
            .action = activateFullscreenButton,
            .font_size_override = theme.scaledU16(2.5, 5, ui_scale),
        }, content_width_pixels, row_height_pixels, ui_scale);
    });
}

fn activateFullscreenButton(_: usize) void {
    toggleFullscreenMode();
}

fn drawControlsTab(panel_width_pixels: f32, ui_scale: f32) void {
    const content_width_pixels = panel_width_pixels - @round(12.0 * ui_scale);
    const row_font_size = theme.scaledU16(3.0, 6, ui_scale);
    const row_height_pixels = @round(9.0 * ui_scale);
    const is_gamepad = DevicePrompts.isGamepad();
    const active_scheme = ControlScheme.getControlScheme();

    ui.new(.{
        .id = .ID("opt-controls-content"),
        .layout = .{
            .sizing = .{ .w = .fixed(content_width_pixels) },
            .direction = .top_to_bottom,
            .child_gap = lm.tou16(@round(0.75 * ui_scale)),
        },
    })({
        drawToggleRow(.{
            .row_id = "opt-scheme-row",
            .row_index = 0,
            .label_id = "opt-scheme-label-wrap",
            .label_text = "Control Scheme",
            .label_width_pixels = @round(55.0 * ui_scale),
            .button_caption = active_scheme.displayName(),
            .action = activateControlSchemeButton,
            .font_size_override = theme.scaledU16(2.0, 4, ui_scale),
            .letter_spacing = 0,
        }, content_width_pixels, row_height_pixels, ui_scale);

        drawControlsTableHeader(content_width_pixels, row_font_size, ui_scale);

        inline for (control_row_specs, 0..) |row_spec, binding_index| {
            drawControlBindingRow(row_spec, binding_index, content_width_pixels, row_font_size, is_gamepad, ui_scale);
        }
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
            .sizing = .{ .w = .fixed(content_width_pixels), .h = .fixed(@round(5.5 * ui_scale)) },
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .padding = .axes(0, lm.tou16(@round(2.0 * ui_scale))),
        },
        .background_color = color_scheme.table_header_background,
        .corner_radius = .all(1.0 * ui_scale),
    })({
        drawTableCell(.ID("opt-table-header-1"), @round(40.0 * ui_scale), "ACTION", color_scheme.accent_gold, header_font_size, true);

        const keyboard_and_mouse_header = if (!is_gamepad)
            (if (is_keyboard_only) "KEYBOARD ONLY (ACTIVE)" else "KEYBOARD & MOUSE (ACTIVE)")
        else
            active_scheme.displayName();
        const keyboard_color = if (!is_gamepad) color_scheme.text_active_device else color_scheme.text_muted;
        drawTableCell(.ID("opt-table-header-2"), @round(47.5 * ui_scale), keyboard_and_mouse_header, keyboard_color, header_font_size, true);

        const gamepad_header = if (is_gamepad) "CONTROLLER (ACTIVE)" else "CONTROLLER";
        const gamepad_color = if (is_gamepad) color_scheme.text_active_device else color_scheme.text_muted;
        drawTableCell(.ID("opt-table-header-3"), null, gamepad_header, gamepad_color, header_font_size, true);
    });
}

fn resolveControlCellLabels(row_spec: ControlRowSpec) struct { keyboard_and_mouse: []const u8, gamepad: []const u8 } {
    if (row_spec.prompt_action) |prompt_action| {
        return .{
            .keyboard_and_mouse = DevicePrompts.getDeviceActionPrompt(.keyboard_mouse, prompt_action).label,
            .gamepad = DevicePrompts.getDeviceActionPrompt(.gamepad, prompt_action).label,
        };
    }

    const is_keyboard_only = (ControlScheme.getControlScheme() == .keyboard_only);
    return .{
        .keyboard_and_mouse = if (is_keyboard_only) row_spec.static_keyboard_only else row_spec.static_keyboard_and_mouse,
        .gamepad = row_spec.static_gamepad,
    };
}

fn drawControlBindingRow(
    row_spec: ControlRowSpec,
    binding_index: usize,
    content_width_pixels: f32,
    row_font_size: u16,
    is_gamepad: bool,
    ui_scale: f32,
) void {
    const is_even = (binding_index % 2 == 0);
    const background = if (is_even) color_scheme.table_row_even_background else color_scheme.table_row_odd_background;
    const labels = resolveControlCellLabels(row_spec);

    ui.new(.{
        .id = .IDI("opt-control-row-", @intCast(binding_index)),
        .layout = .{
            .sizing = .{ .w = .fixed(content_width_pixels), .h = .fixed(@round(5.0 * ui_scale)) },
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .padding = .axes(0, lm.tou16(@round(2.0 * ui_scale))),
        },
        .background_color = background,
    })({
        drawTableCell(.IDI("opt-cell-action-", @intCast(binding_index)), @round(40.0 * ui_scale), row_spec.action_name, color_scheme.text_primary, row_font_size, false);

        const keyboard_color = if (!is_gamepad) color_scheme.text_active_binding else color_scheme.text_dim;
        drawTableCell(.IDI("opt-cell-kbm-", @intCast(binding_index)), @round(47.5 * ui_scale), labels.keyboard_and_mouse, keyboard_color, row_font_size, false);

        const gamepad_color = if (is_gamepad) color_scheme.text_active_binding else color_scheme.text_dim;
        drawTableCell(.IDI("opt-cell-pad-", @intCast(binding_index)), null, labels.gamepad, gamepad_color, row_font_size, false);
    });
}

fn drawTableCell(
    element_id: clay.ElementId,
    width_pixels: ?f32,
    cell_text: []const u8,
    text_color: clay.Color,
    font_size: u16,
    is_bold: bool,
) void {
    const sizing_width: clay.SizingAxis = if (width_pixels) |fixed_width|
        .fixed(fixed_width)
    else
        .grow;

    ui.new(.{
        .id = element_id,
        .layout = .{ .sizing = .{ .w = sizing_width } },
    })({
        ui.text(cell_text, .{
            .color = text_color,
            .font_size = font_size,
            .letter_spacing = if (is_bold) 1 else 0,
            .font_id = theme.getFontId(is_bold),
        });
    });
}

fn drawBackButton(ui_scale: f32) void {
    sprite_button.draw(
        .utility,
        getBackIndex(),
        "BACK",
        &navigation.selected_index,
        activateBackButton,
        ui_scale,
        .{ .font_size_override = theme.scaledU16(2.75, 5, ui_scale) },
    );
}

fn activateBackButton(_: usize) void {
    back_button_clicked = true;
}

fn handleInput() bool {
    const input = navigation.readMenuInput();
    if (input.back_pressed) return true;
    if (handleTabInput(input)) return false;

    const back_index = getBackIndex();
    navigation.applyVerticalNavigation(input, back_index + 1);

    return switch (options_tab) {
        .audio => handleAudioTabAction(input, back_index),
        .display => handleSingleToggleTabAction(input, back_index, toggleFullscreenMode),
        .controls => handleSingleToggleTabAction(input, back_index, toggleControlScheme),
    };
}

fn handleTabInput(input: menu_navigation.MenuInput) bool {
    if (input.tab_previous) {
        cycleTab(-1);
        return true;
    }
    if (input.tab_next) {
        cycleTab(1);
        return true;
    }
    return false;
}

fn handleAudioTabAction(input: menu_navigation.MenuInput, back_index: usize) bool {
    if (input.navigate_left) adjustSelectedAudioVolume(-0.05);
    if (input.navigate_right) adjustSelectedAudioVolume(0.05);
    if (!input.select_pressed) return false;

    if (navigation.selected_index == MUTE_ROW_INDEX) {
        toggleMuteAudio();
        return false;
    }
    return navigation.selected_index == back_index;
}

fn adjustSelectedAudioVolume(delta: f32) void {
    inline for (std.enums.values(VolumeType)) |volume_type| {
        if (navigation.selected_index == @intFromEnum(volume_type)) {
            adjustVolume(volume_type, delta);
            return;
        }
    }
    if (navigation.selected_index == MUTE_ROW_INDEX) {
        toggleMuteAudio();
    }
}

fn handleSingleToggleTabAction(
    input: menu_navigation.MenuInput,
    back_index: usize,
    toggle_callback: *const fn () void,
) bool {
    const is_action_pressed = input.navigate_left or input.navigate_right or input.select_pressed;
    if (!is_action_pressed) return false;

    if (navigation.selected_index == 0) {
        toggle_callback();
        return false;
    }
    return navigation.selected_index == back_index;
}

/// Sets the current active tab and resets row selection.
pub fn setTab(tab: OptionsTab) void {
    if (options_tab == tab) return;

    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.45, 0.05);
    options_tab = tab;
    navigation.selected_index = 0;
    navigation.previous_selected_index = 0;
}

/// Cycles the current tab forward or backward by delta.
pub fn cycleTab(delta: i32) void {
    const current = @as(i32, @intCast(@intFromEnum(options_tab)));
    const next_value = @mod(current + delta, @as(i32, @intCast(TAB_COUNT)));
    const tabs = std.enums.values(OptionsTab);
    setTab(tabs[@intCast(next_value)]);
}

/// Returns the index of the back button for the currently active tab.
pub fn getBackIndex() usize {
    return switch (options_tab) {
        .audio => AUDIO_BACK_INDEX,
        .display, .controls => 1,
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
    const previous_disk_io = SaveSystem.disable_disk_io_for_tests;
    const previous_scheme = ControlScheme.getControlScheme();
    SaveSystem.disable_disk_io_for_tests = true;
    defer {
        ControlScheme.setControlScheme(previous_scheme);
        SaveSystem.deinit();
        SaveSystem.disable_disk_io_for_tests = previous_disk_io;
    }

    ControlScheme.setControlScheme(.keyboard_and_mouse);
    toggleControlScheme();
    try std.testing.expectEqual(ControlScheme.ControlScheme.keyboard_only, ControlScheme.getControlScheme());
    toggleControlScheme();
    try std.testing.expectEqual(ControlScheme.ControlScheme.keyboard_and_mouse, ControlScheme.getControlScheme());
}

test "OptionsMenu volume clamping bounds" {
    const previous_disk_io = SaveSystem.disable_disk_io_for_tests;
    const previous_master = AudioManager.master_volume;
    const previous_music = AudioManager.music_volume;
    const previous_sfx = AudioManager.sfx_volume;
    const previous_mute = AudioManager.mute;
    SaveSystem.disable_disk_io_for_tests = true;
    defer {
        AudioManager.setMasterVolume(previous_master);
        AudioManager.setMusicVolume(previous_music);
        AudioManager.setSfxVolume(previous_sfx);
        AudioManager.setMute(previous_mute);
        SaveSystem.deinit();
        SaveSystem.disable_disk_io_for_tests = previous_disk_io;
    }

    AudioManager.setMasterVolume(0.95);
    adjustVolume(.master, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), AudioManager.master_volume, 0.001);

    adjustVolume(.master, -1.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), AudioManager.master_volume, 0.001);
}

test "OptionsMenu control rows resolve live DevicePrompts labels" {
    DevicePrompts.reset();
    ControlScheme.reset();
    defer {
        DevicePrompts.reset();
        ControlScheme.reset();
    }

    ControlScheme.setControlSchemeForTest(.keyboard_and_mouse);
    const spell_zero_labels = resolveControlCellLabels(.{ .action_name = "Cast Spell 1", .prompt_action = .spell_0 });
    try std.testing.expectEqualStrings("Q", spell_zero_labels.keyboard_and_mouse);
    try std.testing.expectEqualStrings("X", spell_zero_labels.gamepad);

    const interact_labels = resolveControlCellLabels(.{ .action_name = "Interact", .prompt_action = .interact });
    try std.testing.expectEqualStrings("F", interact_labels.keyboard_and_mouse);
    try std.testing.expectEqualStrings("A", interact_labels.gamepad);
}
