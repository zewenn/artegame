const std = @import("std");
const lm = @import("loom");

const ui = lm.ui;

const Stats = @import("../Stats.zig");
const EffectVisualRegistry = @import("../effects/EffectVisual.zig").EffectVisualRegistry;
const Self = @This();

var enemy_overhead_ui_count: u32 = 0;

stats: ?*Stats = null,
transform: ?*lm.Transform = null,

camera: ?*lm.Camera = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
}

pub fn Start(self: *Self) void {
    self.camera = lm.activeScene().?.getCameraById("main");
}

pub fn Update(self: *Self) !void {
    const stats: *Stats = try lm.ensureComponent(self.stats);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const camera: *lm.Camera = try lm.ensureComponent(self.camera);

    const screen_pos = camera.worldToScreenPos(lm.vec3ToVec2(transform.position))
        .subtract(.init(0, 48));

    enemy_overhead_ui_count +%= 1;

    ui.new(.{
        .id = .IDI("enemy-status", enemy_overhead_ui_count),
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
            .id = .IDI("enemy-status-badges", enemy_overhead_ui_count),
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
                    .id = .IDI("status-badge-", (enemy_overhead_ui_count * 16) + @as(u32, @intCast(badge_index))),
                    .image = ui.image(icon_path, .init(14, 14)) catch .{ .image_data = null },
                    .layout = .{
                        .sizing = .{ .w = .fixed(14), .h = .fixed(14) },
                    },
                })({});
            }
        });

        ui.new(.{
            .id = .IDI("enemy-healthbar", enemy_overhead_ui_count),
            .background_color = ui.color(20, 20, 20, 255),
            .layout = .{
                .sizing = .{ .h = .fixed(8), .w = .fixed(64) },
            },
        })({
            ui.new(.{
                .id = .IDI("enemy-healthbar-inner", enemy_overhead_ui_count),
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
