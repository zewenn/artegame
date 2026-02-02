const std = @import("std");
const lm = @import("loom");

const ui = lm.ui;
const TIMER = 0.1;

const Stats = @import("Stats.zig");
const Self = @This();

const Dash = struct {
    direction: lm.Vector2,
    cooldown: f32,

    pub fn init(direction: lm.Vector2, cooldown: f32) Dash {
        return Dash{
            .direction = direction,
            .cooldown = cooldown,
        };
    }
};

transform: ?*lm.Transform = null,
stats: ?*Stats = null,

dashes: ?lm.List(Dash) = null,

pub fn apply(self: *Self, direction_vector: lm.Vector2) void {
    const stats = self.stats orelse return;

    if (self.isDashing()) return;
    if (stats.current.stamina < 50) return;

    const dashes = &(self.dashes orelse return);
    dashes.append(.init(direction_vector, stats.current.dash_time)) catch return;
    stats.current.stamina -= 50;
}

pub fn applyEx(self: *Self, direction_vector: lm.Vector2, cooldown: f32, reduce_stamina: bool) void {
    const stats = self.stats orelse return;
    const dashes = &(self.dashes orelse return);

    dashes.append(.init(direction_vector, cooldown)) catch return;
    if (reduce_stamina) stats.current.stamina -= 50;
}

pub inline fn isDashing(self: *Self) bool {
    const dashes = &(self.dashes orelse return false);
    return dashes.len() > 0;
}

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.dashes = .init(lm.allocators.scene());
    self.transform = try entity.pullComponent(lm.Transform);
    self.stats = try entity.pullComponent(Stats);
}

pub fn Update(self: *Self) !void {
    if (lm.time.paused()) return;

    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const stats: *Stats = try lm.ensureComponent(self.stats);

    const dashes = &(self.dashes orelse return);

    const len = dashes.len();
    if (len == 0) return;

    for (1..len + 1) |j| {
        const index = len - j;
        const dash: *Dash = &dashes.items()[index];

        if (dash.cooldown < 0) dash.cooldown = 0;
        if (dash.cooldown == 0) {
            _ = dashes.swapRemove(index);
            continue;
        }

        dash.cooldown -= lm.time.deltaTime();

        const direction_vector = dash.direction;
        const speed = stats.current.movement_speed * stats.current.dash_speed_multiplier;

        transform.position = transform.position.add(lm.vec2ToVec3(
            direction_vector
                .multiply(lm.time.deltaTimeVector2())
                .multiply(lm.Vec2(speed, speed)),
        ));
    }
}

pub fn Tick(self: *Self) !void {
    const stats: *Stats = try lm.ensureComponent(self.stats);

    stats.current.stamina = @min(stats.max.stamina, stats.current.stamina + 1);
}

pub fn End(self: *Self) void {
    if (self.dashes) |*dashes| dashes.deinit();
    self.dashes = null;
}
