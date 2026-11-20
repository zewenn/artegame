const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const AudioManager = @import("../audio/AudioManager.zig");
const RoomManager = @import("../RoomManager.zig");
const OptionsMenu = @import("OptionsMenu.zig");
const SaveSystem = @import("../save/SaveSystem.zig");
const theme = @import("theme.zig");
const sprite_button = @import("buttons/sprite_button.zig");
const menu_navigation = @import("menu_navigation.zig");
const color_scheme = @import("color_scheme.zig");

/// Visual screens displayed within the pause menu overlay.
pub const View = enum {
    root,
    options,
};

/// Actions available on the root pause menu screen.
pub const PauseAction = enum(usize) {
    resume_game = 0,
    restart = 1,
    options = 2,
    exit = 3,

    /// Text caption displayed on the pause button.
    pub fn caption(self: PauseAction) []const u8 {
        return switch (self) {
            .resume_game => "RESUME",
            .restart => "RESTART",
            .options => "OPTIONS",
            .exit => if (RoomManager.isPlaytestMode()) "MAP EDITOR" else "MAIN MENU",
        };
    }
};

/// Indicates whether the pause menu overlay is actively visible.
pub var is_showing: bool = false;

/// The currently active view within the pause menu.
pub var current_view: View = .root;

/// Shared navigation selection, stick latching, and open-guard state.
pub var navigation: menu_navigation.NavigationState = .{};

/// Opens the pause menu overlay, halting gameplay time.
pub fn show() void {
    if (is_showing) return;
    is_showing = true;
    current_view = .root;
    navigation.reset(true);
    lm.time.pause();
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.5, 0.0);
}

/// Hides the pause menu overlay, resuming gameplay time.
pub fn hide() void {
    if (!is_showing) return;
    is_showing = false;
    current_view = .root;
    navigation.just_opened = false;
    lm.time.proceed();
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.5, 0.0);
}

/// Returns whether the pause menu overlay is actively shown.
pub fn isShowing() bool {
    return is_showing;
}

/// Renders the pause menu overlay and processes navigation inputs.
pub fn draw(allocator: ?std.mem.Allocator) void {
    if (!is_showing) return;

    const window_size = lm.window.size.get();
    const ui_scale = theme.calculateUiScale(window_size);

    if (!navigation.consumeJustOpened() and current_view == .root) {
        handleRootInput();
    }

    ui.new(.{
        .id = .ID("pause-backdrop"),
        .floating = .{
            .attach_to = .to_root,
            .attach_points = .{
                .element = .left_top,
                .parent = .left_top,
            },
        },
        .layout = .{
            .sizing = .{
                .w = .fixed(window_size.x),
                .h = .fixed(window_size.y),
            },
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center, .y = .center },
        },
        .background_color = color_scheme.backdrop_overlay,
    })({
        drawCurrentView(ui_scale, window_size, allocator);
    });

    navigation.syncSelectionAudio();
}

fn drawCurrentView(ui_scale: f32, window_size: lm.Vector2, allocator: ?std.mem.Allocator) void {
    switch (current_view) {
        .root => drawRootScreen(ui_scale, window_size, allocator),
        .options => drawOptionsView(ui_scale, window_size, allocator),
    }
}

fn drawOptionsView(ui_scale: f32, window_size: lm.Vector2, allocator: ?std.mem.Allocator) void {
    if (!OptionsMenu.draw(ui_scale, window_size, allocator)) return;
    current_view = .root;
    navigation.selected_index = @intFromEnum(PauseAction.options);
    navigation.previous_selected_index = navigation.selected_index;
    navigation.just_opened = true;
}

fn drawRootScreen(ui_scale: f32, window_size: lm.Vector2, allocator: ?std.mem.Allocator) void {
    const card_width_pixels = @min(window_size.x - 32, @round(95.0 * ui_scale));
    const card_padding_pixels = lm.tou16(@round(6.0 * ui_scale));
    const font_size = theme.scaledU16(3.75, 7, ui_scale);
    const letter_spacing = theme.scaledU16(0.5, 1, ui_scale);
    const status_text = resolveStatusText(allocator);

    ui.new(.{
        .id = .ID("pause-root-card"),
        .layout = .{
            .sizing = .{ .w = .fixed(card_width_pixels) },
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = lm.tou16(@round(3.5 * ui_scale)),
            .padding = .all(card_padding_pixels),
        },
        .background_color = color_scheme.panel_background,
        .corner_radius = .all(3.0 * ui_scale),
        .border = .{
            .color = color_scheme.accent_gold_border,
            .width = .outside(1),
        },
    })({
        drawHeader(ui_scale, status_text);
        drawPauseButtons(ui_scale, font_size, letter_spacing);
        drawFooter(ui_scale);
    });
}

fn resolveStatusText(allocator: ?std.mem.Allocator) []const u8 {
    if (RoomManager.isPlaytestMode()) return "Map Editor Playtest";
    if (RoomManager.isPracticeTutorialMode()) return "Practice Tutorial";

    const wave_progress = RoomManager.getWaveProgress() orelse return "Run in Progress";
    const room_state = RoomManager.getState() orelse return "Run in Progress";
    const active_allocator = allocator orelse return "Run in Progress";

    if (room_state == .combat) {
        return std.fmt.allocPrint(
            active_allocator,
            "Room {d} • Combat ({d}/{d} Defeated)",
            .{ wave_progress.round, wave_progress.killed, wave_progress.total },
        ) catch "Combat Wave";
    }

    return std.fmt.allocPrint(
        active_allocator,
        "Room {d} • Replenish Phase",
        .{wave_progress.round},
    ) catch "Replenish Phase";
}

fn drawHeader(ui_scale: f32, status_text: []const u8) void {
    ui.new(.{
        .id = .ID("pause-title-wrap"),
        .layout = .{ .child_alignment = .{ .x = .center } },
    })({
        ui.text("GAME PAUSED", .{
            .color = color_scheme.accent_gold,
            .font_size = theme.scaledU16(6.0, 12, ui_scale),
            .letter_spacing = 2,
            .alignment = .center,
            .font_id = theme.boldFontId(),
        });
    });

    ui.new(.{
        .id = .ID("pause-status-wrap"),
        .layout = .{
            .child_alignment = .{ .x = .center },
            .padding = .axes(lm.tou16(@round(0.5 * ui_scale)), lm.tou16(@round(2.5 * ui_scale))),
        },
        .background_color = color_scheme.status_pill_background,
        .corner_radius = .all(1.0 * ui_scale),
    })({
        ui.text(status_text, .{
            .color = color_scheme.text_secondary,
            .font_size = theme.scaledU16(3.0, 6, ui_scale),
            .letter_spacing = 1,
            .alignment = .center,
            .font_id = theme.regularFontId(),
        });
    });

    ui.new(.{
        .id = .ID("pause-root-spacer"),
        .layout = .{ .sizing = .{ .h = .fixed(@round(2.5 * ui_scale)), .w = .fixed(1) } },
    })({});
}

fn drawPauseButtons(ui_scale: f32, font_size: u16, letter_spacing: u16) void {
    inline for (std.enums.values(PauseAction)) |action| {
        sprite_button.draw(
            .menu,
            @intFromEnum(action),
            action.caption(),
            &navigation.selected_index,
            activateRootAction,
            ui_scale,
            .{
                .font_size_override = font_size,
                .letter_spacing = letter_spacing,
            },
        );
    }
}

fn drawFooter(ui_scale: f32) void {
    ui.new(.{
        .id = .ID("pause-footer-spacer"),
        .layout = .{ .sizing = .{ .h = .fixed(@round(3.5 * ui_scale)), .w = .fixed(1) } },
    })({});

    menu_navigation.drawFooterHint(
        "pause-footer-container",
        "Navigate: D-Pad / L-Stick  |  Select: A  |  Resume: B / Start",
        "Navigate: WASD / Arrows  |  Select: Enter  |  Resume: Esc",
        ui_scale,
    );
}

fn handleRootInput() void {
    const input = navigation.readMenuInput();
    if (input.back_pressed) {
        hide();
        return;
    }

    const actions = std.enums.values(PauseAction);
    navigation.applyVerticalNavigation(input, actions.len);
    if (input.select_pressed) {
        activateRootAction(navigation.selected_index);
    }
}

fn activateRootAction(index: usize) void {
    const actions = std.enums.values(PauseAction);
    if (index >= actions.len) return;
    switch (actions[index]) {
        .resume_game => hide(),
        .restart => restartGame(),
        .options => openOptionsMenu(),
        .exit => exitToMenuOrEditor(),
    }
}

fn restartGame() void {
    if (!RoomManager.isPlaytestMode() and !RoomManager.isPracticeTutorialMode()) {
        SaveSystem.clearRun();
    }
    hide();
    AudioManager.playSfxPitched("audio/sfx/coin.wav", 0.8, 0.05);
    lm.loadScene("demo_map") catch |load_error| {
        std.log.err("Failed to restart demo_map scene: {any}", .{load_error});
    };
}

fn openOptionsMenu() void {
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.55, 0.0);
    OptionsMenu.reset();
    current_view = .options;
}

fn exitToMenuOrEditor() void {
    if (RoomManager.isPlaytestMode()) {
        RoomManager.endPlaytest();
        hide();
        AudioManager.playSfxPitched("audio/sfx/click.wav", 0.55, 0.0);
        lm.loadScene("map_editor") catch |load_error| {
            std.log.err("Failed to return to map_editor scene: {any}", .{load_error});
        };
        return;
    }

    if (RoomManager.isPracticeTutorialMode()) {
        RoomManager.endPracticeTutorial();
    } else {
        RoomManager.saveCurrentRun();
    }

    hide();
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.55, 0.0);
    lm.loadScene("main_menu") catch |load_error| {
        std.log.err("Failed to return to main_menu scene: {any}", .{load_error});
    };
}

test "PauseMenu show and hide lifecycle" {
    is_showing = false;
    lm.time.proceed();
    defer {
        hide();
        lm.time.proceed();
    }

    show();
    try std.testing.expect(is_showing);
    try std.testing.expect(isShowing());
    try std.testing.expect(lm.time.paused());

    hide();
    try std.testing.expect(!is_showing);
    try std.testing.expect(!isShowing());
    try std.testing.expect(!lm.time.paused());
}
