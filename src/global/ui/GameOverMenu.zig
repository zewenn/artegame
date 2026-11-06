const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;
const clay = lm.deps.clay;

const AudioManager = @import("../audio/AudioManager.zig");
const RoomManager = @import("../RoomManager.zig");
const SaveSystem = @import("../save/SaveSystem.zig");
const DevicePrompts = @import("../input/DevicePrompts.zig");
const HUD = @import("../HUD.zig");

pub const RESTART_LOCKOUT_DURATION_SECONDS: f32 = 1.5;

pub var is_showing: bool = false;
pub var run_stats: RoomManager.RunStats = .{};
pub var selected_index: usize = 0;
pub var previous_selected_index: usize = 0;
pub var restart_lockout_timer_seconds: f32 = 0.0;
var just_opened: bool = false;
var last_mouse_position: lm.Vector2 = .init(-1, -1);
var mouse_moved: bool = false;

pub fn show(stats: RoomManager.RunStats) void {
    if (is_showing) return;
    is_showing = true;
    run_stats = stats;
    selected_index = 0;
    previous_selected_index = 0;
    just_opened = true;
    restart_lockout_timer_seconds = RESTART_LOCKOUT_DURATION_SECONDS;
    last_mouse_position = lm.mouse.getPosition();
    mouse_moved = false;
    lm.time.pause();
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.4, -0.2);
    if (!RoomManager.isPlaytestMode() and !RoomManager.isPracticeTutorialMode()) {
        SaveSystem.recordRunEnd(stats);
    }
}

pub fn hide() void {
    if (!is_showing) return;
    is_showing = false;
    just_opened = false;
    restart_lockout_timer_seconds = 0.0;
    lm.time.proceed();
}

pub fn reset() void {
    is_showing = false;
    just_opened = false;
    selected_index = 0;
    previous_selected_index = 0;
    restart_lockout_timer_seconds = 0.0;
    last_mouse_position = .init(-1, -1);
    mouse_moved = false;
}

pub fn update(delta_seconds: f32) void {
    if (restart_lockout_timer_seconds > 0.0) {
        restart_lockout_timer_seconds = @max(0.0, restart_lockout_timer_seconds - delta_seconds);
    }
}

pub fn canRestart() bool {
    return restart_lockout_timer_seconds <= 0.0;
}

pub fn isButtonActive(index: usize) bool {
    const is_disabled = (index == 0 and !canRestart());
    return !is_disabled and (selected_index == index);
}

pub fn isShowing() bool {
    return is_showing;
}

pub fn draw(allocator: ?std.mem.Allocator) void {
    if (!is_showing) return;

    const window_size = lm.window.size.get();
    const ui_scale = HUD.calculateUiScale(window_size);

    update(lm.time.deltaTime());

    if (just_opened) {
        just_opened = false;
    } else {
        handleInput();
    }

    ui.new(.{
        .id = .ID("gameover-backdrop"),
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
        .background_color = ui.color(8, 4, 6, 225),
    })({
        drawCard(ui_scale, window_size, allocator);
    });

    if (selected_index != previous_selected_index) {
        AudioManager.playSfxPitched("audio/sfx/click.wav", 0.35, 0.1);
        previous_selected_index = selected_index;
    }
}

fn drawCard(ui_scale: f32, window_size: lm.Vector2, allocator: ?std.mem.Allocator) void {
    const card_width_pixels = @min(window_size.x - 32, @round(105.0 * ui_scale));
    const card_padding_pixels = lm.tou16(@round(6.0 * ui_scale));
    const card_gap_pixels = lm.tou16(@round(4.0 * ui_scale));
    const title_font_size = lm.tou16(@max(12, @round(6.0 * ui_scale)));
    const subtitle_font_size = lm.tou16(@max(6, @round(3.25 * ui_scale)));
    const letter_spacing = lm.tou16(@max(1, @round(0.5 * ui_scale)));

    ui.new(.{
        .id = .ID("gameover-card"),
        .layout = .{
            .sizing = .{ .w = .fixed(card_width_pixels) },
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = card_gap_pixels,
            .padding = .all(card_padding_pixels),
        },
        .background_color = ui.color(16, 12, 16, 252),
        .corner_radius = .all(3.5 * ui_scale),
        .border = .{
            .color = ui.color(190, 45, 55, 230),
            .width = .outside(2),
        },
    })({
        ui.new(.{
            .id = .ID("gameover-header"),
            .layout = .{
                .direction = .top_to_bottom,
                .child_alignment = .{ .x = .center },
                .child_gap = lm.tou16(@round(1.0 * ui_scale)),
            },
        })({
            ui.text("GAME OVER", .{
                .color = ui.color(240, 70, 75, 255),
                .letter_spacing = lm.tou16(@max(1, @round(0.75 * ui_scale))),
                .font_size = title_font_size,
                .alignment = .center,
                .font_id = HUD.boldFontId(),
            });
            ui.text("You have fallen in battle", .{
                .color = ui.color(180, 165, 175, 255),
                .letter_spacing = letter_spacing,
                .font_size = subtitle_font_size,
                .alignment = .center,
                .font_id = HUD.regularFontId(),
            });
        });

        drawStatsBox(card_width_pixels - @as(f32, @floatFromInt(card_padding_pixels * 2)), ui_scale, allocator);
        drawActionButtons(card_width_pixels - @as(f32, @floatFromInt(card_padding_pixels * 2)), ui_scale);
    });
}

fn drawStatsBox(box_width_pixels: f32, ui_scale: f32, allocator: ?std.mem.Allocator) void {
    const box_padding_pixels = lm.tou16(@round(3.5 * ui_scale));
    const box_gap_pixels = lm.tou16(@round(2.0 * ui_scale));
    const row_height_pixels = @round(6.0 * ui_scale);

    const rooms_text = if (allocator) |active_allocator|
        std.fmt.allocPrint(active_allocator, "{d}", .{run_stats.rooms_cleared}) catch "0"
    else
        "0";

    const enemies_text = if (allocator) |active_allocator|
        std.fmt.allocPrint(active_allocator, "{d}", .{run_stats.enemies_defeated}) catch "0"
    else
        "0";

    const experience_text = if (allocator) |active_allocator|
        std.fmt.allocPrint(active_allocator, "{d} XP", .{run_stats.experience_collected}) catch "0 XP"
    else
        "0 XP";

    const high_score_text = if (allocator) |active_allocator|
        std.fmt.allocPrint(active_allocator, "{d} XP", .{SaveSystem.getScores().high_score}) catch "0 XP"
    else
        "0 XP";

    ui.new(.{
        .id = .ID("gameover-stats-box"),
        .layout = .{
            .sizing = .{ .w = .fixed(box_width_pixels) },
            .direction = .top_to_bottom,
            .padding = .all(box_padding_pixels),
            .child_gap = box_gap_pixels,
        },
        .background_color = ui.color(24, 18, 24, 200),
        .corner_radius = .all(2.0 * ui_scale),
        .border = .{
            .color = ui.color(60, 48, 60, 180),
            .width = .outside(1),
        },
    })({
        drawStatRow("ROOMS CLEARED", rooms_text, ui.color(240, 205, 110, 255), row_height_pixels, ui_scale);
        drawStatRow("ENEMIES DEFEATED", enemies_text, ui.color(235, 90, 95, 255), row_height_pixels, ui_scale);
        drawStatRow("EXPERIENCE", experience_text, ui.color(100, 200, 255, 255), row_height_pixels, ui_scale);
        drawStatRow("HIGH SCORE", high_score_text, ui.color(180, 230, 140, 255), row_height_pixels, ui_scale);
    });
}

fn drawStatRow(
    label: []const u8,
    value: []const u8,
    value_color: lm.deps.clay.Color,
    row_height_pixels: f32,
    ui_scale: f32,
) void {
    const font_size = lm.tou16(@max(6, @round(3.25 * ui_scale)));
    const letter_spacing = lm.tou16(@max(1, @round(0.25 * ui_scale)));

    ui.new(.{
        .id = .ID(label),
        .layout = .{
            .sizing = .{ .w = .grow, .h = .fixed(row_height_pixels) },
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
        },
    })({
        ui.text(label, .{
            .color = ui.color(160, 150, 160, 255),
            .letter_spacing = letter_spacing,
            .font_size = font_size,
            .font_id = HUD.regularFontId(),
        });

        ui.new(.{
            .id = .ID("stat-row-spacer"),
            .layout = .{ .sizing = .{ .w = .grow } },
        })({});

        ui.text(value, .{
            .color = value_color,
            .letter_spacing = letter_spacing,
            .font_size = font_size,
            .font_id = HUD.boldFontId(),
        });
    });
}

fn updateHoverSelection() void {
    const current_mouse_position = lm.mouse.getPosition();
    mouse_moved = (current_mouse_position.x != last_mouse_position.x or current_mouse_position.y != last_mouse_position.y);
    last_mouse_position = current_mouse_position;

    if (!mouse_moved) return;

    const total_buttons: usize = 2;
    for (0..total_buttons) |button_index| {
        const button_element_id = clay.ElementId.IDI("gameover-btn-", @as(u32, @intCast(button_index)));
        if (clay.pointerOver(button_element_id)) {
            selected_index = button_index;
            return;
        }
    }
}

fn drawActionButtons(button_max_width_pixels: f32, ui_scale: f32) void {
    updateHoverSelection();

    const button_width_pixels = @min(button_max_width_pixels, @round(HUD.MENU_BUTTON_BASE_WIDTH * ui_scale));
    const button_height_pixels = @round(HUD.MENU_BUTTON_BASE_HEIGHT * ui_scale);
    const gap_pixels = lm.tou16(@round(2.5 * ui_scale));

    ui.new(.{
        .id = .ID("gameover-buttons-col"),
        .layout = .{
            .sizing = .{ .w = .fixed(button_width_pixels) },
            .direction = .top_to_bottom,
            .child_gap = gap_pixels,
            .child_alignment = .{ .x = .center },
        },
    })({
        drawButton(0, "RESTART", true, button_width_pixels, button_height_pixels, ui_scale);
        drawButton(1, if (RoomManager.isPlaytestMode()) "MAP EDITOR" else "MAIN MENU", false, button_width_pixels, button_height_pixels, ui_scale);

        ui.new(.{
            .id = .ID("gameover-footer-spacer"),
            .layout = .{ .sizing = .{ .h = .fixed(@round(3.5 * ui_scale)), .w = .fixed(1) } },
        })({});

        ui.new(.{
            .id = .ID("gameover-footer-container"),
            .layout = .{ .child_alignment = .{ .x = .center } },
        })({
            const footer_text = if (DevicePrompts.isGamepad())
                "Navigate: D-Pad / L-Stick  |  Select: A"
            else
                "Navigate: WASD / Arrows  |  Select: Enter / Click";

            ui.text(footer_text, .{
                .color = ui.color(140, 150, 175, 200),
                .font_size = lm.tou16(@max(5, @round(2.75 * ui_scale))),
                .letter_spacing = 1,
                .alignment = .center,
                .font_id = HUD.regularFontId(),
            });
        });
    });
}

fn handleButtonInteraction(index: usize, is_disabled: bool) void {
    if (!clay.hovered()) return;
    if (mouse_moved) {
        selected_index = index;
    }
    if (lm.mouse.getButtonDown(.left) and !is_disabled) {
        selected_index = index;
        activateAction(index);
    }
}

fn drawButton(
    index: usize,
    caption: []const u8,
    is_primary: bool,
    button_width_pixels: f32,
    button_height_pixels: f32,
    ui_scale: f32,
) void {
    const is_disabled = (index == 0 and !canRestart());
    const is_button_active = isButtonActive(index);
    const font_size = lm.tou16(@max(7, @round(3.75 * ui_scale)));
    const letter_spacing = lm.tou16(@max(1, @round(0.5 * ui_scale)));

    clay.UI()(.{
        .id = .IDI("gameover-btn-", @intCast(index)),
        .layout = .{
            .sizing = .{
                .w = .fixed(button_width_pixels),
                .h = .fixed(button_height_pixels),
            },
            .child_alignment = .{ .x = .center, .y = .center },
        },
        .image = ui.image(HUD.getMenuButtonSprite(is_button_active), .init(button_width_pixels, button_height_pixels)) catch .{ .image_data = null },
    })({
        handleButtonInteraction(index, is_disabled);

        const text_color = if (is_disabled)
            ui.color(120, 105, 115, 200)
        else if (is_button_active)
            ui.color(255, 255, 255, 255)
        else if (is_primary)
            ui.color(240, 200, 205, 255)
        else
            ui.color(190, 180, 200, 255);

        ui.text(caption, .{
            .color = text_color,
            .font_size = font_size,
            .letter_spacing = letter_spacing,
            .alignment = .center,
            .font_id = HUD.getFontId(is_button_active),
        });
    });
}

fn handleInput() void {
    DevicePrompts.update();
    var navigate_up = lm.keyboard.getKeyDown(.up) or lm.keyboard.getKeyDown(.w);
    var navigate_down = lm.keyboard.getKeyDown(.down) or lm.keyboard.getKeyDown(.s);
    var select_pressed = lm.keyboard.getKeyDown(.enter);

    if (lm.gamepad.isAvailable(0)) {
        navigate_up = navigate_up or lm.gamepad.getButtonDown(0, .left_face_up);
        navigate_down = navigate_down or lm.gamepad.getButtonDown(0, .left_face_down);
        select_pressed = select_pressed or lm.gamepad.getButtonDown(0, .right_face_down);

        const stick = lm.gamepad.getStickVector(0, .left, 0.25);
        if (stick.y < -0.5) navigate_up = true;
        if (stick.y > 0.5) navigate_down = true;
    }

    const maximum_index: usize = 1;
    if (navigate_up) {
        if (selected_index == 0) selected_index = maximum_index else selected_index -= 1;
    }
    if (navigate_down) {
        if (selected_index >= maximum_index) selected_index = 0 else selected_index += 1;
    }
    if (select_pressed) {
        if (selected_index != 0 or canRestart()) {
            activateAction(selected_index);
        }
    }
}

fn activateAction(index: usize) void {
    switch (index) {
        0 => restartGame(),
        1 => returnToMenuOrEditor(),
        else => {},
    }
}

fn restartGame() void {
    if (!canRestart()) return;
    if (!RoomManager.isPlaytestMode() and !RoomManager.isPracticeTutorialMode()) {
        SaveSystem.clearRun();
    }
    hide();
    AudioManager.playSfxPitched("audio/sfx/coin.wav", 0.8, 0.05);
    lm.loadScene("demo_map") catch |load_error| {
        std.log.err("Failed to restart demo_map scene: {any}", .{load_error});
    };
}

fn returnToMenuOrEditor() void {
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

    hide();
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.55, 0.0);
    lm.loadScene("main_menu") catch |load_error| {
        std.log.err("Failed to return to main_menu scene: {any}", .{load_error});
    };
}

test "GameOverMenu show and hide lifecycle" {
    is_showing = false;
    lm.time.proceed();

    show(.{
        .rooms_cleared = 2,
        .current_room = 3,
        .enemies_defeated = 15,
        .experience_collected = 120,
    });

    try std.testing.expect(is_showing);
    try std.testing.expect(isShowing());
    try std.testing.expect(lm.time.paused());
    try std.testing.expect(just_opened);
    try std.testing.expectEqual(@as(u32, 2), run_stats.rooms_cleared);
    try std.testing.expectEqual(@as(u32, 15), run_stats.enemies_defeated);
    try std.testing.expectEqual(@as(usize, 120), run_stats.experience_collected);

    hide();
    try std.testing.expect(!is_showing);
    try std.testing.expect(!isShowing());
    try std.testing.expect(!lm.time.paused());
    try std.testing.expect(!just_opened);
}

test "GameOverMenu restart lockout timeout and rejection" {
    reset();
    lm.time.proceed();

    show(.{});
    try std.testing.expect(is_showing);
    try std.testing.expect(!canRestart());
    try std.testing.expectEqual(@as(f32, RESTART_LOCKOUT_DURATION_SECONDS), restart_lockout_timer_seconds);

    activateAction(0);
    try std.testing.expect(is_showing);

    update(1.0);
    try std.testing.expect(!canRestart());
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), restart_lockout_timer_seconds, 0.001);

    activateAction(0);
    try std.testing.expect(is_showing);

    update(0.5);
    try std.testing.expect(canRestart());
    try std.testing.expectEqual(@as(f32, 0.0), restart_lockout_timer_seconds);

    hide();
    try std.testing.expect(!is_showing);
    try std.testing.expect(canRestart());
}

test "GameOverMenu button active state and mutual exclusion" {
    reset();
    restart_lockout_timer_seconds = 0.0;

    selected_index = 0;
    try std.testing.expect(isButtonActive(0));
    try std.testing.expect(!isButtonActive(1));

    selected_index = 1;
    try std.testing.expect(!isButtonActive(0));
    try std.testing.expect(isButtonActive(1));

    restart_lockout_timer_seconds = 1.0;
    selected_index = 0;
    try std.testing.expect(!isButtonActive(0));
    try std.testing.expect(!isButtonActive(1));

    selected_index = 1;
    try std.testing.expect(!isButtonActive(0));
    try std.testing.expect(isButtonActive(1));
}
