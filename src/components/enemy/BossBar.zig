const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const Stats = @import("../Stats.zig");
const OverheadUI = @import("OverheadUI.zig");
const HUD = @import("../../global/HUD.zig");
const RoomManager = @import("../../global/RoomManager.zig");
const theme = @import("../../global/ui/theme.zig");
const color_scheme = @import("../../global/ui/color_scheme.zig");

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
    self.render(HUD.ui_scale);
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
            .mini_boss => color_scheme.boss_mini_accent_rgba,
            .boss => color_scheme.boss_main_accent_rgba,
        };
    }
};

const MAX_BOSS_BARS: usize = 16;
var id_pool: [MAX_BOSS_BARS]bool = @splat(false);

const BASE_BAR_WIDTH_PIXELS: f32 = 128.0;
const BASE_BAR_HEIGHT_PIXELS: f32 = 4.0;
const BASE_OVERLAY_WIDTH_PIXELS: f32 = 132.0;
const BASE_OVERLAY_HEIGHT_PIXELS: f32 = 7.0;
const BASE_OVERLAY_OFFSET_X_PIXELS: f32 = -2.0;
const BASE_OVERLAY_OFFSET_Y_PIXELS: f32 = -1.5;

const DAMAGE_LAG_DELAY_SECONDS: f32 = 0.1;
const HEALTH_LERP_RATE_PER_SECOND: f32 = 50.0;
const DAMAGE_LAG_LERP_RATE_PER_SECOND: f32 = 4.0;
const BASE_TOP_OFFSET_PIXELS: f32 = 17.0;
const STACK_VERTICAL_STRIDE_PIXELS: f32 = 13.0;

pub fn shouldRender() bool {
    return !HUD.isModalOpen();
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

pub fn render(self: *const Self, ui_scale: f32) void {
    const total_bar_width_pixels = BASE_BAR_WIDTH_PIXELS * ui_scale;
    const total_bar_height_pixels = BASE_BAR_HEIGHT_PIXELS * ui_scale;
    const container_width_pixels = total_bar_width_pixels + (4.0 * ui_scale);
    const top_offset_pixels = (BASE_TOP_OFFSET_PIXELS * ui_scale) + (@as(f32, @floatFromInt(self.ui_id)) * STACK_VERTICAL_STRIDE_PIXELS * ui_scale);

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
            .child_gap = lm.tou16(@round(1.0 * ui_scale)),
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
            .padding = .axes(0, lm.tou16(@round(0.5 * ui_scale))),
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
    const title_font_size_pixels = lm.tou16(@max(7, @round(3.75 * ui_scale)));

    ui.new(.{
        .id = .IDI("boss-hud-title-container-", self.ui_id),
    })({
        ui.text(self.boss_name, .{
            .color = color_scheme.boss_title_text,
            .font_size = title_font_size_pixels,
            .letter_spacing = 1,
            .font_id = theme.boldFontId(),
        });
    });
}

fn renderRankBadge(self: *const Self, ui_scale: f32) void {
    const rank_font_size_pixels = lm.tou16(@max(5, @round(2.75 * ui_scale)));
    const accent_color = self.rank.getAccentColor();

    ui.new(.{
        .id = .IDI("boss-hud-rank-badge-", self.ui_id),
        .background_color = color_scheme.boss_rank_badge_background,
        .corner_radius = .all(1.0 * ui_scale),
        .border = .{
            .color = color_scheme.fromRgbaWithAlpha(accent_color, 200),
            .width = .outside(1),
        },
        .layout = .{
            .padding = .axes(lm.tou16(@round(0.5 * ui_scale)), lm.tou16(@round(1.5 * ui_scale))),
        },
    })({
        ui.text(self.rank.getTitle(), .{
            .color = color_scheme.fromRgbaWithAlpha(accent_color, 255),
            .font_size = rank_font_size_pixels,
            .letter_spacing = 1,
            .font_id = theme.boldFontId(),
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
        .background_color = color_scheme.boss_trough_background,
        .corner_radius = .all(0.75 * ui_scale),
        .border = .{
            .color = color_scheme.fromRgbaWithAlpha(accent_color, 160),
            .width = .outside(1),
        },
        .layout = .{
            .sizing = .{ .w = .fixed(total_bar_width_pixels), .h = .fixed(total_bar_height_pixels) },
        },
    })({
        self.renderHealthBarFill(
            "boss-health-damage-lag-",
            std.math.clamp(self.damage_lag_health / self.max_health, 0.0, 1.0),
            color_scheme.boss_damage_lag_fill,
            1,
            total_bar_width_pixels,
            total_bar_height_pixels,
            ui_scale,
        );
        self.renderHealthBarFill(
            "boss-health-current-fill-",
            std.math.clamp(self.display_health / self.max_health, 0.0, 1.0),
            color_scheme.boss_health_fill,
            2,
            total_bar_width_pixels,
            total_bar_height_pixels,
            ui_scale,
        );
        self.renderPhaseDividers(total_bar_width_pixels, total_bar_height_pixels, ui_scale);
        self.renderHealthText(total_bar_width_pixels, total_bar_height_pixels, ui_scale);
        self.renderOverlayFrame(ui_scale);
    });
}

fn renderHealthBarFill(
    self: *const Self,
    comptime id_prefix: []const u8,
    fill_ratio: f32,
    fill_color: [4]f32,
    z_index: i16,
    total_bar_width_pixels: f32,
    total_bar_height_pixels: f32,
    ui_scale: f32,
) void {
    ui.new(.{
        .id = .IDI(id_prefix, self.ui_id),
        .floating = .{
            .attach_to = .to_parent,
            .attach_points = .{ .element = .left_top, .parent = .left_top },
            .pointer_capture_mode = .passthrough,
            .z_index = z_index,
        },
        .background_color = fill_color,
        .corner_radius = .all(0.75 * ui_scale),
        .layout = .{
            .sizing = .{ .w = .fixed(total_bar_width_pixels * fill_ratio), .h = .fixed(total_bar_height_pixels) },
        },
    })({});
}

fn renderPhaseDividers(
    self: *const Self,
    total_bar_width_pixels: f32,
    total_bar_height_pixels: f32,
    ui_scale: f32,
) void {
    const divider_width_pixels = @max(1.0, @round(0.25 * ui_scale));
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
            .background_color = color_scheme.boss_phase_divider,
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
    const font_size_pixels = lm.tou16(@max(5, @round(2.5 * ui_scale)));

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
            .color = color_scheme.text_bright,
            .font_size = font_size_pixels,
            .letter_spacing = 1,
            .font_id = theme.regularFontId(),
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

test "BossBar shouldRender suppresses when GameOverMenu, PauseMenu, or BoonMenu is showing" {
    RoomManager.startPracticeTutorial();
    defer {
        HUD.GameOverMenu.hide();
        HUD.PauseMenu.hide();
        HUD.BoonMenu.hide();
        lm.time.proceed();
        RoomManager.endPracticeTutorial();
    }

    HUD.GameOverMenu.hide();
    HUD.PauseMenu.hide();
    HUD.BoonMenu.hide();
    try std.testing.expect(shouldRender());

    HUD.GameOverMenu.show(.{});
    try std.testing.expect(!shouldRender());
    HUD.GameOverMenu.hide();
    try std.testing.expect(shouldRender());

    HUD.PauseMenu.show();
    try std.testing.expect(!shouldRender());
    HUD.PauseMenu.hide();
    try std.testing.expect(shouldRender());

    const dummy_slots = [_]HUD.BoonMenu.BoonSlot{};
    HUD.BoonMenu.show(&dummy_slots);
    try std.testing.expect(!shouldRender());
    HUD.BoonMenu.hide();
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
