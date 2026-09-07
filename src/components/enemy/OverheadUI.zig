const std = @import("std");
const lm = @import("loom");

const ui = lm.ui;

const Stats = @import("../Stats.zig");
const EffectVisualRegistry = @import("../effects/EffectVisual.zig").EffectVisualRegistry;
const GameOverMenu = @import("../../global/ui/GameOverMenu.zig");
const PauseMenu = @import("../../global/ui/PauseMenu.zig");

const Self = @This();

var id_pool: [128]bool = [_]bool{false} ** 128;

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
camera: ?*lm.Camera = null,
ui_id: u32 = 0,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.ui_id = acquireId();
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
}

pub fn Start(self: *Self) void {
    self.camera = lm.activeScene().?.getCameraById("main");
}

pub fn shouldRender() bool {
    if (GameOverMenu.isShowing()) return false;
    if (PauseMenu.isShowing()) return false;
    return true;
}

pub fn Update(self: *Self) !void {
    if (!shouldRender()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const camera: *lm.Camera = try lm.ensureComponent(self.camera);

    const screen_pos = camera.worldToScreenPos(lm.vec3ToVec2(transform.position))
        .subtract(.init(0, 48));

    ui.new(.{
        .id = .IDI("enemy-status-", self.ui_id),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{ .x = screen_pos.x, .y = screen_pos.y },
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
        ui.new(.{
            .id = .IDI("enemy-status-badges-", self.ui_id),
            .layout = .{
                .sizing = .{ .h = .fit, .w = .fit },
                .direction = .left_to_right,
                .child_alignment = .{ .x = .center },
                .child_gap = 2,
            },
        })(badges: {
            const effects = stats.effects orelse break :badges;

            for (effects.items(), 0..) |effect, badge_index| {
                const visual = EffectVisualRegistry.resolve(effect) orelse continue;
                const icon_path = visual.icon orelse continue;

                ui.new(.{
                    .id = .IDI("status-badge-", (self.ui_id * 16) + @as(u32, @intCast(badge_index))),
                    .image = ui.image(icon_path, .init(14, 14)) catch .{ .image_data = null },
                    .layout = .{
                        .sizing = .{ .w = .fixed(14), .h = .fixed(14) },
                    },
                })({});
            }
        });

        ui.new(.{
            .id = .IDI("enemy-healthbar-", self.ui_id),
            .background_color = ui.color(20, 20, 20, 255),
            .layout = .{
                .sizing = .{ .h = .fixed(8), .w = .fixed(64) },
            },
        })({
            ui.new(.{
                .id = .IDI("enemy-healthbar-inner-", self.ui_id),
                .background_color = ui.color(255, 20, 20, 255),
                .layout = .{
                    .sizing = .{
                        .h = .percent(1),
                        .w = .percent(stats.current.health / stats.max.health),
                    },
                },
            })({});
        });
    });
}

pub fn End(self: *Self) void {
    releaseId(self.ui_id);
}

fn acquireId() u32 {
    for (&id_pool, 0..) |*in_use, i| {
        if (!in_use.*) {
            in_use.* = true;
            return @intCast(i);
        }
    }
    return 0;
}

fn releaseId(id: u32) void {
    if (id < id_pool.len) {
        id_pool[id] = false;
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
