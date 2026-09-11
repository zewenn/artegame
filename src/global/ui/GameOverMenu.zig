const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;
const clay = lm.deps.clay;

const AudioManager = @import("../audio/AudioManager.zig");
const RoomManager = @import("../RoomManager.zig");
const SaveSystem = @import("../save/SaveSystem.zig");
const InputHelper = @import("../input/InputHelper.zig");
const HUD = @import("../HUD.zig");

pub var is_showing: bool = false;
pub var run_stats: RoomManager.RunStats = .{};
pub var selected_index: usize = 0;
pub var prev_selected_index: usize = 0;
var just_opened: bool = false;

pub fn show(stats: RoomManager.RunStats) void {
    if (is_showing) return;
    is_showing = true;
    run_stats = stats;
    selected_index = 0;
    prev_selected_index = 0;
    just_opened = true;
    lm.time.pause();
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.4, -0.2);
    SaveSystem.recordRunEnd(stats);
}

pub fn hide() void {
    if (!is_showing) return;
    is_showing = false;
    just_opened = false;
    lm.time.proceed();
}

pub fn reset() void {
    is_showing = false;
    just_opened = false;
    selected_index = 0;
    prev_selected_index = 0;
}

pub fn isShowing() bool {
    return is_showing;
}

pub fn draw(alloc: ?std.mem.Allocator) void {
    if (!is_showing) return;

    const window_size = lm.window.size.get();
    const ui_scale = HUD.calculateUiScale(window_size);

    if (just_opened) {
        just_opened = false;
    } else {
        handleInput();
    }

    // Full-screen darkened backdrop overlay over frozen scene
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
        drawCard(ui_scale, window_size, alloc);
    });

    if (selected_index != prev_selected_index) {
        AudioManager.playSfxPitched("audio/sfx/click.wav", 0.35, 0.1);
        prev_selected_index = selected_index;
    }
}

fn drawCard(ui_scale: f32, window_size: lm.Vector2, alloc: ?std.mem.Allocator) void {
    const card_w = @min(window_size.x - 32, @round(420 * ui_scale));
    const card_padding = lm.tou16(@round(24 * ui_scale));
    const card_gap = lm.tou16(@round(16 * ui_scale));
    const title_font_size = lm.tou16(@max(20, @round(24 * ui_scale)));
    const subtitle_font_size = lm.tou16(@max(12, @round(13 * ui_scale)));
    const letter_spacing = lm.tou16(@max(1, @round(2 * ui_scale)));

    ui.new(.{
        .id = .ID("gameover-card"),
        .layout = .{
            .sizing = .{ .w = .fixed(card_w) },
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = card_gap,
            .padding = .all(card_padding),
        },
        .background_color = ui.color(16, 12, 16, 252),
        .corner_radius = .all(14 * ui_scale),
        .border = .{
            .color = ui.color(190, 45, 55, 230),
            .width = .outside(2),
        },
    })({
        // Header
        ui.new(.{
            .id = .ID("gameover-header"),
            .layout = .{
                .direction = .top_to_bottom,
                .child_alignment = .{ .x = .center },
                .child_gap = lm.tou16(@round(4 * ui_scale)),
            },
        })({
            ui.text("GAME OVER", .{
                .color = ui.color(240, 70, 75, 255),
                .letter_spacing = lm.tou16(@round(3 * ui_scale)),
                .font_size = title_font_size,
                .alignment = .center,
            });
            ui.text("You have fallen in battle", .{
                .color = ui.color(180, 165, 175, 255),
                .letter_spacing = letter_spacing,
                .font_size = subtitle_font_size,
                .alignment = .center,
            });
        });

        // Run Statistics Summary Box
        drawStatsBox(card_w - @as(f32, @floatFromInt(card_padding * 2)), ui_scale, alloc);

        // Action Buttons (Restart & Main Menu)
        drawActionButtons(card_w - @as(f32, @floatFromInt(card_padding * 2)), ui_scale);
    });
}

fn drawStatsBox(box_w: f32, ui_scale: f32, alloc: ?std.mem.Allocator) void {
    const box_padding = lm.tou16(@round(14 * ui_scale));
    const box_gap = lm.tou16(@round(8 * ui_scale));
    const row_h = @round(24 * ui_scale);

    const rooms_str = if (alloc) |a|
        std.fmt.allocPrint(a, "{d}", .{run_stats.rooms_cleared}) catch "0"
    else
        "0";

    const enemies_str = if (alloc) |a|
        std.fmt.allocPrint(a, "{d}", .{run_stats.enemies_defeated}) catch "0"
    else
        "0";

    const xp_str = if (alloc) |a|
        std.fmt.allocPrint(a, "{d} XP", .{run_stats.experience_collected}) catch "0 XP"
    else
        "0 XP";

    const high_score_str = if (alloc) |a|
        std.fmt.allocPrint(a, "{d} XP", .{SaveSystem.getScores().high_score}) catch "0 XP"
    else
        "0 XP";

    ui.new(.{
        .id = .ID("gameover-stats-box"),
        .layout = .{
            .sizing = .{ .w = .fixed(box_w) },
            .direction = .top_to_bottom,
            .padding = .all(box_padding),
            .child_gap = box_gap,
        },
        .background_color = ui.color(24, 18, 24, 200),
        .corner_radius = .all(8 * ui_scale),
        .border = .{
            .color = ui.color(60, 48, 60, 180),
            .width = .outside(1),
        },
    })({
        drawStatRow("ROOMS CLEARED", rooms_str, ui.color(240, 205, 110, 255), box_w, row_h, ui_scale);
        drawStatRow("ENEMIES DEFEATED", enemies_str, ui.color(235, 90, 95, 255), box_w, row_h, ui_scale);
        drawStatRow("EXPERIENCE", xp_str, ui.color(100, 200, 255, 255), box_w, row_h, ui_scale);
        drawStatRow("HIGH SCORE", high_score_str, ui.color(180, 230, 140, 255), box_w, row_h, ui_scale);
    });
}

fn drawStatRow(
    label: []const u8,
    value: []const u8,
    value_color: lm.deps.clay.Color,
    row_w: f32,
    row_h: f32,
    ui_scale: f32,
) void {
    _ = row_w;
    const font_size = lm.tou16(@max(12, @round(13 * ui_scale)));
    const letter_spacing = lm.tou16(@max(1, @round(1 * ui_scale)));

    ui.new(.{
        .id = .ID(label),
        .layout = .{
            .sizing = .{ .w = .grow, .h = .fixed(row_h) },
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
        },
    })({
        ui.text(label, .{
            .color = ui.color(160, 150, 160, 255),
            .letter_spacing = letter_spacing,
            .font_size = font_size,
        });

        ui.new(.{
            .id = .ID("stat-row-spacer"),
            .layout = .{ .sizing = .{ .w = .grow } },
        })({});

        ui.text(value, .{
            .color = value_color,
            .letter_spacing = letter_spacing,
            .font_size = font_size,
        });
    });
}

fn drawActionButtons(btn_max_w: f32, ui_scale: f32) void {
    const btn_w = @min(btn_max_w, @round(HUD.MENU_BUTTON_BASE_W * ui_scale));
    const btn_h = @round(HUD.MENU_BUTTON_BASE_H * ui_scale);
    const gap = lm.tou16(@round(10 * ui_scale));

    ui.new(.{
        .id = .ID("gameover-buttons-col"),
        .layout = .{
            .sizing = .{ .w = .fixed(btn_w) },
            .direction = .top_to_bottom,
            .child_gap = gap,
            .child_alignment = .{ .x = .center },
        },
    })({
        drawButton(0, "RESTART", true, btn_w, btn_h, ui_scale);
        drawButton(1, "MAIN MENU", false, btn_w, btn_h, ui_scale);

        ui.new(.{
            .id = .ID("gameover-footer-spacer"),
            .layout = .{ .sizing = .{ .h = .fixed(@round(14 * ui_scale)), .w = .fixed(1) } },
        })({});

        ui.new(.{
            .id = .ID("gameover-footer-container"),
            .layout = .{ .child_alignment = .{ .x = .center } },
        })({
            const footer_text = if (InputHelper.isGamepad())
                "Navigate: D-Pad / L-Stick  |  Select: A"
            else
                "Navigate: WASD / Arrows  |  Select: Enter / Space / Click";

            ui.text(footer_text, .{
                .color = ui.color(140, 150, 175, 200),
                .font_size = lm.tou16(@max(9, @round(11 * ui_scale))),
                .letter_spacing = 1,
                .alignment = .center,
            });
        });
    });
}

fn drawButton(
    index: usize,
    caption: []const u8,
    is_primary: bool,
    w: f32,
    h: f32,
    ui_scale: f32,
) void {
    const is_selected = (selected_index == index);
    const font_size = lm.tou16(@max(13, @round(15 * ui_scale)));
    const letter_spacing = lm.tou16(@max(1, @round(2 * ui_scale)));

    clay.UI()(.{
        .id = .IDI("gameover-btn-", @intCast(index)),
        .layout = .{
            .sizing = .{
                .w = .fixed(w),
                .h = .fixed(h),
            },
            .child_alignment = .{ .x = .center, .y = .center },
        },
        .image = ui.image(HUD.getMenuButtonSprite(clay.hovered() or is_selected), .init(w, h)) catch .{ .image_data = null },
    })({
        if (clay.hovered()) {
            selected_index = index;
            if (lm.mouse.getButtonDown(.left)) {
                activateAction(index);
            }
        }

        ui.text(caption, .{
            .color = if (clay.hovered() or is_selected)
                ui.color(255, 255, 255, 255)
            else if (is_primary)
                ui.color(240, 200, 205, 255)
            else
                ui.color(190, 180, 200, 255),
            .font_size = font_size,
            .letter_spacing = letter_spacing,
            .alignment = .center,
        });
    });
}

fn handleInput() void {
    InputHelper.update();
    var nav_up = lm.keyboard.getKeyDown(.up) or lm.keyboard.getKeyDown(.w);
    var nav_down = lm.keyboard.getKeyDown(.down) or lm.keyboard.getKeyDown(.s);
    var select_pressed = lm.keyboard.getKeyDown(.enter) or lm.keyboard.getKeyDown(.space);

    if (lm.gamepad.isAvailable(0)) {
        nav_up = nav_up or lm.gamepad.getButtonDown(0, .left_face_up);
        nav_down = nav_down or lm.gamepad.getButtonDown(0, .left_face_down);
        select_pressed = select_pressed or lm.gamepad.getButtonDown(0, .right_face_down);

        const stick = lm.gamepad.getStickVector(0, .left, 0.25);
        if (stick.y < -0.5) nav_up = true;
        if (stick.y > 0.5) nav_down = true;
    }

    const max_index: usize = 1; // 0: Restart, 1: Main Menu
    if (nav_up) {
        if (selected_index == 0) selected_index = max_index else selected_index -= 1;
    }
    if (nav_down) {
        if (selected_index >= max_index) selected_index = 0 else selected_index += 1;
    }
    if (select_pressed) {
        activateAction(selected_index);
    }
}

fn activateAction(index: usize) void {
    switch (index) {
        0 => {
            // RESTART
            SaveSystem.clearRun();
            hide();
            AudioManager.playSfxPitched("audio/sfx/coin.wav", 0.8, 0.05);
            lm.loadScene("demo_map") catch |err| {
                std.log.err("Failed to restart demo_map scene: {any}", .{err});
            };
        },
        1 => {
            // MAIN MENU
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

test "GameOverMenu navigation index wrapping" {
    is_showing = true;
    selected_index = 0;

    const max_index: usize = 1;

    // Navigate down to Main Menu
    selected_index = if (selected_index >= max_index) 0 else selected_index + 1;
    try std.testing.expectEqual(@as(usize, 1), selected_index);

    // Navigate down wraps to Restart
    selected_index = if (selected_index >= max_index) 0 else selected_index + 1;
    try std.testing.expectEqual(@as(usize, 0), selected_index);

    // Navigate up wraps to Main Menu
    selected_index = if (selected_index == 0) max_index else selected_index - 1;
    try std.testing.expectEqual(@as(usize, 1), selected_index);
}
