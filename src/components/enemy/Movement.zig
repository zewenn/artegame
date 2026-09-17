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
preferred_range_min_pixels: f32 = 250,
preferred_range_max_pixels: f32 = 450,
strafe_direction: f32 = 1.0,
strafe_timer_seconds: f32 = 0,

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
dashing: ?*Dashing = null,
attack: ?*Attack = null,
player_transform: ?*lm.Transform = null,

direction: lm.Vector2 = lm.Vec2(0, 0),
wander_cooldown_seconds: f32 = 0,
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
    const scene = lm.activeScene() orelse return;
    const player = scene.getEntityById("player") orelse return;
    self.player_transform = player.getComponent(lm.Transform);
}

pub fn Update(self: *Self) !void {
    if (lm.time.paused()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);
    const dashing: *Dashing = try lm.ensureComponent(self.dashing);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const player_transform: *lm.Transform = try lm.ensureComponent(self.player_transform);

    if (self.attack) |attack| {
        if (attack.isActing()) {
            self.move_vector = .init(0, 0);
            return;
        }
    }

    if (dashing.isDashing() or !stats.canMove()) {
        self.move_vector = .init(0, 0);
        return;
    }

    const enemy_position = lm.vec3ToVec2(transform.position);
    const player_position = lm.vec3ToVec2(player_transform.position);
    const distance_pixels = std.math.hypot(
        enemy_position.x - player_position.x,
        enemy_position.y - player_position.y,
    );

    const delta_seconds = lm.time.deltaTime();

    if (distance_pixels > stats.current.aggro_range) {
        self.updateWandering(distance_pixels, stats.current.aggro_range, delta_seconds);
    } else {
        self.updateCombatMovement(distance_pixels, enemy_position, player_position, stats, delta_seconds);
    }

    const effective_speed = stats.current.calculateMovementSpeed();
    transform.position = transform.position.add(lm.vec2ToVec3(
        self.move_vector
            .multiply(lm.time.deltaTimeVector2())
            .multiply(.init(effective_speed, effective_speed)),
    ));
}

fn updateWandering(self: *Self, distance_pixels: f32, aggro_range: f32, delta_seconds: f32) void {
    if (self.wander_cooldown_seconds <= 0) {
        self.direction = lm.Vec2(
            lm.random.intRangeAtMost(isize, -100, 100),
            lm.random.intRangeAtMost(isize, -100, 100),
        );
        self.wander_cooldown_seconds = lm.randFloat(f32, 2, 4);
    }
    self.wander_cooldown_seconds -= delta_seconds;

    if (self.wander_cooldown_seconds < 1 or distance_pixels > aggro_range * 4) {
        self.move_vector = .init(0, 0);
        return;
    }

    self.move_vector = self.direction.normalize().multiply(lm.Vec2(0.25, 0.25));
}

fn updateCombatMovement(
    self: *Self,
    distance_pixels: f32,
    enemy_position: lm.Vector2,
    player_position: lm.Vector2,
    stats: *const Stats,
    delta_seconds: f32,
) void {
    switch (self.style) {
        .pursue => {
            self.move_vector = if (distance_pixels > 60)
                player_position.subtract(enemy_position).normalize()
            else
                .init(0, 0);
        },
        .kite_strafe => {
            self.move_vector = self.calculateKiteStrafeVector(distance_pixels, enemy_position, player_position, delta_seconds, 1.8, 3.2);
        },
        .hybrid => {
            const has_haste = stats.hasEffect(.{ .effect_type = .haste });
            if (has_haste or distance_pixels < 80) {
                self.move_vector = player_position.subtract(enemy_position).normalize();
                return;
            }
            self.move_vector = self.calculateKiteStrafeVector(distance_pixels, enemy_position, player_position, delta_seconds, 1.5, 2.8);
        },
    }
}

fn calculateKiteStrafeVector(
    self: *Self,
    distance_pixels: f32,
    enemy_position: lm.Vector2,
    player_position: lm.Vector2,
    delta_seconds: f32,
    min_strafe_time_seconds: f32,
    max_strafe_time_seconds: f32,
) lm.Vector2 {
    self.strafe_timer_seconds -= delta_seconds;
    if (self.strafe_timer_seconds <= 0) {
        self.strafe_timer_seconds = lm.randFloat(f32, min_strafe_time_seconds, max_strafe_time_seconds);
        self.strafe_direction = -self.strafe_direction;
    }

    if (distance_pixels < self.preferred_range_min_pixels) {
        return enemy_position.subtract(player_position).normalize();
    }
    if (distance_pixels > self.preferred_range_max_pixels) {
        return player_position.subtract(enemy_position).normalize();
    }

    const to_player = player_position.subtract(enemy_position).normalize();
    const perpendicular = lm.Vec2(-to_player.y, to_player.x);
    return perpendicular.multiply(.init(self.strafe_direction, self.strafe_direction)).normalize();
}

pub fn Tick(self: *Self) !void {
    const stats: *Stats = try lm.ensureComponent(self.stats);
    if (!stats.canMove()) return;

    const dashing: *Dashing = try lm.ensureComponent(self.dashing);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const player_transform: *lm.Transform = try lm.ensureComponent(self.player_transform);

    if (dashing.isDashing()) return;

    const enemy_position = lm.vec3ToVec2(transform.position);
    const player_position = lm.vec3ToVec2(player_transform.position);
    const distance_pixels = std.math.hypot(
        enemy_position.x - player_position.x,
        enemy_position.y - player_position.y,
    );

    if (distance_pixels > stats.current.aggro_range) return;

    switch (self.style) {
        .pursue => {
            if (distance_pixels >= 120 and distance_pixels <= 220 and lm.random.intRangeAtMost(u8, 1, 25) == 1) {
                dashing.apply(player_position.subtract(enemy_position).normalize());
            }
        },
        .kite_strafe => {
            if (distance_pixels < 110 and lm.random.intRangeAtMost(u8, 1, 15) == 1) {
                dashing.apply(enemy_position.subtract(player_position).normalize());
            }
        },
        .hybrid => {
            if (lm.random.intRangeAtMost(u8, 1, 20) != 1) return;
            if (distance_pixels < 100) {
                dashing.apply(enemy_position.subtract(player_position).normalize());
            } else if (distance_pixels >= 140 and distance_pixels <= 240) {
                dashing.apply(player_position.subtract(enemy_position).normalize());
            }
        },
    }
}
