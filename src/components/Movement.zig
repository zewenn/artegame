const std = @import("std");
const lm = @import("loom");

const Stats = @import("Stats.zig");

const Self = @This();

stats: ?*Stats = null,
transform: ?*lm.Transform = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
}

pub fn Update(self: *Self) !void {
    const stats: *Stats = try lm.ensureComponent(self.stats);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);

    var move_vector = lm.Vec2(0, 0);

    if (lm.input.getKey(.w)) {
        move_vector.y -= 1;
    }
    if (lm.input.getKey(.s)) {
        move_vector.y += 1;
    }
    if (lm.input.getKey(.a)) {
        move_vector.x -= 1;
    }
    if (lm.input.getKey(.d)) {
        move_vector.x += 1;
    }

    transform.position = transform.position.add(lm.vec2ToVec3(
        move_vector
            .normalize()
            .multiply(lm.time.deltaTimeVector2())
            .multiply(.init(stats.current.movement_speed, stats.current.movement_speed)),
    ));
}
