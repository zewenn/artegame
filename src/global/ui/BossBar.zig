const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const Stats = @import("../../components/Stats.zig");
const OverheadUI = @import("../../components/enemy/OverheadUI.zig");
const HUD = @import("../HUD.zig");
const GameOverMenu = @import("GameOverMenu.zig");
const PauseMenu = @import("PauseMenu.zig");
const BoonMenu = @import("BoonMenu.zig");

const Self = @This();

stats: ?*Stats = null,
overhead_ui: ?*OverheadUI = null,
boss_name: []const u8 = "Boss",
rank: BossRank = .mini_boss,
ui_id: u32 = 0,

current_health: f32 = 1.0,
max_health: f32 = 1.0,
display_health: f32 = 1.0,
damage_lag_health: f32 = 1.0,
damage_lag_delay_timer_seconds: f32 = 0.0,

pub fn Awake(self: *Self) void {
    self.ui_id = acquireId();
}

pub fn Start(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.overhead_ui = entity.getComponent(OverheadUI);
    if (self.overhead_ui) |overhead_ui| {
        overhead_ui.show_health_bar = false;
    }
    self.syncHealthFromStats(self.stats.?);
}

pub fn Update(self: *Self) !void {
    const stats: *Stats = try lm.ensureComponent(self.stats);
    self.stepHealthInterpolation(stats, lm.time.deltaTime());
    if (!shouldRender()) return;
    self.render(HUD.ui_scale, HUD.scale);
}

pub fn End(self: *Self) void {
    releaseId(self.ui_id);
}

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

const MAX_BOSS_BARS: usize = 16;
var id_pool: [MAX_BOSS_BARS]bool = @splat(false);

const BASE_BAR_WIDTH_PIXELS: f32 = 512.0;
const BASE_BAR_HEIGHT_PIXELS: f32 = 16.0;
const BASE_OVERLAY_WIDTH_PIXELS: f32 = 528.0;
const BASE_OVERLAY_HEIGHT_PIXELS: f32 = 28.0;
const BASE_OVERLAY_OFFSET_X_PIXELS: f32 = -8.0;
const BASE_OVERLAY_OFFSET_Y_PIXELS: f32 = -6.0;

const DAMAGE_LAG_DELAY_SECONDS: f32 = 0.1;
const HEALTH_LERP_RATE_PER_SECOND: f32 = 50.0;
const DAMAGE_LAG_LERP_RATE_PER_SECOND: f32 = 4.0;
const BASE_TOP_OFFSET_PIXELS: f32 = 68.0;
const STACK_VERTICAL_STRIDE_PIXELS: f32 = 52.0;

pub fn shouldRender() bool {
    if (GameOverMenu.isShowing()) return false;
    if (PauseMenu.isShowing()) return false;
    if (BoonMenu.isShowing()) return false;
    return true;
}

pub fn syncHealthFromStats(self: *Self, stats: *const Stats) void {
    self.current_health = @max(0.0, stats.current.health);
    self.max_health = @max(1.0, stats.max.health);
    self.display_health = self.current_health;
    self.damage_lag_health = self.current_health;
    self.damage_lag_delay_timer_seconds = 0.0;
}

pub fn stepHealthInterpolation(self: *Self, stats: *const Stats, delta_seconds: f32) void {
    self.current_health = @max(0.0, stats.current.health);
    self.max_health = @max(1.0, stats.max.health);

    const health_difference = self.current_health - self.display_health;
    if (health_difference < -0.1) {
        self.damage_lag_delay_timer_seconds = DAMAGE_LAG_DELAY_SECONDS;
    }

    const health_step = (self.current_health - self.display_health) * @min(1.0, delta_seconds * HEALTH_LERP_RATE_PER_SECOND);
    self.display_health += health_step;

    if (self.damage_lag_delay_timer_seconds > 0.0) {
        self.damage_lag_delay_timer_seconds -= delta_seconds;
    } else {
        const lag_step = (self.display_health - self.damage_lag_health) * @min(1.0, delta_seconds * DAMAGE_LAG_LERP_RATE_PER_SECOND);
        self.damage_lag_health += lag_step;
    }
}

pub fn render(self: *const Self, ui_scale: f32, hud_scale: f32) void {
    const total_bar_width_pixels = BASE_BAR_WIDTH_PIXELS * ui_scale;
    const total_bar_height_pixels = BASE_BAR_HEIGHT_PIXELS * ui_scale;
    const container_width_pixels = total_bar_width_pixels + (16.0 * ui_scale);
    const top_offset_pixels = (BASE_TOP_OFFSET_PIXELS * hud_scale) + (@as(f32, @floatFromInt(self.ui_id)) * STACK_VERTICAL_STRIDE_PIXELS * ui_scale);

    ui.new(.{
        .id = .IDI("boss-hud-container-", self.ui_id),
        .floating = .{
            .attach_to = .to_root,
            .attach_points = .{
                .element = .center_top,
                .parent = .center_top,
            },
            .offset = .{ .x = 0, .y = top_offset_pixels },
        },
        .layout = .{
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = lm.tou16(@round(4.0 * ui_scale)),
            .sizing = .{ .w = .fixed(container_width_pixels), .h = .fit },
        },
    })({
        self.renderHeader(ui_scale);
        self.renderHealthBarTrough(total_bar_width_pixels, total_bar_height_pixels, ui_scale);
    });
}

fn renderHeader(self: *const Self, ui_scale: f32) void {
    ui.new(.{
        .id = .IDI("boss-hud-header-", self.ui_id),
        .layout = .{
            .direction = .left_to_right,
            .sizing = .{ .w = .percent(1) },
            .child_alignment = .{ .y = .center },
            .padding = .axes(0, lm.tou16(@round(2.0 * ui_scale))),
        },
    })({
        self.renderTitleText(ui_scale);
        ui.new(.{
            .id = .IDI("boss-hud-spacer-", self.ui_id),
            .layout = .{ .sizing = .{ .w = .grow } },
        })({});
        self.renderRankBadge(ui_scale);
    });
}

fn renderTitleText(self: *const Self, ui_scale: f32) void {
    const title_font_size_pixels = lm.tou16(@max(13, @round(15.0 * ui_scale)));

    ui.new(.{
        .id = .IDI("boss-hud-title-container-", self.ui_id),
    })({
        ui.text(self.boss_name, .{
            .color = ui.color(255, 240, 245, 255),
            .font_size = title_font_size_pixels,
            .letter_spacing = 1,
        });
    });
}

fn renderRankBadge(self: *const Self, ui_scale: f32) void {
    const rank_font_size_pixels = lm.tou16(@max(9, @round(11.0 * ui_scale)));
    const accent_color = self.rank.getAccentColor();

    ui.new(.{
        .id = .IDI("boss-hud-rank-badge-", self.ui_id),
        .background_color = ui.color(18, 16, 22, 220),
        .corner_radius = .all(4.0 * ui_scale),
        .border = .{
            .color = ui.color(accent_color.r, accent_color.g, accent_color.b, 200),
            .width = .outside(1),
        },
        .layout = .{
            .padding = .axes(lm.tou16(@round(2.0 * ui_scale)), lm.tou16(@round(6.0 * ui_scale))),
        },
    })({
        ui.text(self.rank.getTitle(), .{
            .color = ui.color(accent_color.r, accent_color.g, accent_color.b, 255),
            .font_size = rank_font_size_pixels,
            .letter_spacing = 1,
        });
    });
}

fn renderHealthBarTrough(
    self: *const Self,
    total_bar_width_pixels: f32,
    total_bar_height_pixels: f32,
    ui_scale: f32,
) void {
    const accent_color = self.rank.getAccentColor();

    ui.new(.{
        .id = .IDI("boss-health-trough-", self.ui_id),
        .background_color = ui.color(20, 14, 18, 240),
        .corner_radius = .all(3.0 * ui_scale),
        .border = .{
            .color = ui.color(accent_color.r, accent_color.g, accent_color.b, 160),
            .width = .outside(1),
        },
        .layout = .{
            .sizing = .{ .w = .fixed(total_bar_width_pixels), .h = .fixed(total_bar_height_pixels) },
        },
    })({
        self.renderDamageLagFill(total_bar_width_pixels, total_bar_height_pixels, ui_scale);
        self.renderCurrentHealthFill(total_bar_width_pixels, total_bar_height_pixels, ui_scale);
        self.renderPhaseDividers(total_bar_width_pixels, total_bar_height_pixels, ui_scale);
        self.renderHealthText(total_bar_width_pixels, total_bar_height_pixels, ui_scale);
        self.renderOverlayFrame(ui_scale);
    });
}

fn renderDamageLagFill(
    self: *const Self,
    total_bar_width_pixels: f32,
    total_bar_height_pixels: f32,
    ui_scale: f32,
) void {
    const lag_ratio = std.math.clamp(self.damage_lag_health / self.max_health, 0.0, 1.0);

    ui.new(.{
        .id = .IDI("boss-health-damage-lag-", self.ui_id),
        .floating = .{
            .attach_to = .to_parent,
            .attach_points = .{ .element = .left_top, .parent = .left_top },
            .pointer_capture_mode = .passthrough,
            .z_index = 1,
        },
        .background_color = ui.color(235, 155, 45, 220),
        .corner_radius = .all(3.0 * ui_scale),
        .layout = .{
            .sizing = .{ .w = .fixed(total_bar_width_pixels * lag_ratio), .h = .fixed(total_bar_height_pixels) },
        },
    })({});
}

fn renderCurrentHealthFill(
    self: *const Self,
    total_bar_width_pixels: f32,
    total_bar_height_pixels: f32,
    ui_scale: f32,
) void {
    const health_ratio = std.math.clamp(self.display_health / self.max_health, 0.0, 1.0);

    ui.new(.{
        .id = .IDI("boss-health-current-fill-", self.ui_id),
        .floating = .{
            .attach_to = .to_parent,
            .attach_points = .{ .element = .left_top, .parent = .left_top },
            .pointer_capture_mode = .passthrough,
            .z_index = 2,
        },
        .background_color = ui.color(225, 28, 48, 255),
        .corner_radius = .all(3.0 * ui_scale),
        .layout = .{
            .sizing = .{ .w = .fixed(total_bar_width_pixels * health_ratio), .h = .fixed(total_bar_height_pixels) },
        },
    })({});
}

fn renderPhaseDividers(
    self: *const Self,
    total_bar_width_pixels: f32,
    total_bar_height_pixels: f32,
    ui_scale: f32,
) void {
    const divider_width_pixels = @max(1.0, @round(1.0 * ui_scale));
    const fractions = [_]f32{ 0.25, 0.50, 0.75 };

    for (fractions, 0..) |fraction, divider_index| {
        const offset_x_pixels = (total_bar_width_pixels * fraction) - (divider_width_pixels * 0.5);
        const element_id: u32 = (self.ui_id * 8) + @as(u32, @intCast(divider_index));

        ui.new(.{
            .id = .IDI("boss-phase-divider-", element_id),
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
    self: *const Self,
    total_bar_width_pixels: f32,
    total_bar_height_pixels: f32,
    ui_scale: f32,
) void {
    const rounded_current_health: u32 = @intFromFloat(@max(0.0, self.display_health));
    const rounded_max_health: u32 = @intFromFloat(@max(1.0, self.max_health));
    const health_percentage: u32 = @intFromFloat(std.math.clamp(self.display_health / self.max_health * 100.0, 0.0, 100.0));
    const font_size_pixels = lm.tou16(@max(9, @round(10.0 * ui_scale)));

    ui.new(.{
        .id = .IDI("boss-health-text-container-", self.ui_id),
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
        ui.textFmt("{d} / {d} ({d}%)", .{ rounded_current_health, rounded_max_health, health_percentage }, .{
            .color = ui.color(255, 255, 255, 255),
            .font_size = font_size_pixels,
            .letter_spacing = 1,
        });
    });
}

fn renderOverlayFrame(self: *const Self, ui_scale: f32) void {
    const overlay_width_pixels = BASE_OVERLAY_WIDTH_PIXELS * ui_scale;
    const overlay_height_pixels = BASE_OVERLAY_HEIGHT_PIXELS * ui_scale;
    const offset_x_pixels = BASE_OVERLAY_OFFSET_X_PIXELS * ui_scale;
    const offset_y_pixels = BASE_OVERLAY_OFFSET_Y_PIXELS * ui_scale;

    ui.new(.{
        .id = .IDI("boss-health-overlay-frame-", self.ui_id),
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

fn acquireId() u32 {
    for (&id_pool, 0..) |*in_use, pool_index| {
        if (!in_use.*) {
            in_use.* = true;
            return @intCast(pool_index);
        }
    }
    return 0;
}

fn releaseId(ui_id: u32) void {
    if (ui_id < id_pool.len) {
        id_pool[ui_id] = false;
    }
}

test "BossRank titles and accent colors" {
    try std.testing.expectEqualStrings("MINI-BOSS", BossRank.mini_boss.getTitle());
    try std.testing.expectEqualStrings("BOSS", BossRank.boss.getTitle());

    const mini_boss_color = BossRank.mini_boss.getAccentColor();
    try std.testing.expectEqual(@as(u8, 240), mini_boss_color.r);
    try std.testing.expectEqual(@as(u8, 195), mini_boss_color.g);
    try std.testing.expectEqual(@as(u8, 80), mini_boss_color.b);
    try std.testing.expectEqual(@as(u8, 255), mini_boss_color.a);

    const boss_color = BossRank.boss.getAccentColor();
    try std.testing.expectEqual(@as(u8, 255), boss_color.r);
    try std.testing.expectEqual(@as(u8, 85), boss_color.g);
    try std.testing.expectEqual(@as(u8, 95), boss_color.b);
    try std.testing.expectEqual(@as(u8, 255), boss_color.a);
}

test "BossBar shouldRender suppresses when GameOverMenu, PauseMenu, or BoonMenu is showing" {
    GameOverMenu.hide();
    PauseMenu.hide();
    BoonMenu.hide();
    try std.testing.expect(shouldRender());

    GameOverMenu.show(.{});
    try std.testing.expect(!shouldRender());
    GameOverMenu.hide();
    try std.testing.expect(shouldRender());

    PauseMenu.show();
    try std.testing.expect(!shouldRender());
    PauseMenu.hide();
    try std.testing.expect(shouldRender());

    const dummy_slots = [_]BoonMenu.BoonSlot{};
    BoonMenu.show(&dummy_slots);
    try std.testing.expect(!shouldRender());
    BoonMenu.hide();
    try std.testing.expect(shouldRender());
}

test "BossBar Start pulls Stats and disables OverheadUI health bar" {
    const entity = try lm.makeEntity("test-boss", .{
        lm.Transform{},
        Stats.init(.enemy, .{ .health = 1500.0 }),
        OverheadUI{ .show_health_bar = true },
        Self{ .boss_name = "Test Boss", .rank = .boss },
    });
    defer entity.deinit();
    try entity.addPreparedComponents(false);

    const boss_bar = entity.getComponent(Self).?;
    const overhead_ui = entity.getComponent(OverheadUI).?;
    try std.testing.expect(overhead_ui.show_health_bar);

    try boss_bar.Start(entity);
    try std.testing.expect(!overhead_ui.show_health_bar);
    try std.testing.expectEqual(@as(f32, 1500.0), boss_bar.current_health);
    try std.testing.expectEqual(@as(f32, 1500.0), boss_bar.max_health);
    try std.testing.expectEqual(@as(f32, 1500.0), boss_bar.display_health);
    try std.testing.expectEqual(@as(f32, 1500.0), boss_bar.damage_lag_health);
}

test "BossBar syncHealthFromStats initializes health fields accurately" {
    var stats = Stats{};
    stats.current.health = 450.0;
    stats.max.health = 600.0;

    var boss_bar = Self{};
    boss_bar.syncHealthFromStats(&stats);

    try std.testing.expectEqual(@as(f32, 450.0), boss_bar.current_health);
    try std.testing.expectEqual(@as(f32, 600.0), boss_bar.max_health);
    try std.testing.expectEqual(@as(f32, 450.0), boss_bar.display_health);
    try std.testing.expectEqual(@as(f32, 450.0), boss_bar.damage_lag_health);
    try std.testing.expectEqual(@as(f32, 0.0), boss_bar.damage_lag_delay_timer_seconds);
}

test "BossBar stepHealthInterpolation activates damage lag timer and catches up" {
    var stats = Stats{};
    stats.current.health = 500.0;
    stats.max.health = 500.0;

    var boss_bar = Self{};
    boss_bar.syncHealthFromStats(&stats);

    stats.current.health = 400.0;
    boss_bar.stepHealthInterpolation(&stats, 0.016);

    try std.testing.expectEqual(@as(f32, 400.0), boss_bar.current_health);
    try std.testing.expect(boss_bar.damage_lag_delay_timer_seconds > 0.0);
    try std.testing.expect(boss_bar.display_health < 500.0);
    try std.testing.expectEqual(@as(f32, 500.0), boss_bar.damage_lag_health);

    boss_bar.stepHealthInterpolation(&stats, 0.1);
    try std.testing.expect(boss_bar.damage_lag_delay_timer_seconds <= 0.0);

    const previous_damage_lag_health = boss_bar.damage_lag_health;
    boss_bar.stepHealthInterpolation(&stats, 0.05);
    try std.testing.expect(boss_bar.damage_lag_health < previous_damage_lag_health);
    try std.testing.expect(boss_bar.damage_lag_health >= boss_bar.display_health);
}

test "BossBar acquireId and releaseId slot reuse" {
    @memset(&id_pool, false);

    const first_ui_id = acquireId();
    try std.testing.expectEqual(@as(u32, 0), first_ui_id);

    const second_ui_id = acquireId();
    try std.testing.expectEqual(@as(u32, 1), second_ui_id);

    releaseId(first_ui_id);

    const reused_ui_id = acquireId();
    try std.testing.expectEqual(@as(u32, 0), reused_ui_id);

    releaseId(second_ui_id);
    releaseId(reused_ui_id);
}
