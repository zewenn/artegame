const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;
const clay = lm.deps.clay;

const AudioManager = @import("../audio/AudioManager.zig");
const DemoMap = @import("../DemoMap.zig");
const OptionsMenu = @import("OptionsMenu.zig");
const SaveSystem = @import("../save/SaveSystem.zig");

pub const View = enum {
    root,
    options,
};

pub var is_showing: bool = false;
pub var current_view: View = .root;

pub var selected_index: usize = 0;
pub var prev_selected_index: usize = 0;
var just_opened: bool = false;

pub fn show() void {
    if (is_showing) return;
    is_showing = true;
    current_view = .root;
    selected_index = 0;
    prev_selected_index = 0;
    just_opened = true;
    lm.time.pause();
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.5, 0.0);
}

pub fn hide() void {
    if (!is_showing) return;
    is_showing = false;
    current_view = .root;
    just_opened = false;
    lm.time.proceed();
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.5, 0.0);
}

pub fn toggle() void {
    if (is_showing) {
        hide();
    } else {
        show();
    }
}

pub fn isShowing() bool {
    return is_showing;
}

pub fn draw(alloc: ?std.mem.Allocator) void {
    if (!is_showing) return;

    const window_size = lm.window.size.get();
    const scale_x = window_size.x / 1280.0;
    const scale_y = window_size.y / 720.0;
    const ui_scale = @max(0.65, @min(2.5, @min(scale_x, scale_y)));

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
        switch (current_view) {
            .root => drawRootScreen(ui_scale, window_size, alloc),
            .options => {
                if (OptionsMenu.draw(ui_scale, window_size, alloc)) {
                    current_view = .root;
                    selected_index = 2;
                    prev_selected_index = 2;
                    just_opened = true;
                }
            },
        }
    });

    if (selected_index != prev_selected_index) {
        AudioManager.playSfxPitched("audio/sfx/click.wav", 0.35, 0.1);
        prev_selected_index = selected_index;
    }
}

// --------------------------------------------------------------------------------------------------
// Root Pause Screen
// --------------------------------------------------------------------------------------------------

fn drawRootScreen(ui_scale: f32, window_size: lm.Vector2, alloc: ?std.mem.Allocator) void {
    const card_w = @min(window_size.x - 32, @round(380 * ui_scale));
    const button_w = @round(280 * ui_scale);
    const button_h = @round(46 * ui_scale);
    const card_padding = lm.tou16(@round(24 * ui_scale));
    const font_size = lm.tou16(@max(13, @round(15 * ui_scale)));
    const letter_spacing = lm.tou16(@max(1, @round(2 * ui_scale)));

    const status_str = status_str: {
        const progress_opt = DemoMap.getWaveProgress();
        const state_opt = DemoMap.getState();
        if (progress_opt) |p| {
            if (state_opt) |s| {
                if (s == .combat) {
                    if (alloc) |a| {
                        break :status_str std.fmt.allocPrint(a, "Round {d} • Combat ({d}/{d} Defeated)", .{ p.round, p.killed, p.total }) catch "Combat Wave";
                    }
                } else {
                    if (alloc) |a| {
                        break :status_str std.fmt.allocPrint(a, "Round {d} • Replenish Phase", .{p.round}) catch "Replenish Phase";
                    }
                }
            }
        }
        break :status_str "Run in Progress";
    };

    ui.new(.{
        .id = .ID("pause-root-card"),
        .layout = .{
            .sizing = .{
                .w = .fixed(card_w),
            },
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = lm.tou16(@round(14 * ui_scale)),
            .padding = .all(card_padding),
        },
        .background_color = ui.color(16, 18, 25, 250),
        .corner_radius = .all(12 * ui_scale),
        .border = .{
            .color = ui.color(240, 200, 100, 180),
            .width = .outside(1),
        },
    })({
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
            ui.text(status_str, .{
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

        drawPauseButton(0, "RESUME", button_w, button_h, ui_scale, font_size, letter_spacing, true);
        drawPauseButton(1, "RESTART", button_w, button_h, ui_scale, font_size, letter_spacing, false);
        drawPauseButton(2, "OPTIONS", button_w, button_h, ui_scale, font_size, letter_spacing, false);
        drawPauseButton(3, "MAIN MENU", button_w, button_h, ui_scale, font_size, letter_spacing, false);
    });
}

fn drawPauseButton(
    index: usize,
    caption: []const u8,
    w: f32,
    h: f32,
    ui_scale: f32,
    font_size: u16,
    letter_spacing: u16,
    is_primary: bool,
) void {
    const is_selected = (selected_index == index);

    clay.UI()(.{
        .id = .IDI("pause-btn-", @intCast(index)),
        .layout = .{
            .sizing = .{
                .w = .fixed(w),
                .h = .fixed(h),
            },
            .child_alignment = .{ .x = .center, .y = .center },
        },
        .background_color = if (clay.hovered() or is_selected)
            if (is_primary) ui.color(52, 60, 80, 255) else ui.color(40, 46, 62, 255)
        else
            ui.color(22, 26, 35, 230),
        .corner_radius = .all(6 * ui_scale),
        .border = .{
            .color = if (clay.hovered() or is_selected)
                ui.color(240, 200, 100, 255)
            else if (is_primary)
                ui.color(200, 165, 80, 160)
            else
                ui.color(50, 56, 72, 160),
            .width = .outside(if (clay.hovered() or is_selected) 2 else 1),
        },
    })({
        if (clay.hovered()) {
            selected_index = index;
            if (lm.mouse.getButtonDown(.left)) {
                activateRootAction(index);
            }
        }

        ui.text(caption, .{
            .color = if (clay.hovered() or is_selected)
                ui.color(255, 255, 255, 255)
            else if (is_primary)
                ui.color(255, 235, 170, 255)
            else
                ui.color(200, 205, 220, 255),
            .font_size = font_size,
            .letter_spacing = letter_spacing,
            .alignment = .center,
        });
    });
}

// --------------------------------------------------------------------------------------------------
// Input & Actions
// --------------------------------------------------------------------------------------------------

fn handleRootInput() void {
    var nav_up = lm.keyboard.getKeyDown(.up) or lm.keyboard.getKeyDown(.w);
    var nav_down = lm.keyboard.getKeyDown(.down) or lm.keyboard.getKeyDown(.s);
    var select_pressed = lm.keyboard.getKeyDown(.enter) or lm.keyboard.getKeyDown(.space);
    var back_pressed = lm.keyboard.getKeyDown(.escape);

    if (lm.gamepad.isAvailable(0)) {
        nav_up = nav_up or lm.gamepad.getButtonDown(0, .left_face_up);
        nav_down = nav_down or lm.gamepad.getButtonDown(0, .left_face_down);
        select_pressed = select_pressed or lm.gamepad.getButtonDown(0, .right_face_down);
        back_pressed = back_pressed or lm.gamepad.getButtonDown(0, .right_face_right) or
            lm.gamepad.getButtonDown(0, .middle_right) or lm.gamepad.getButtonDown(0, .middle);

        const stick = lm.gamepad.getStickVector(0, .left, 0.25);
        if (stick.y < -0.5) nav_up = true;
        if (stick.y > 0.5) nav_down = true;
    }

    if (back_pressed) {
        hide();
        return;
    }

    const max_index: usize = 3;
    if (nav_up) {
        if (selected_index == 0) selected_index = max_index else selected_index -= 1;
    }
    if (nav_down) {
        if (selected_index >= max_index) selected_index = 0 else selected_index += 1;
    }
    if (select_pressed) {
        activateRootAction(selected_index);
    }
}

fn activateRootAction(index: usize) void {
    switch (index) {
        0 => {
            hide();
        },
        1 => {
            SaveSystem.clearRun();
            hide();
            AudioManager.playSfxPitched("audio/sfx/coin.wav", 0.8, 0.05);
            lm.loadScene("demo_map") catch |err| {
                std.log.err("Failed to restart demo_map scene: {any}", .{err});
            };
        },
        2 => {
            AudioManager.playSfxPitched("audio/sfx/click.wav", 0.55, 0.0);
            OptionsMenu.reset();
            current_view = .options;
        },
        3 => {
            DemoMap.saveCurrentRun();
            hide();
            AudioManager.playSfxPitched("audio/sfx/click.wav", 0.55, 0.0);
            lm.loadScene("main_menu") catch |err| {
                std.log.err("Failed to return to main_menu scene: {any}", .{err});
            };
        },
        else => {},
    }
}

// --------------------------------------------------------------------------------------------------
// Unit Tests
// --------------------------------------------------------------------------------------------------

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

test "PauseMenu root navigation index wrapping" {
    is_showing = true;
    current_view = .root;
    selected_index = 0;

    const max_index: usize = 3;

    selected_index = if (selected_index >= max_index) 0 else selected_index + 1;
    try std.testing.expectEqual(@as(usize, 1), selected_index);

    selected_index = if (selected_index >= max_index) 0 else selected_index + 1;
    try std.testing.expectEqual(@as(usize, 2), selected_index);

    selected_index = if (selected_index >= max_index) 0 else selected_index + 1;
    try std.testing.expectEqual(@as(usize, 3), selected_index);

    selected_index = if (selected_index >= max_index) 0 else selected_index + 1;
    try std.testing.expectEqual(@as(usize, 0), selected_index);

    selected_index = if (selected_index == 0) max_index else selected_index - 1;
    try std.testing.expectEqual(@as(usize, 3), selected_index);
}
