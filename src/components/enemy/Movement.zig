const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Dashing = @import("../Dashing.zig");

const Self = @This();

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
dashing: ?*Dashing = null,
player_transform: ?*lm.Transform = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
    self.dashing = try entity.pullComponent(Dashing);
}

pub fn Start(self: *Self) !void {
    if (lm.eventloop.active_scene.?.getEntityById("player")) |player| {
        self.player_transform = player.getComponent(lm.Transform);
    }
}

pub fn Update(self: *Self) !void {
    const stats: *Stats = try lm.ensureComponent(self.stats);
    const dashing: *Dashing = try lm.ensureComponent(self.dashing);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const player_transform: *lm.Transform = try lm.ensureComponent(self.player_transform);

    if (dashing.is_dashing()) return;

    var move_vector = lm.vec3ToVec2(player_transform.position)
        .subtract(lm.vec3ToVec2(transform.position))
        .normalize();

    transform.position = transform.position.add(lm.vec2ToVec3(
        move_vector
            .normalize()
            .multiply(lm.time.deltaTimeVector2())
            .multiply(.init(stats.current.movement_speed, stats.current.movement_speed)),
    ));
}

pub fn Tick(self: *Self) !void {
    const dashing: *Dashing = try lm.ensureComponent(self.dashing);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const player_transform: *lm.Transform = try lm.ensureComponent(self.player_transform);

    if (dashing.is_dashing()) return;

    if (lm.random.intRangeAtMost(u8, 1, 10) == 1) {
        dashing.apply(
            lm.vec3ToVec2(player_transform.position)
                .subtract(lm.vec3ToVec2(transform.position))
                .normalize(),
        );
        return;
    }
}
