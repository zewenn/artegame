const std = @import("std");
const lm = @import("loom");

const ui = lm.ui;
const TIMER = 0.1;

const Stats = @import("Stats.zig");
const Self = @This();

transform: ?*lm.Transform = null,
stats: ?*Stats = null,

cooldown: f32 = 0,
direction: ?lm.Vector2 = null,

pub fn apply(self: *Self, direction_vector: lm.Vector2) void {
    const stats = self.stats orelse return;

    if (self.direction != null) return;
    if (stats.current.stamina < 50) return;

    self.direction = direction_vector.normalize();
    self.cooldown = stats.current.dash_time;
    stats.current.stamina -= 50;
}

pub fn is_dashing(self: *Self) bool {
    return self.direction != null;
}

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.transform = try entity.pullComponent(lm.Transform);
    self.stats = try entity.pullComponent(Stats);
}

pub fn Update(self: *Self) !void {
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const stats: *Stats = try lm.ensureComponent(self.stats);

    if (self.cooldown < 0) self.cooldown = 0;
    if (self.cooldown == 0) {
        self.direction = null;
        return;
    }

    self.cooldown -= lm.time.deltaTime();

    const direction_vector = self.direction orelse return;
    const speed = stats.current.movement_speed * stats.current.dash_speed_multiplier;

    transform.position = transform.position.add(lm.vec2ToVec3(
        direction_vector
            .multiply(lm.time.deltaTimeVector2())
            .multiply(lm.Vec2(speed, speed)),
    ));
}

pub fn Tick(self: *Self) !void {
    const stats: *Stats = try lm.ensureComponent(self.stats);

    stats.current.stamina = @min(stats.max.stamina, stats.current.stamina + 1);
}
