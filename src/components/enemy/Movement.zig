const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Dashing = @import("../Dashing.zig");
const Attack = @import("Attack.zig");

const Self = @This();

pub const MovementStyle = enum {
    pursue,
    kite_strafe,
    hybrid,
};

style: MovementStyle = .pursue,
preferred_range_min: f32 = 250,
preferred_range_max: f32 = 450,
strafe_direction: f32 = 1.0,
strafe_timer: f32 = 0,

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
dashing: ?*Dashing = null,
attack: ?*Attack = null,
player_transform: ?*lm.Transform = null,

direction: lm.Vector2 = lm.Vec2(0, 0),
cooldown: f32 = 0,
move_vector: lm.Vector2 = lm.Vec2(0, 0),

pub fn init(style: MovementStyle) Self {
    return Self{
        .style = style,
    };
}

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
    self.dashing = try entity.pullComponent(Dashing);
    self.attack = entity.getComponent(Attack);
}

pub fn Start(self: *Self) !void {
    if (lm.activeScene()) |scene| {
        if (scene.getEntityById("player")) |player| {
            self.player_transform = player.getComponent(lm.Transform);
        }
    }
}

pub fn Update(self: *Self) !void {
    if (lm.time.paused()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);
    const dashing: *Dashing = try lm.ensureComponent(self.dashing);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const player_transform: *lm.Transform = try lm.ensureComponent(self.player_transform);

    if (self.attack) |attack| attack: {
        if (!attack.isActing()) break :attack;

        self.move_vector = .init(0, 0);
        return;
    }

    if (dashing.isDashing() or !stats.canMove()) {
        self.move_vector = .init(0, 0);
        return;
    }

    const enemy_pos = lm.vec3ToVec2(transform.position);
    const player_pos = lm.vec3ToVec2(player_transform.position);
    const distance = std.math.hypot(
        enemy_pos.x - player_pos.x,
        enemy_pos.y - player_pos.y,
    );

    const dt = lm.time.deltaTime();

    if (distance > stats.current.aggro_range) {
        if (self.cooldown <= 0) {
            self.direction = lm.Vec2(
                lm.random.intRangeAtMost(isize, -100, 100),
                lm.random.intRangeAtMost(isize, -100, 100),
            );
            self.cooldown = lm.randFloat(f32, 2, 4);
        }
        self.cooldown -= dt;

        if (self.cooldown < 1 or distance > stats.current.aggro_range * 4) {
            self.move_vector = .init(0, 0);
            return;
        }

        self.move_vector = self.direction.normalize().multiply(lm.Vec2(0.25, 0.25));
    } else switch (self.style) {
        .pursue => self.move_vector = switch (distance > 60) {
            true => player_pos.subtract(enemy_pos).normalize(),
            false => .init(0, 0),
        },
        .kite_strafe => kite: {
            self.strafe_timer -= dt;
            if (self.strafe_timer <= 0) {
                self.strafe_timer = lm.randFloat(f32, 1.8, 3.2);
                self.strafe_direction = -self.strafe_direction;
            }

            if (distance < self.preferred_range_min) {
                self.move_vector = enemy_pos.subtract(player_pos).normalize();
                break :kite;
            }
            if (distance > self.preferred_range_max) {
                self.move_vector = player_pos.subtract(enemy_pos).normalize();
                break :kite;
            }

            const to_player = player_pos.subtract(enemy_pos).normalize();
            const perp = lm.Vec2(-to_player.y, to_player.x);
            self.move_vector = perp.multiply(.init(self.strafe_direction, self.strafe_direction)).normalize();
        },
        .hybrid => hybrid: {
            const has_haste = stats.hasEffect(.{ .effect_type = .haste });
            if (has_haste or distance < 80) {
                self.move_vector = player_pos.subtract(enemy_pos).normalize();
                break :hybrid;
            }

            self.strafe_timer -= dt;
            if (self.strafe_timer <= 0) {
                self.strafe_timer = lm.randFloat(f32, 1.5, 2.8);
                self.strafe_direction = -self.strafe_direction;
            }

            if (distance < self.preferred_range_min) {
                self.move_vector = enemy_pos.subtract(player_pos).normalize();
                break :hybrid;
            }
            if (distance > self.preferred_range_max) {
                self.move_vector = player_pos.subtract(enemy_pos).normalize();
                break :hybrid;
            }

            const to_player = player_pos.subtract(enemy_pos).normalize();
            const perp = lm.Vec2(-to_player.y, to_player.x);
            self.move_vector = perp.multiply(.init(self.strafe_direction, self.strafe_direction)).normalize();
        },
    }

    const effective_speed = stats.current.calculateMovementSpeed();
    transform.position = transform.position.add(lm.vec2ToVec3(
        self.move_vector
            .multiply(lm.time.deltaTimeVector2())
            .multiply(.init(effective_speed, effective_speed)),
    ));
}

pub fn Tick(self: *Self) !void {
    const stats: *Stats = try lm.ensureComponent(self.stats);

    if (!stats.canMove()) return;

    const dashing: *Dashing = try lm.ensureComponent(self.dashing);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const player_transform: *lm.Transform = try lm.ensureComponent(self.player_transform);

    if (dashing.isDashing()) return;

    const enemy_pos = lm.vec3ToVec2(transform.position);
    const player_pos = lm.vec3ToVec2(player_transform.position);
    const distance = std.math.hypot(
        enemy_pos.x - player_pos.x,
        enemy_pos.y - player_pos.y,
    );

    if (distance > stats.current.aggro_range) return;

    switch (self.style) {
        .pursue => {
            if (distance >= 120 and
                distance <= 220 and
                lm.random.intRangeAtMost(u8, 1, 25) == 1)
            {
                dashing.apply(player_pos.subtract(enemy_pos).normalize());
            }
        },
        .kite_strafe => {
            if (distance < 110 and lm.random.intRangeAtMost(u8, 1, 15) == 1) {
                dashing.apply(enemy_pos.subtract(player_pos).normalize());
            }
        },
        .hybrid => hybrid: {
            if (lm.random.intRangeAtMost(u8, 1, 20) != 1) break :hybrid;

            if (distance < 100) {
                dashing.apply(enemy_pos.subtract(player_pos).normalize());
            } else if (distance >= 140 and distance <= 240) {
                dashing.apply(player_pos.subtract(enemy_pos).normalize());
            }
        },
    }
}
