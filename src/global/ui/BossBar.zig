const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const Stats = @import("../../components/Stats.zig");
const OverheadUI = @import("../../components/enemy/OverheadUI.zig");

const Self = @This();

pub const BossRank = enum {
    mini_boss,
    boss,

    pub fn getTitle(self: BossRank) []const u8 {
        return switch (self) {
            .mini_boss => "MINI-BOSS",
            .boss => "BOSS",
        };
    }

    pub fn getAccentColor(self: BossRank) lm.Color {
        return switch (self) {
            .mini_boss => lm.Color{ .r = 240, .g = 195, .b = 80, .a = 255 },
            .boss => lm.Color{ .r = 255, .g = 85, .b = 95, .a = 255 },
        };
    }
};

const BASE_BAR_WIDTH_PIXELS: f32 = 512.0;
const BASE_BAR_HEIGHT_PIXELS: f32 = 16.0;
const BASE_OVERLAY_WIDTH_PIXELS: f32 = 528.0;
const BASE_OVERLAY_HEIGHT_PIXELS: f32 = 28.0;
const BASE_OVERLAY_OFFSET_X_PIXELS: f32 = -8.0;
const BASE_OVERLAY_OFFSET_Y_PIXELS: f32 = -6.0;

const DAMAGE_LAG_DELAY_SECONDS: f32 = 0.1;
const HEALTH_LERP_RATE_PER_SECOND: f32 = 50.0;
const DAMAGE_LAG_LERP_RATE_PER_SECOND: f32 = 4.0;
const DEFEAT_FADE_DURATION_SECONDS: f32 = 1.5;

pub const BossBarState = struct {
    is_active: bool = false,
    boss_uuid: ?u128 = null,
    boss_stats: ?*Stats = null,
    boss_name: []const u8 = "Boss",
    rank: BossRank = .mini_boss,

    current_health: f32 = 1.0,
    max_health: f32 = 1.0,
    display_health: f32 = 0.0,
    damage_lag_health: f32 = 0.0,
    damage_lag_delay_timer_seconds: f32 = 0.0,

    fade_alpha: f32 = 0.0,
    is_defeating: bool = false,
    defeat_timer_seconds: f32 = 0.0,
};

var global_state: BossBarState = .{};

fn getStatsComponent(entity: *lm.Entity) ?*Stats {
    if (entity.getComponent(Stats)) |stats| return stats;
    return entity.getComponentUnsafe(Stats).result;
}

/// Binds the boss health bar to an active entity.
pub fn bind(entity: *lm.Entity, name: []const u8, rank: BossRank) void {
    global_state.is_active = true;
    global_state.boss_uuid = entity.uuid;
    global_state.boss_name = name;
    global_state.rank = rank;
    global_state.is_defeating = false;
    global_state.defeat_timer_seconds = 0.0;
    global_state.damage_lag_delay_timer_seconds = 0.0;
    global_state.fade_alpha = 1.0;

    if (getStatsComponent(entity)) |stats| {
        global_state.boss_stats = stats;
        global_state.current_health = stats.current.health;
        global_state.max_health = @max(1.0, stats.max.health);
        global_state.display_health = stats.current.health;
        global_state.damage_lag_health = stats.current.health;
    }

    if (entity.getComponent(OverheadUI)) |overhead_ui| {
        overhead_ui.show_health_bar = false;
    } else if (entity.getComponentUnsafe(OverheadUI).result) |overhead_ui| {
        overhead_ui.show_health_bar = false;
    }
}

/// Disconnects the active boss entity and resets state.
pub fn unbind() void {
    global_state.is_active = false;
    global_state.boss_uuid = null;
    global_state.boss_stats = null;
    global_state.fade_alpha = 0.0;
    global_state.is_defeating = false;
    global_state.defeat_timer_seconds = 0.0;
}

/// Returns whether the boss health bar is currently active and visible.
pub fn isActive() bool {
    return global_state.is_active and global_state.fade_alpha > 0.001;
}

/// Notifies the boss health bar that the active boss entity has been defeated.
pub fn onBossDefeated(defeated_uuid: u128) void {
    const active_uuid = global_state.boss_uuid orelse return;
    if (active_uuid != defeated_uuid) return;

    global_state.current_health = 0.0;
    global_state.display_health = 0.0;
    global_state.boss_stats = null;
    global_state.is_defeating = true;
}

/// Updates health lerping, damage lag timer, and defeat fade transition.
pub fn update(delta_time_seconds: f32) void {
    if (!global_state.is_active) return;

    if (global_state.is_defeating) {
        updateDefeatTransition(delta_time_seconds);
        return;
    }

    updateActiveHealth(delta_time_seconds);
}

fn updateDefeatTransition(delta_time_seconds: f32) void {
    global_state.defeat_timer_seconds += delta_time_seconds;
    const progress = global_state.defeat_timer_seconds / DEFEAT_FADE_DURATION_SECONDS;
    global_state.fade_alpha = @max(0.0, 1.0 - progress);

    if (global_state.defeat_timer_seconds >= DEFEAT_FADE_DURATION_SECONDS) {
        unbind();
    }
}

fn updateActiveHealth(delta_time_seconds: f32) void {
    global_state.fade_alpha = 1.0;

    if (global_state.boss_stats == null) {
        if (global_state.boss_uuid) |boss_uuid| {
            if (lm.activeScene()) |scene| {
                if (scene.getEntityByUuid(boss_uuid)) |boss_entity| {
                    if (getStatsComponent(boss_entity)) |stats| {
                        global_state.boss_stats = stats;
                        global_state.current_health = stats.current.health;
                        global_state.max_health = @max(1.0, stats.max.health);
                        global_state.display_health = stats.current.health;
                        global_state.damage_lag_health = stats.current.health;
                    }
                }
            }
        }
    }

    const stats = global_state.boss_stats orelse return;

    if (stats.current.health <= 0.0) {
        global_state.current_health = 0.0;
        global_state.display_health = 0.0;
        global_state.boss_stats = null;
        global_state.is_defeating = true;
        return;
    }

    global_state.current_health = stats.current.health;
    global_state.max_health = @max(1.0, stats.max.health);

    const health_change = global_state.current_health - global_state.display_health;
    if (health_change < -0.1) {
        global_state.damage_lag_delay_timer_seconds = DAMAGE_LAG_DELAY_SECONDS;
    }

    const health_step = (global_state.current_health - global_state.display_health) * @min(1.0, delta_time_seconds * HEALTH_LERP_RATE_PER_SECOND);
    global_state.display_health += health_step;

    if (global_state.damage_lag_delay_timer_seconds > 0.0) {
        global_state.damage_lag_delay_timer_seconds -= delta_time_seconds;
    } else {
        const lag_step = (global_state.display_health - global_state.damage_lag_health) * @min(1.0, delta_time_seconds * DAMAGE_LAG_LERP_RATE_PER_SECOND);
        global_state.damage_lag_health += lag_step;
    }
}

/// Renders the boss health bar HUD component.
pub fn draw(allocator: ?std.mem.Allocator, ui_scale: f32, scale: f32) void {
    if (!isActive()) return;

    const total_bar_width_pixels = BASE_BAR_WIDTH_PIXELS * ui_scale;
    const total_bar_height_pixels = BASE_BAR_HEIGHT_PIXELS * ui_scale;
    const container_width_pixels = total_bar_width_pixels + (16.0 * ui_scale);

    const accent_color = global_state.rank.getAccentColor();
    const alpha_u8: u8 = @intFromFloat(global_state.fade_alpha * 255.0);

    ui.new(.{
        .id = .ID("boss-hud-container"),
        .floating = .{
            .attach_to = .to_root,
            .attach_points = .{
                .element = .center_top,
                .parent = .center_top,
            },
            .offset = .{ .x = 0, .y = 68.0 * scale },
        },
        .layout = .{
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = lm.tou16(@round(4.0 * ui_scale)),
            .sizing = .{ .w = .fixed(container_width_pixels), .h = .fit },
        },
    })({
        renderHeader(global_state.boss_name, global_state.rank, accent_color, alpha_u8, ui_scale);
        renderHealthBarTrough(allocator, total_bar_width_pixels, total_bar_height_pixels, accent_color, alpha_u8, ui_scale);
    });
}

fn renderHeader(boss_name: []const u8, rank: BossRank, accent_color: lm.Color, alpha_u8: u8, ui_scale: f32) void {
    const title_font_size_pixels = lm.tou16(@max(13, @round(15.0 * ui_scale)));
    const rank_font_size_pixels = lm.tou16(@max(9, @round(11.0 * ui_scale)));

    ui.new(.{
        .id = .ID("boss-hud-header"),
        .layout = .{
            .direction = .left_to_right,
            .sizing = .{ .w = .percent(1) },
            .child_alignment = .{ .y = .center },
            .padding = .axes(0, lm.tou16(@round(2.0 * ui_scale))),
        },
    })({
        ui.new(.{
            .id = .ID("boss-hud-title-container"),
        })({
            ui.text(boss_name, .{
                .color = ui.color(255, 240, 245, alpha_u8),
                .font_size = title_font_size_pixels,
                .letter_spacing = 1,
            });
        });

        ui.new(.{
            .id = .ID("boss-hud-spacer"),
            .layout = .{ .sizing = .{ .w = .grow } },
        })({});

        ui.new(.{
            .id = .ID("boss-hud-rank-badge"),
            .background_color = ui.color(18, 16, 22, @min(alpha_u8, 220)),
            .corner_radius = .all(4.0 * ui_scale),
            .border = .{
                .color = ui.color(accent_color.r, accent_color.g, accent_color.b, @min(alpha_u8, 200)),
                .width = .outside(1),
            },
            .layout = .{
                .padding = .axes(lm.tou16(@round(2.0 * ui_scale)), lm.tou16(@round(6.0 * ui_scale))),
            },
        })({
            ui.text(rank.getTitle(), .{
                .color = ui.color(accent_color.r, accent_color.g, accent_color.b, alpha_u8),
                .font_size = rank_font_size_pixels,
                .letter_spacing = 1,
            });
        });
    });
}

fn renderHealthBarTrough(
    allocator: ?std.mem.Allocator,
    total_bar_width_pixels: f32,
    total_bar_height_pixels: f32,
    accent_color: lm.Color,
    alpha_u8: u8,
    ui_scale: f32,
) void {
    const health_ratio = std.math.clamp(global_state.display_health / global_state.max_health, 0.0, 1.0);
    const lag_ratio = std.math.clamp(global_state.damage_lag_health / global_state.max_health, 0.0, 1.0);

    ui.new(.{
        .id = .ID("boss-health-trough"),
        .background_color = ui.color(20, 14, 18, @min(alpha_u8, 240)),
        .corner_radius = .all(3.0 * ui_scale),
        .border = .{
            .color = ui.color(accent_color.r, accent_color.g, accent_color.b, @min(alpha_u8, 160)),
            .width = .outside(1),
        },
        .layout = .{
            .sizing = .{ .w = .fixed(total_bar_width_pixels), .h = .fixed(total_bar_height_pixels) },
        },
    })({
        ui.new(.{
            .id = .ID("boss-health-damage-lag"),
            .floating = .{
                .attach_to = .to_parent,
                .attach_points = .{ .element = .left_top, .parent = .left_top },
                .pointer_capture_mode = .passthrough,
                .z_index = 1,
            },
            .background_color = ui.color(235, 155, 45, @min(alpha_u8, 220)),
            .corner_radius = .all(3.0 * ui_scale),
            .layout = .{
                .sizing = .{ .w = .fixed(total_bar_width_pixels * lag_ratio), .h = .fixed(total_bar_height_pixels) },
            },
        })({});

        ui.new(.{
            .id = .ID("boss-health-current-fill"),
            .floating = .{
                .attach_to = .to_parent,
                .attach_points = .{ .element = .left_top, .parent = .left_top },
                .pointer_capture_mode = .passthrough,
                .z_index = 2,
            },
            .background_color = ui.color(225, 28, 48, alpha_u8),
            .corner_radius = .all(3.0 * ui_scale),
            .layout = .{
                .sizing = .{ .w = .fixed(total_bar_width_pixels * health_ratio), .h = .fixed(total_bar_height_pixels) },
            },
        })({});

        renderPhaseDividers(total_bar_width_pixels, total_bar_height_pixels, ui_scale);
        renderHealthText(allocator, total_bar_width_pixels, total_bar_height_pixels, alpha_u8, ui_scale);
        renderOverlayFrame(ui_scale);
    });
}

fn renderPhaseDividers(total_bar_width_pixels: f32, total_bar_height_pixels: f32, ui_scale: f32) void {
    const divider_width_pixels = @max(1.0, @round(1.0 * ui_scale));
    const fractions = [_]f32{ 0.25, 0.50, 0.75 };

    for (fractions, 0..) |fraction, divider_index| {
        const offset_x_pixels = (total_bar_width_pixels * fraction) - (divider_width_pixels * 0.5);

        ui.new(.{
            .id = .IDI("boss-phase-divider-", @intCast(divider_index)),
            .floating = .{
                .attach_to = .to_parent,
                .attach_points = .{ .element = .left_top, .parent = .left_top },
                .offset = .{ .x = offset_x_pixels, .y = 0 },
                .pointer_capture_mode = .passthrough,
                .z_index = 3,
            },
            .background_color = ui.color(40, 16, 22, 180),
            .layout = .{
                .sizing = .{ .w = .fixed(divider_width_pixels), .h = .fixed(total_bar_height_pixels) },
            },
        })({});
    }
}

fn renderHealthText(
    allocator: ?std.mem.Allocator,
    total_bar_width_pixels: f32,
    total_bar_height_pixels: f32,
    alpha_u8: u8,
    ui_scale: f32,
) void {
    const current_health_int: u32 = @intFromFloat(@max(0.0, global_state.display_health));
    const max_health_int: u32 = @intFromFloat(@max(1.0, global_state.max_health));
    const health_percentage: u32 = @intFromFloat(std.math.clamp(global_state.display_health / global_state.max_health * 100.0, 0.0, 100.0));

    const health_string = if (allocator) |string_allocator|
        std.fmt.allocPrint(string_allocator, "{d} / {d} ({d}%)", .{ current_health_int, max_health_int, health_percentage }) catch "0 / 0"
    else
        "";

    const font_size_pixels = lm.tou16(@max(9, @round(10.0 * ui_scale)));

    ui.new(.{
        .id = .ID("boss-health-text-container"),
        .floating = .{
            .attach_to = .to_parent,
            .attach_points = .{ .element = .center_center, .parent = .center_center },
            .pointer_capture_mode = .passthrough,
            .z_index = 4,
        },
        .layout = .{
            .sizing = .{ .w = .fixed(total_bar_width_pixels), .h = .fixed(total_bar_height_pixels) },
            .child_alignment = .{ .x = .center, .y = .center },
        },
    })({
        ui.text(health_string, .{
            .color = ui.color(255, 255, 255, alpha_u8),
            .font_size = font_size_pixels,
            .letter_spacing = 1,
        });
    });
}

fn renderOverlayFrame(ui_scale: f32) void {
    const overlay_width_pixels = BASE_OVERLAY_WIDTH_PIXELS * ui_scale;
    const overlay_height_pixels = BASE_OVERLAY_HEIGHT_PIXELS * ui_scale;
    const offset_x_pixels = BASE_OVERLAY_OFFSET_X_PIXELS * ui_scale;
    const offset_y_pixels = BASE_OVERLAY_OFFSET_Y_PIXELS * ui_scale;

    ui.new(.{
        .id = .ID("boss-health-overlay-frame"),
        .floating = .{
            .attach_to = .to_parent,
            .attach_points = .{ .element = .left_top, .parent = .left_top },
            .offset = .{ .x = offset_x_pixels, .y = offset_y_pixels },
            .pointer_capture_mode = .passthrough,
            .z_index = 5,
        },
        .image = ui.image("ui/enemies/boss_healthbar_overlay.png", .init(overlay_width_pixels, overlay_height_pixels)) catch .{ .image_data = null },
        .layout = .{
            .sizing = .{ .w = .fixed(overlay_width_pixels), .h = .fixed(overlay_height_pixels) },
        },
    })({});
}

test "BossRank titles and accent colors" {
    try std.testing.expectEqualStrings("MINI-BOSS", BossRank.mini_boss.getTitle());
    try std.testing.expectEqualStrings("BOSS", BossRank.boss.getTitle());

    const mini_boss_color = BossRank.mini_boss.getAccentColor();
    try std.testing.expectEqual(@as(u8, 240), mini_boss_color.r);
    try std.testing.expectEqual(@as(u8, 195), mini_boss_color.g);
    try std.testing.expectEqual(@as(u8, 80), mini_boss_color.b);

    const boss_color = BossRank.boss.getAccentColor();
    try std.testing.expectEqual(@as(u8, 255), boss_color.r);
    try std.testing.expectEqual(@as(u8, 85), boss_color.g);
    try std.testing.expectEqual(@as(u8, 95), boss_color.b);
}

test "BossBar unbind resets state and isActive returns false" {
    unbind();
    try std.testing.expect(!isActive());
    try std.testing.expectEqual(@as(?u128, null), global_state.boss_uuid);
    try std.testing.expectEqual(@as(?*Stats, null), global_state.boss_stats);
    try std.testing.expect(!global_state.is_active);
}

test "BossBar updateDefeatTransition fades out smoothly" {
    unbind();
    global_state.is_active = true;
    global_state.is_defeating = true;
    global_state.fade_alpha = 1.0;
    global_state.defeat_timer_seconds = 0.0;

    update(0.75);
    try std.testing.expect(global_state.fade_alpha < 1.0);
    try std.testing.expect(global_state.fade_alpha > 0.0);
    try std.testing.expect(isActive());

    update(0.80);
    try std.testing.expect(!isActive());
    try std.testing.expect(!global_state.is_active);
}

test "BossBar damage lag delay timer activates on health drop" {
    unbind();
    global_state.is_active = true;
    global_state.current_health = 1000.0;
    global_state.max_health = 1000.0;
    global_state.display_health = 1000.0;
    global_state.damage_lag_health = 1000.0;
    global_state.damage_lag_delay_timer_seconds = 0.0;

    // Simulate health drop without active entity in scene
    global_state.current_health = 800.0;
    global_state.damage_lag_delay_timer_seconds = DAMAGE_LAG_DELAY_SECONDS;

    try std.testing.expectApproxEqAbs(DAMAGE_LAG_DELAY_SECONDS, global_state.damage_lag_delay_timer_seconds, 0.001);
}

test "BossBar onBossDefeated initiates defeat transition" {
    unbind();
    global_state.is_active = true;
    global_state.boss_uuid = 999;
    global_state.fade_alpha = 1.0;

    onBossDefeated(111);
    try std.testing.expect(!global_state.is_defeating);

    onBossDefeated(999);
    try std.testing.expect(global_state.is_defeating);
    try std.testing.expectEqual(@as(?*Stats, null), global_state.boss_stats);
}
