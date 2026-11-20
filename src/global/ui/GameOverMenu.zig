const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;
const clay = lm.deps.clay;

const AudioManager = @import("../audio/AudioManager.zig");
const RoomManager = @import("../RoomManager.zig");
const SaveSystem = @import("../save/SaveSystem.zig");
const theme = @import("theme.zig");
const sprite_button = @import("buttons/sprite_button.zig");
const menu_navigation = @import("menu_navigation.zig");
const color_scheme = @import("color_scheme.zig");

pub const RESTART_LOCKOUT_DURATION_SECONDS: f32 = 1.5;

/// Actions available on the game over screen.
pub const GameOverAction = enum(usize) {
    restart = 0,
    exit = 1,

    /// Text caption displayed on the game over action button.
    pub fn caption(self: GameOverAction) []const u8 {
        return switch (self) {
            .restart => "RESTART",
            .exit => if (RoomManager.isPlaytestMode()) "MAP EDITOR" else "MAIN MENU",
        };
    }

    /// Idle label color differentiating primary restart from secondary exit.
    pub fn idleTextColor(self: GameOverAction) clay.Color {
        return switch (self) {
            .restart => color_scheme.button_text_primary_idle,
            .exit => color_scheme.button_text_secondary_idle,
        };
    }
};

const StatField = enum {
    rooms_cleared,
    enemies_defeated,
    experience_collected,
    high_score,
};

const StatRowSpec = struct {
    label: []const u8,
    field: StatField,
    format_string: []const u8,
    value_color: clay.Color,
};

const stat_row_specs = [_]StatRowSpec{
    .{
        .label = "ROOMS CLEARED",
        .field = .rooms_cleared,
        .format_string = "{d}",
        .value_color = color_scheme.accent_gold,
    },
    .{
        .label = "ENEMIES DEFEATED",
        .field = .enemies_defeated,
        .format_string = "{d}",
        .value_color = color_scheme.accent_crimson_stat,
    },
    .{
        .label = "EXPERIENCE",
        .field = .experience_collected,
        .format_string = "{d} XP",
        .value_color = color_scheme.accent_cyan,
    },
    .{
        .label = "HIGH SCORE",
        .field = .high_score,
        .format_string = "{d} XP",
        .value_color = color_scheme.accent_green,
    },
};

pub var is_showing: bool = false;
pub var run_stats: RoomManager.RunStats = .{};
pub var navigation: menu_navigation.NavigationState = .{};
pub var restart_lockout_timer_seconds: f32 = 0.0;
var last_mouse_position: lm.Vector2 = .init(-1, -1);
var mouse_moved: bool = false;

/// Displays the game over screen with the provided run statistics and records the run end.
pub fn show(stats: RoomManager.RunStats) void {
    if (is_showing) return;
    is_showing = true;
    run_stats = stats;
    navigation.reset(true);
    restart_lockout_timer_seconds = RESTART_LOCKOUT_DURATION_SECONDS;
    last_mouse_position = lm.mouse.getPosition();
    mouse_moved = false;
    lm.time.pause();
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.4, -0.2);
    if (!RoomManager.isPlaytestMode() and !RoomManager.isPracticeTutorialMode()) {
        SaveSystem.recordRunEnd(stats);
    }
}

/// Hides the game over screen and resumes game time.
pub fn hide() void {
    if (!is_showing) return;
    is_showing = false;
    navigation.just_opened = false;
    restart_lockout_timer_seconds = 0.0;
    lm.time.proceed();
}

/// Resets all game over state, timers, and selections back to default.
pub fn reset() void {
    is_showing = false;
    navigation.reset(false);
    restart_lockout_timer_seconds = 0.0;
    last_mouse_position = .init(-1, -1);
    mouse_moved = false;
}

/// Advances the restart lockout timer by delta_seconds.
pub fn update(delta_seconds: f32) void {
    if (restart_lockout_timer_seconds > 0.0) {
        restart_lockout_timer_seconds = @max(0.0, restart_lockout_timer_seconds - delta_seconds);
    }
}

/// Returns true if the restart lockout duration has elapsed.
pub fn canRestart() bool {
    return restart_lockout_timer_seconds <= 0.0;
}

/// Returns true if the button at index is active and selectable.
pub fn isButtonActive(index: usize) bool {
    const is_disabled = (index == @intFromEnum(GameOverAction.restart) and !canRestart());
    return !is_disabled and (navigation.selected_index == index);
}

/// Returns true if the game over menu is currently visible.
pub fn isShowing() bool {
    return is_showing;
}

/// Renders the game over backdrop, summary card, stats, and action buttons.
pub fn draw(allocator: ?std.mem.Allocator) void {
    _ = allocator;
    if (!is_showing) return;

    const window_size = lm.window.size.get();
    const ui_scale = theme.calculateUiScale(window_size);

    update(lm.time.deltaTime());

    if (!navigation.consumeJustOpened()) {
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
        .background_color = color_scheme.backdrop_danger,
    })({
        drawCard(ui_scale, window_size);
    });

    navigation.syncSelectionAudio();
}

fn drawCard(ui_scale: f32, window_size: lm.Vector2) void {
    const card_width_pixels = @min(window_size.x - 32, @round(105.0 * ui_scale));
    const card_padding_pixels = lm.tou16(@round(6.0 * ui_scale));
    const card_gap_pixels = lm.tou16(@round(4.0 * ui_scale));
    const title_font_size = theme.scaledU16(6.0, 12, ui_scale);
    const subtitle_font_size = theme.scaledU16(3.25, 6, ui_scale);
    const letter_spacing = theme.scaledU16(0.5, 1, ui_scale);

    ui.new(.{
        .id = .ID("gameover-card"),
        .layout = .{
            .sizing = .{ .w = .fixed(card_width_pixels) },
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = card_gap_pixels,
            .padding = .all(card_padding_pixels),
        },
        .background_color = color_scheme.panel_danger_background,
        .corner_radius = .all(3.5 * ui_scale),
        .border = .{
            .color = color_scheme.accent_crimson_border,
            .width = .outside(2),
        },
    })({
        drawHeader(title_font_size, subtitle_font_size, letter_spacing, ui_scale);

        const content_width_pixels = card_width_pixels - @as(f32, @floatFromInt(card_padding_pixels * 2));
        drawStatsBox(content_width_pixels, ui_scale);
        drawActionButtons(content_width_pixels, ui_scale);
    });
}

fn drawHeader(title_font_size: u16, subtitle_font_size: u16, letter_spacing: u16, ui_scale: f32) void {
    ui.new(.{
        .id = .ID("gameover-header"),
        .layout = .{
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = lm.tou16(@round(1.0 * ui_scale)),
        },
    })({
        ui.text("GAME OVER", .{
            .color = color_scheme.accent_crimson,
            .letter_spacing = theme.scaledU16(0.75, 1, ui_scale),
            .font_size = title_font_size,
            .alignment = .center,
            .font_id = theme.boldFontId(),
        });
        ui.text("You have fallen in battle", .{
            .color = color_scheme.text_danger_subtitle,
            .letter_spacing = letter_spacing,
            .font_size = subtitle_font_size,
            .alignment = .center,
            .font_id = theme.regularFontId(),
        });
    });
}

fn resolveStatValue(comptime field: StatField) usize {
    return switch (field) {
        .rooms_cleared => run_stats.rooms_cleared,
        .enemies_defeated => run_stats.enemies_defeated,
        .experience_collected => run_stats.experience_collected,
        .high_score => SaveSystem.getScores().high_score,
    };
}

fn drawStatsBox(box_width_pixels: f32, ui_scale: f32) void {
    const box_padding_pixels = lm.tou16(@round(3.5 * ui_scale));
    const box_gap_pixels = lm.tou16(@round(2.0 * ui_scale));
    const row_height_pixels = @round(6.0 * ui_scale);

    ui.new(.{
        .id = .ID("gameover-stats-box"),
        .layout = .{
            .sizing = .{ .w = .fixed(box_width_pixels) },
            .direction = .top_to_bottom,
            .padding = .all(box_padding_pixels),
            .child_gap = box_gap_pixels,
        },
        .background_color = color_scheme.surface_danger_inset,
        .corner_radius = .all(2.0 * ui_scale),
        .border = .{
            .color = color_scheme.border_danger_subtle,
            .width = .outside(1),
        },
    })({
        inline for (stat_row_specs, 0..) |row_spec, row_index| {
            drawStatRow(row_index, row_spec, resolveStatValue(row_spec.field), row_height_pixels, ui_scale);
        }
    });
}

fn drawStatRow(
    comptime row_index: usize,
    comptime row_spec: StatRowSpec,
    stat_value: usize,
    row_height_pixels: f32,
    ui_scale: f32,
) void {
    const font_size = theme.scaledU16(3.25, 6, ui_scale);
    const letter_spacing = theme.scaledU16(0.25, 1, ui_scale);

    ui.new(.{
        .id = .ID(row_spec.label),
        .layout = .{
            .sizing = .{ .w = .grow, .h = .fixed(row_height_pixels) },
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
        },
    })({
        ui.text(row_spec.label, .{
            .color = color_scheme.text_danger_muted,
            .letter_spacing = letter_spacing,
            .font_size = font_size,
            .font_id = theme.regularFontId(),
        });

        ui.new(.{
            .id = .IDI("stat-row-spacer-", @intCast(row_index)),
            .layout = .{ .sizing = .{ .w = .grow } },
        })({});

        ui.textFmt(row_spec.format_string, .{stat_value}, .{
            .color = row_spec.value_color,
            .letter_spacing = letter_spacing,
            .font_size = font_size,
            .font_id = theme.boldFontId(),
        });
    });
}

fn updateMouseMovement() void {
    const current_mouse_position = lm.mouse.getPosition();
    mouse_moved = (current_mouse_position.x != last_mouse_position.x or current_mouse_position.y != last_mouse_position.y);
    last_mouse_position = current_mouse_position;
}

fn drawActionButtons(button_maximum_width_pixels: f32, ui_scale: f32) void {
    updateMouseMovement();

    const button_width_pixels = @min(button_maximum_width_pixels, @round(theme.MENU_BUTTON_BASE_WIDTH * ui_scale));
    const gap_pixels = lm.tou16(@round(2.5 * ui_scale));
    const font_size = theme.scaledU16(3.75, 7, ui_scale);
    const letter_spacing = theme.scaledU16(0.5, 1, ui_scale);

    var stationary_cursor_selection = navigation.selected_index;
    const selection_target = if (mouse_moved) &navigation.selected_index else &stationary_cursor_selection;

    ui.new(.{
        .id = .ID("gameover-buttons-col"),
        .layout = .{
            .sizing = .{ .w = .fixed(button_width_pixels) },
            .direction = .top_to_bottom,
            .child_gap = gap_pixels,
            .child_alignment = .{ .x = .center },
        },
    })({
        inline for (std.enums.values(GameOverAction)) |action| {
            const action_index = @intFromEnum(action);
            sprite_button.draw(
                .menu,
                action_index,
                action.caption(),
                selection_target,
                activateAction,
                ui_scale,
                .{
                    .letter_spacing = letter_spacing,
                    .font_size_override = font_size,
                    .is_disabled = (action == .restart and !canRestart()),
                    .idle_text_color_override = action.idleTextColor(),
                    .width_override_pixels = button_width_pixels,
                    .id_prefix_override = "gameover-btn-",
                },
            );
        }

        ui.new(.{
            .id = .ID("gameover-footer-spacer"),
            .layout = .{ .sizing = .{ .h = .fixed(@round(3.5 * ui_scale)), .w = .fixed(1) } },
        })({});

        menu_navigation.drawFooterHint(
            "gameover-footer-container",
            "Navigate: D-Pad / L-Stick  |  Select: A",
            "Navigate: WASD / Arrows  |  Select: Enter / Click",
            ui_scale,
        );
    });
}

fn handleInput() void {
    const input = navigation.readMenuInput();
    const actions = std.enums.values(GameOverAction);
    navigation.applyVerticalNavigation(input, actions.len);

    if (!input.select_pressed) return;
    if (navigation.selected_index == @intFromEnum(GameOverAction.restart) and !canRestart()) return;
    activateAction(navigation.selected_index);
}

fn activateAction(index: usize) void {
    const actions = std.enums.values(GameOverAction);
    if (index >= actions.len) return;
    switch (actions[index]) {
        .restart => restartRun(),
        .exit => exitRun(),
    }
}

fn restartRun() void {
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

fn exitRun() void {
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
    defer {
        hide();
        lm.time.proceed();
    }

    show(.{
        .rooms_cleared = 2,
        .current_room = 3,
        .enemies_defeated = 15,
        .experience_collected = 120,
    });

    try std.testing.expect(is_showing);
    try std.testing.expect(isShowing());
    try std.testing.expect(lm.time.paused());
    try std.testing.expect(navigation.just_opened);
    try std.testing.expectEqual(@as(u32, 2), run_stats.rooms_cleared);
    try std.testing.expectEqual(@as(u32, 15), run_stats.enemies_defeated);
    try std.testing.expectEqual(@as(usize, 120), run_stats.experience_collected);

    hide();
    try std.testing.expect(!is_showing);
    try std.testing.expect(!isShowing());
    try std.testing.expect(!lm.time.paused());
    try std.testing.expect(!navigation.just_opened);
}

test "GameOverMenu restart lockout timeout and rejection" {
    reset();
    lm.time.proceed();
    defer {
        hide();
        lm.time.proceed();
    }

    show(.{});
    try std.testing.expect(is_showing);
    try std.testing.expect(!canRestart());
    try std.testing.expectEqual(@as(f32, RESTART_LOCKOUT_DURATION_SECONDS), restart_lockout_timer_seconds);

    activateAction(@intFromEnum(GameOverAction.restart));
    try std.testing.expect(is_showing);

    update(1.0);
    try std.testing.expect(!canRestart());
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), restart_lockout_timer_seconds, 0.001);

    activateAction(@intFromEnum(GameOverAction.restart));
    try std.testing.expect(is_showing);

    update(0.5);
    try std.testing.expect(canRestart());
    try std.testing.expectEqual(@as(f32, 0.0), restart_lockout_timer_seconds);

    hide();
    try std.testing.expect(!is_showing);
    try std.testing.expect(canRestart());
}
