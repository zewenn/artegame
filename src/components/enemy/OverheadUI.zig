const std = @import("std");
const lm = @import("loom");

const ui = lm.ui;

const Stats = @import("../Stats.zig");
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
    self.camera = lm.activeScene().?.getCamera("main");
}

pub fn Update(self: *Self) !void {
    const stats: *Stats = try lm.ensureComponent(self.stats);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const camera: *lm.Camera = try lm.ensureComponent(self.camera);

    const screen_pos = camera.worldToScreenPos(lm.vec3ToVec2(transform.position))
        .subtract(.init(32, 64));

    enemy_overhead_ui_count +%= 1;

    ui.new(.{
        .id = .IDI("enemy-status", enemy_overhead_ui_count),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{ .x = screen_pos.x, .y = screen_pos.y },
        },
        .layout = .{
            .sizing = .{ .h = .fit, .w = .fixed(64) },
            .direction = .top_to_bottom,
        },
    })({
        ui.new(.{
            .id = .IDI("enemy-status-effect", enemy_overhead_ui_count),
            .layout = .{
                .sizing = .{ .h = .fit, .w = .percent(1) },
                .child_alignment = .{ .x = .center },
            },
        })({
            if (stats.current.stunned) {
                lm.ui.text("Stunned", .{
                    .letter_spacing = 2,
                });
            } else if (stats.current.rooted) {
                lm.ui.text("Rooted", .{
                    .letter_spacing = 2,
                });
            } else if (stats.current.slow_movement_speed_decrease != 0) {
                lm.ui.text("Slowed", .{
                    .letter_spacing = 2,
                });
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
                    .sizing = .{ .h = .percent(1), .w = .percent(stats.current.health / stats.max.health) },
                },
            })({});
        });
    });
}
