const std = @import("std");
const lm = @import("loom");

const Stats = @import("Stats.zig");
const Dashing = @import("Dashing.zig");

const Self = @This();

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
dashing: ?*Dashing = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
    self.dashing = try entity.pullComponent(Dashing);
}

pub fn Update(self: *Self) !void {
    if (lm.time.paused()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);
    const dashing: *Dashing = try lm.ensureComponent(self.dashing);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);

    if (dashing.is_dashing()) return;

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

    if (lm.input.getKeyDown(.space)) {
        dashing.apply(move_vector);
        return;
    }

    transform.position = transform.position.add(lm.vec2ToVec3(
        move_vector
            .normalize()
            .multiply(lm.time.deltaTimeVector2())
            .multiply(.init(stats.current.movement_speed, stats.current.movement_speed)),
    ));
}
