const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const AudioManager = @import("../audio/AudioManager.zig");
const RoomManager = @import("../RoomManager.zig");
const OptionsMenu = @import("OptionsMenu.zig");
const SaveSystem = @import("../save/SaveSystem.zig");
const DevicePrompts = @import("../input/DevicePrompts.zig");
const HUD = @import("../HUD.zig");
const menu_button = @import("buttons/menu_button.zig");

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

    pub const ALL_ACTIONS = [_]PauseAction{
        .resume_game,
        .restart,
        .options,
        .exit,
    };

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

/// The index of the currently highlighted pause menu action.
pub var selected_index: usize = 0;

/// The index of the previously selected pause menu action for audio feedback tracking.
pub var previous_selected_index: usize = 0;

var just_opened: bool = false;

/// Opens the pause menu overlay, halting gameplay time.
pub fn show() void {
    if (is_showing) return;
    is_showing = true;
    current_view = .root;
    selected_index = 0;
    previous_selected_index = 0;
    just_opened = true;
    lm.time.pause();
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.5, 0.0);
}

/// Hides the pause menu overlay, resuming gameplay time.
pub fn hide() void {
    if (!is_showing) return;
    is_showing = false;
    current_view = .root;
    just_opened = false;
    lm.time.proceed();
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.5, 0.0);
}

/// Toggles visibility of the pause menu overlay.
pub fn toggle() void {
    if (is_showing) {
        hide();
    } else {
        show();
    }
}

/// Returns whether the pause menu overlay is actively shown.
pub fn isShowing() bool {
    return is_showing;
}

/// Renders the pause menu overlay and processes navigation inputs.
pub fn draw(allocator: ?std.mem.Allocator) void {
    if (!is_showing) return;

    const window_size = lm.window.size.get();
    const ui_scale = HUD.calculateUiScale(window_size);

    if (just_opened) {
        just_opened = false;
    } else if (current_view == .root) {
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
        .background_color = ui.color(6, 8, 12, 195),
    })({
        drawCurrentView(ui_scale, window_size, allocator);
    });

    if (selected_index != previous_selected_index) {
        AudioManager.playSfxPitched("audio/sfx/click.wav", 0.35, 0.1);
        previous_selected_index = selected_index;
    }
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
    selected_index = 2;
    previous_selected_index = 2;
    just_opened = true;
}

fn drawRootScreen(ui_scale: f32, window_size: lm.Vector2, allocator: ?std.mem.Allocator) void {
    const card_width_pixels = @min(window_size.x - 32, @round(380 * ui_scale));
    const card_padding_pixels = lm.tou16(@round(24 * ui_scale));
    const font_size = lm.tou16(@max(13, @round(15 * ui_scale)));
    const letter_spacing = lm.tou16(@max(1, @round(2 * ui_scale)));
    const status_text = resolveStatusText(allocator);

    ui.new(.{
        .id = .ID("pause-root-card"),
        .layout = .{
            .sizing = .{
                .w = .fixed(card_width_pixels),
            },
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = lm.tou16(@round(14 * ui_scale)),
            .padding = .all(card_padding_pixels),
        },
        .background_color = ui.color(16, 18, 25, 250),
        .corner_radius = .all(12 * ui_scale),
        .border = .{
            .color = ui.color(240, 200, 100, 180),
            .width = .outside(1),
        },
    })({
        drawHeader(ui_scale, status_text);
        drawPauseButtons(font_size, letter_spacing);
        drawFooter(ui_scale);
    });
}

fn resolveStatusText(allocator: ?std.mem.Allocator) []const u8 {
    if (RoomManager.isPlaytestMode()) {
        return "Map Editor Playtest";
    }
    if (RoomManager.isPracticeTutorialMode()) {
        return "Practice Tutorial";
    }

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
        .layout = .{
            .child_alignment = .{ .x = .center },
        },
    })({
        ui.text("GAME PAUSED", .{
            .color = ui.color(240, 200, 100, 255),
            .font_size = lm.tou16(@max(20, @round(24 * ui_scale))),
            .letter_spacing = 2,
            .alignment = .center,
        });
    });

    ui.new(.{
        .id = .ID("pause-status-wrap"),
        .layout = .{
            .child_alignment = .{ .x = .center },
            .padding = .axes(lm.tou16(@round(2 * ui_scale)), lm.tou16(@round(10 * ui_scale))),
        },
        .background_color = ui.color(24, 28, 38, 180),
        .corner_radius = .all(4 * ui_scale),
    })({
        ui.text(status_text, .{
            .color = ui.color(180, 190, 210, 240),
            .font_size = lm.tou16(@max(11, @round(12 * ui_scale))),
            .letter_spacing = 1,
            .alignment = .center,
        });
    });

    ui.new(.{
        .id = .ID("pause-root-spacer"),
        .layout = .{ .sizing = .{ .h = .fixed(@round(10 * ui_scale)), .w = .fixed(1) } },
    })({});
}

fn drawPauseButtons(font_size: u16, letter_spacing: u16) void {
    for (PauseAction.ALL_ACTIONS, 0..) |action, action_index| {
        menu_button.draw(
            action_index,
            action.caption(),
            &selected_index,
            activateRootAction,
            font_size,
            letter_spacing,
        );
    }
}

fn drawFooter(ui_scale: f32) void {
    ui.new(.{
        .id = .ID("pause-footer-spacer"),
        .layout = .{ .sizing = .{ .h = .fixed(@round(14 * ui_scale)), .w = .fixed(1) } },
    })({});

    ui.new(.{
        .id = .ID("pause-footer-container"),
        .layout = .{ .child_alignment = .{ .x = .center } },
    })({
        const footer_text = if (DevicePrompts.isGamepad())
            "Navigate: D-Pad / L-Stick  |  Select: A  |  Resume: B / Start"
        else
            "Navigate: WASD / Arrows  |  Select: Enter  |  Resume: Esc";

        ui.text(footer_text, .{
            .color = ui.color(140, 150, 175, 200),
            .font_size = lm.tou16(@max(9, @round(11 * ui_scale))),
            .letter_spacing = 1,
            .alignment = .center,
        });
    });
}

fn handleRootInput() void {
    DevicePrompts.update();
    var navigate_up = lm.keyboard.getKeyDown(.up) or lm.keyboard.getKeyDown(.w);
    var navigate_down = lm.keyboard.getKeyDown(.down) or lm.keyboard.getKeyDown(.s);
    var select_pressed = lm.keyboard.getKeyDown(.enter);
    var back_pressed = lm.keyboard.getKeyDown(.escape);

    if (lm.gamepad.isAvailable(0)) {
        navigate_up = navigate_up or lm.gamepad.getButtonDown(0, .left_face_up);
        navigate_down = navigate_down or lm.gamepad.getButtonDown(0, .left_face_down);
        select_pressed = select_pressed or lm.gamepad.getButtonDown(0, .right_face_down);
        back_pressed = back_pressed or lm.gamepad.getButtonDown(0, .right_face_right) or
            lm.gamepad.getButtonDown(0, .middle_right) or lm.gamepad.getButtonDown(0, .middle);

        const left_stick = lm.gamepad.getStickVector(0, .left, 0.25);
        if (left_stick.y < -0.5) navigate_up = true;
        if (left_stick.y > 0.5) navigate_down = true;
    }

    if (back_pressed) {
        hide();
        return;
    }

    const maximum_action_index: usize = PauseAction.ALL_ACTIONS.len - 1;
    if (navigate_up) {
        if (selected_index == 0) {
            selected_index = maximum_action_index;
        } else {
            selected_index -= 1;
        }
    }
    if (navigate_down) {
        if (selected_index >= maximum_action_index) {
            selected_index = 0;
        } else {
            selected_index += 1;
        }
    }
    if (select_pressed) {
        activateRootAction(selected_index);
    }
}

fn activateRootAction(index: usize) void {
    if (index >= PauseAction.ALL_ACTIONS.len) return;
    const action = PauseAction.ALL_ACTIONS[index];
    switch (action) {
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
        hide();
        AudioManager.playSfxPitched("audio/sfx/click.wav", 0.55, 0.0);
        lm.loadScene("main_menu") catch |load_error| {
            std.log.err("Failed to return to main_menu scene: {any}", .{load_error});
        };
        return;
    }

    RoomManager.saveCurrentRun();
    hide();
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.55, 0.0);
    lm.loadScene("main_menu") catch |load_error| {
        std.log.err("Failed to return to main_menu scene: {any}", .{load_error});
    };
}

test "PauseMenu show, hide, and toggle lifecycle" {
    is_showing = false;
    lm.time.proceed();

    show();
    try std.testing.expect(is_showing);
    try std.testing.expect(isShowing());
    try std.testing.expect(lm.time.paused());

    hide();
    try std.testing.expect(!is_showing);
    try std.testing.expect(!isShowing());
    try std.testing.expect(!lm.time.paused());

    toggle();
    try std.testing.expect(is_showing);
    try std.testing.expect(lm.time.paused());

    toggle();
    try std.testing.expect(!is_showing);
    try std.testing.expect(!lm.time.paused());
}

test "PauseMenu show and hide just_opened flag lifecycle" {
    is_showing = false;
    show();
    defer hide();
    try std.testing.expect(just_opened);

    hide();
    try std.testing.expect(!just_opened);
}

test "PauseMenu PauseAction captions" {
    try std.testing.expectEqualStrings("RESUME", PauseAction.resume_game.caption());
    try std.testing.expectEqualStrings("RESTART", PauseAction.restart.caption());
    try std.testing.expectEqualStrings("OPTIONS", PauseAction.options.caption());
    try std.testing.expectEqualStrings("MAIN MENU", PauseAction.exit.caption());
}
