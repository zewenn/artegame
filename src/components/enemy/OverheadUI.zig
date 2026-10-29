const std = @import("std");
const lm = @import("loom");

const ui = lm.ui;

const Stats = @import("../Stats.zig");
const Effect = @import("../effects/Effect.zig");
const EffectType = Effect.EffectType;
const EffectVisualRegistry = @import("../effects/EffectVisual.zig").EffectVisualRegistry;
const GameOverMenu = @import("../../global/ui/GameOverMenu.zig");
const PauseMenu = @import("../../global/ui/PauseMenu.zig");

const Self = @This();

const MAX_STATUS_BADGES: usize = 8;

var id_pool: [256]bool = @splat(false);

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
camera: ?*lm.Camera = null,
ui_id: u32 = 0,

show_health_bar: bool = true,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.ui_id = acquireId();
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
}

pub fn Start(self: *Self) void {
    self.camera = lm.activeScene().?.getCameraById("main");
}

pub fn Update(self: *Self) !void {
    if (!shouldRender()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const camera: *lm.Camera = try lm.ensureComponent(self.camera);

    const has_effects = if (stats.effects) |effects| effects.items().len > 0 else false;
    if (!self.show_health_bar and !has_effects) return;

    const screen_position = camera.worldToScreenPos(lm.vec3ToVec2(transform.position))
        .subtract(.init(0, 48));

    ui.new(.{
        .id = .IDI("enemy-status-", self.ui_id),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{ .x = screen_position.x, .y = screen_position.y },
            .attach_points = .{
                .element = .center_bottom,
                .parent = .left_top,
            },
        },
        .layout = .{
            .sizing = .{ .h = .fit, .w = .fixed(64) },
            .direction = .top_to_bottom,
            .child_gap = 8,
        },
    })({
        renderStatusBadges(self.ui_id, stats);
        if (self.show_health_bar) {
            renderHealthBar(self.ui_id, stats);
        }
    });
}

pub fn End(self: *Self) void {
    releaseId(self.ui_id);
}

pub fn shouldRender() bool {
    if (GameOverMenu.isShowing()) return false;
    if (PauseMenu.isShowing()) return false;
    return true;
}

fn renderStatusBadges(ui_id: u32, stats: *Stats) void {
    const effects = stats.effects orelse return;
    if (effects.items().len == 0) return;

    var icon_buffer: [MAX_STATUS_BADGES][]const u8 = undefined;
    const badge_count = collectUniqueBadgeIcons(effects.items(), &icon_buffer);
    if (badge_count == 0) return;

    ui.new(.{
        .id = .IDI("enemy-status-badges-", ui_id),
        .layout = .{
            .sizing = .{ .h = .fit, .w = .fit },
            .direction = .left_to_right,
            .child_alignment = .{ .x = .center },
            .child_gap = 2,
        },
    })({
        for (icon_buffer[0..badge_count], 0..) |icon_path, badge_index| {
            renderSingleBadge(ui_id, icon_path, badge_index);
        }
    });
}

fn renderSingleBadge(ui_id: u32, icon_path: []const u8, badge_index: usize) void {
    ui.new(.{
        .id = .IDI("status-badge-", (ui_id * 16) + @as(u32, @intCast(badge_index))),
        .image = ui.image(icon_path, .init(14, 14)) catch .{ .image_data = null },
        .layout = .{
            .sizing = .{ .w = .fixed(14), .h = .fixed(14) },
        },
    })({});
}

fn collectUniqueBadgeIcons(effects: []const Effect, icon_buffer: *[MAX_STATUS_BADGES][]const u8) usize {
    var rendered_effect_types: std.EnumSet(EffectType) = .empty;
    var collected_count: usize = 0;

    for (effects) |effect| {
        if (collected_count >= MAX_STATUS_BADGES) break;
        if (effect.effect_type != .custom and rendered_effect_types.contains(effect.effect_type)) continue;

        const visual = EffectVisualRegistry.resolve(effect) orelse continue;
        const icon_path = visual.icon orelse continue;

        rendered_effect_types.insert(effect.effect_type);
        icon_buffer[collected_count] = icon_path;
        collected_count += 1;
    }

    return collected_count;
}

fn renderHealthBar(ui_id: u32, stats: *Stats) void {
    ui.new(.{
        .id = .IDI("enemy-healthbar-", ui_id),
        .background_color = ui.color(20, 20, 20, 255),
        .layout = .{
            .sizing = .{ .h = .fixed(8), .w = .fixed(64) },
        },
    })({
        ui.new(.{
            .id = .IDI("enemy-healthbar-inner-", ui_id),
            .background_color = ui.color(255, 20, 20, 255),
            .layout = .{
                .sizing = .{
                    .h = .percent(1),
                    .w = .percent(stats.current.health / stats.max.health),
                },
            },
        })({});
    });
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

test "OverheadUI shouldRender suppresses when GameOverMenu or PauseMenu is showing" {
    GameOverMenu.hide();
    PauseMenu.hide();
    try std.testing.expect(shouldRender());

    GameOverMenu.show(.{});
    try std.testing.expect(!shouldRender());
    GameOverMenu.hide();
    try std.testing.expect(shouldRender());

    PauseMenu.show();
    try std.testing.expect(!shouldRender());
    PauseMenu.hide();
    try std.testing.expect(shouldRender());
}

test "OverheadUI collectUniqueBadgeIcons deduplicates effects by EffectType" {
    const effects = [_]Effect{
        .{ .id = "slow_1", .effect_type = .slow },
        .{ .id = "slow_2", .effect_type = .slow },
        .{ .id = "root_1", .effect_type = .root },
        .{ .id = "stun_1", .effect_type = .stun },
        .{ .id = "stun_2", .effect_type = .stun },
    };

    var icon_buffer: [MAX_STATUS_BADGES][]const u8 = undefined;
    const collected_count = collectUniqueBadgeIcons(&effects, &icon_buffer);

    try std.testing.expectEqual(@as(usize, 3), collected_count);
    try std.testing.expectEqualStrings("ui/icons/slow_icon.png", icon_buffer[0]);
    try std.testing.expectEqualStrings("ui/icons/root_icon.png", icon_buffer[1]);
    try std.testing.expectEqualStrings("ui/icons/stun_icon.png", icon_buffer[2]);
}

test "OverheadUI collectUniqueBadgeIcons respects buffer capacity limit" {
    const effects = [_]Effect{
        .{ .id = "slow", .effect_type = .slow },
        .{ .id = "root", .effect_type = .root },
        .{ .id = "stun", .effect_type = .stun },
        .{ .id = "sleep", .effect_type = .sleep },
        .{ .id = "regen", .effect_type = .regen },
        .{ .id = "haste", .effect_type = .haste },
        .{ .id = "goliath", .effect_type = .goliath },
        .{ .id = "stasis", .effect_type = .stasis },
        .{ .id = "bond_of_life", .effect_type = .bond_of_life },
    };

    var icon_buffer: [MAX_STATUS_BADGES][]const u8 = undefined;
    const collected_count = collectUniqueBadgeIcons(&effects, &icon_buffer);

    try std.testing.expectEqual(MAX_STATUS_BADGES, collected_count);
}
