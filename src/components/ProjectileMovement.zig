const std = @import("std");
const lm = @import("loom");

const Stats = @import("Stats.zig");
const Self = @This();

transform: ?*lm.Transform = null,
stats: ?*Stats = null,

lifetime: f32 = 1,
direction_vector: lm.Vector2 = .init(1, 0),

start_position: lm.Vector2 = .init(0, 0),

pub fn init(current_position: lm.Vector2, target_position: lm.Vector2, lifetime: f32) Self {
    return Self{
        .direction_vector = target_position
            .subtract(current_position)
            .normalize(),
        .lifetime = lifetime,
        .start_position = current_position,
    };
}

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.transform = try entity.pullComponent(lm.Transform);
    self.stats = try entity.pullComponent(Stats);

    self.transform.?.position = lm.vec2ToVec3(self.start_position);
}

pub fn Update(self: *Self, entity: *lm.Entity) !void {
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const stats: *Stats = try lm.ensureComponent(self.stats);

    if (self.lifetime > 0) {
        self.lifetime -= lm.time.deltaTime();
    } else {
        lm.removeEntity(.{ .uuid = entity.uuid });
    }

    transform.position = transform.position.add(lm.vec2ToVec3(
        self.direction_vector
            .multiply(lm.time.deltaTimeVector2())
            .multiply(lm.Vec2(stats.current.movement_speed, stats.current.movement_speed)),
    ));
}
