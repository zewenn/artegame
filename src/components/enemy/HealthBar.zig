const std = @import("std");
const lm = @import("loom");

const ui = lm.ui;

const Stats = @import("../Stats.zig");
const Self = @This();

var healthbar_count: u32 = 0;

stats: ?*Stats = null,
transform: ?*lm.Transform = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
}

pub fn Update(self: *Self) !void {
    const stats: *Stats = try lm.ensureComponent(self.stats);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);

    const screen_pos = lm.worldToScreenPos(lm.vec3ToVec2(transform.position))
        .subtract(.init(32, 64))
        ;

    healthbar_count +%= 1;

    ui.new(.{
        .id = .IDI("enemy-healthbar", healthbar_count),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{ .x = screen_pos.x, .y = screen_pos.y },
        },
        .background_color = ui.color(20, 20, 20, 255),
        .layout = .{
            .sizing = .{ .h = .fixed(16), .w = .fixed(64) },
        },
    })({
        ui.new(.{
            .id = .IDI("enemy-healthbar-inner", healthbar_count),
            .background_color = ui.color(255, 20, 20, 255),
            .layout = .{
                .sizing = .{ .h = .percent(1), .w = .percent(stats.current.health / stats.max.health) },
            },
        })({});
    });
}
