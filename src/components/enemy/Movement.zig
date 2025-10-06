const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Dashing = @import("../Dashing.zig");

const Self = @This();

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
dashing: ?*Dashing = null,
player_transform: ?*lm.Transform = null,

direction: lm.Vector2 = lm.Vec2(0, 0),
cooldown: f32 = 0,

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
    if (lm.time.paused()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);
    const dashing: *Dashing = try lm.ensureComponent(self.dashing);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const player_transform: *lm.Transform = try lm.ensureComponent(self.player_transform);

    if (dashing.is_dashing() or !stats.canMove()) return;

    const distance = std.math.hypot(
        transform.position.x - player_transform.position.x,
        transform.position.y - player_transform.position.y,
    );

    var move_vector: lm.Vector2 = switch (distance > stats.current.aggro_range) {
        true => blk: {
            if (self.cooldown <= 0) {
                self.direction = lm.Vec2(
                    lm.random.intRangeAtMost(isize, -100, 100),
                    lm.random.intRangeAtMost(isize, -100, 100),
                );
                self.cooldown = lm.randFloat(f32, 2, 4);
            }
            self.cooldown -= lm.time.deltaTime();

            if (self.cooldown < 1 or distance > stats.current.aggro_range * 4) break :blk .init(0, 0);

            break :blk self.direction
                .normalize()
                .multiply(lm.Vec2(0.25, 0.25));
        },
        false => lm.vec3ToVec2(player_transform.position)
            .subtract(lm.vec3ToVec2(transform.position))
            .normalize(),
    };

    transform.position = transform.position.add(lm.vec2ToVec3(
        move_vector
            .multiply(lm.time.deltaTimeVector2())
            .multiply(.init(stats.current.movement_speed, stats.current.movement_speed)),
    ));
}

pub fn Tick(self: *Self) !void {
    const stats: *Stats = try lm.ensureComponent(self.stats);

    if (!stats.canMove()) return;

    const dashing: *Dashing = try lm.ensureComponent(self.dashing);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const player_transform: *lm.Transform = try lm.ensureComponent(self.player_transform);

    const distance = std.math.hypot(
        transform.position.x - player_transform.position.x,
        transform.position.y - player_transform.position.y,
    );

    if (dashing.is_dashing() or distance > stats.current.aggro_range) return;

    if (lm.random.intRangeAtMost(u8, 1, 30) == 1) {
        dashing.apply(
            lm.vec3ToVec2(player_transform.position)
                .subtract(lm.vec3ToVec2(transform.position))
                .normalize(),
        );
        return;
    }
}
