const std = @import("std");
const lm = @import("loom");

const Stats = @import("../components/Stats.zig");
const ProjectileMovement = @import("../components/ProjectileMovement.zig");
const Dashing = @import("../components/Dashing.zig");
const SpatialAudio = @import("../global/audio/SpatialAudio.zig");
const ReactiveAura = @import("../components/enemy/ReactiveAura.zig");
const TrainingDummyBehaviour = @import("../components/enemy/TrainingDummyBehaviour.zig");
const MapTypes = @import("../global/map/MapTypes.zig");
const Wall = MapTypes.Wall;
const ProjectileManager = @import("../global/ProjectileManager.zig");

pub const OnHitEffect = enum { slow, root, stun };

pub const AttackKind = enum {
    light,
    heavy,
    dash,
    spell,
    generic,
};

/// Information passed to projectile hit callbacks.
pub const HitInfo = struct {
    projectile: ?*lm.Entity = null,
    target: *lm.Entity,
    caster_uuid: ?u128 = null,
    damage_dealt: f32 = 0,
    is_crit: bool = false,
    is_healing: bool = false,
    options: *Options,
};

/// Callback signature invoked when a projectile impacts a target entity.
pub const OnHitFn = *const fn (hit: HitInfo) void;

/// Configuration parameters for projectile instantiation and behavior.
pub const Options = struct {
    pub const MAX_HIT_TARGETS: usize = 64;

    attack_kind: AttackKind = .generic,

    start_position: lm.Vector2 = .init(0, 0),
    target_position: lm.Vector2 = .init(1, 0),

    lifetime: f32 = 1,
    speed: f32 = 330,
    size: lm.Vector2 = .init(64, 64),
    passtrough: bool = false,

    is_crit: bool = false,
    shooter_stats: Stats = .{},

    damage_type: Stats.DamageType = .physical,
    damage: f32 = 1,
    target_team: Stats.Teams = .neutral,

    is_healing: bool = false,
    heal_amount: f32 = 0,

    caster_position: ?lm.Vector2 = null,
    caster_uuid: ?u128 = null,

    pull_strength: f32 = 0,
    pull_speed: ?f32 = null,
    pull_duration: f32 = 0,

    on_hit_callback: ?OnHitFn = null,

    inactive: bool = false,
    override_sprite: ?[]const u8 = null,

    onhit_effect: ?OnHitEffect = null,
    onhit_duration: f32 = 0,
    onhit_strength: f32 = 0,

    knockback_strength: f32 = 0,
    knockback_duration: f32 = 0,

    hit_targets: [MAX_HIT_TARGETS]u128 = @splat(0),
    hit_count: usize = 0,

    pub fn hasHit(self: *const Options, target_uuid: u128) bool {
        for (self.hit_targets[0..self.hit_count]) |uuid| {
            if (uuid == target_uuid) return true;
        }
        return false;
    }

    pub fn recordHit(self: *Options, target_uuid: u128) bool {
        if (self.hasHit(target_uuid)) return false;
        if (self.hit_count < MAX_HIT_TARGETS) {
            self.hit_targets[self.hit_count] = target_uuid;
            self.hit_count += 1;
        }
        return true;
    }

    pub fn getProjectileSprite(self: Options) []const u8 {
        return self.override_sprite orelse switch (self.target_team) {
            .player => "projectiles/enemies/light.png",
            else => "projectiles/player/light.png",
        };
    }
};

/// Spawns a projectile into the Structure of Arrays (SoA) ProjectileManager.
pub fn emit(options: Options) !void {
    try ProjectileManager.spawn(options);
}

var projectile_count: u32 = 0;

pub fn Projectile(options: Options) !*lm.Entity {
    defer projectile_count +%= 1;

    return try lm.makeEntityI("projectile", projectile_count, .{
        lm.Transform{
            .rotation = std.math.radiansToDegrees(std.math.atan2(
                options.target_position.y - options.start_position.y,
                options.target_position.x - options.start_position.x,
            )) - 90,
            .scale = options.size,
        },
        lm.Renderer.sprite(options.getProjectileSprite()),
        lm.RectangleCollider.initConfig(.{
            .type = .trigger,
            .transform = .{ .scale = options.size.multiply(lm.Vec2(0.8, 0.8)) },
            .onCollision = onCollisionDealDamage,
        }),

        options,
        Stats{
            .current = .{
                .movement_speed = options.speed,
            },
        },
        ProjectileMovement.init(
            options.start_position,
            options.target_position,
            options.lifetime,
        ),
    });
}

/// Evaluates whether a wall collision blocks and destroys the projectile.
pub fn processWallCollision(options: *Options, wall: Wall) bool {
    if (wall.wall_type.blocksProjectiles()) {
        if (options.inactive) return true;
        options.inactive = true;
        return true;
    }
    return false;
}

fn getPlayerListenerPosition(fallback_position: lm.Vector2) lm.Vector2 {
    const player_entity = lm.getEntity(.{ .id = "player" }) orelse return fallback_position;
    const player_transform = player_entity.getComponent(lm.Transform) orelse return fallback_position;
    return lm.vec3ToVec2(player_transform.position);
}

/// Plays spatial punch audio at the specified projectile impact position.
pub fn playWallHitAudioAtPosition(projectile_position: lm.Vector2) void {
    const listener_position = getPlayerListenerPosition(projectile_position);
    SpatialAudio.playSpatialPitched("audio/sfx/punch.mp3", projectile_position, listener_position, 600.0, 0.3, 0.2);
}

fn playWallHitAudio(projectile_transform: *const lm.Transform) void {
    playWallHitAudioAtPosition(lm.vec3ToVec2(projectile_transform.position));
}

/// Resolves wall collision logic and plays audio if the projectile is destroyed.
pub fn resolveWallCollision(options: *Options, projectile_position: lm.Vector2, wall: Wall) bool {
    const should_destroy = processWallCollision(options, wall);
    if (should_destroy) {
        playWallHitAudioAtPosition(projectile_position);
        return true;
    }
    return false;
}

/// Plays spatial audio for regular or critical hits at the specified position.
pub fn playHitAudioAtPosition(hit_position: lm.Vector2, is_crit: bool) void {
    const listener_position = getPlayerListenerPosition(hit_position);
    if (is_crit) {
        SpatialAudio.playSpatialPitched("audio/sfx/boom.wav", hit_position, listener_position, 700.0, 0.65, 0.15);
    } else {
        SpatialAudio.playSpatialPitched("audio/sfx/punch.mp3", hit_position, listener_position, 700.0, 0.5, 0.1);
    }
}

fn playInvulnerableHitAudioAtPosition(hit_position: lm.Vector2) void {
    const listener_position = getPlayerListenerPosition(hit_position);
    SpatialAudio.playSpatialPitched("audio/sfx/punch.mp3", hit_position, listener_position, 600.0, 0.4, 0.2);
}

fn applyHealingHit(options: *const Options, other: *lm.Entity, other_stats: *Stats) void {
    const heal_amount = if (options.heal_amount > 0) options.heal_amount else options.damage;
    other_stats.current.health = @min(other_stats.max.health, other_stats.current.health + heal_amount);

    const other_transform = other.getComponent(lm.Transform) orelse return;
    const hit_position = lm.vec3ToVec2(other_transform.position);
    const listener_position = getPlayerListenerPosition(hit_position);

    SpatialAudio.playSpatialPitched("audio/sfx/pickup.mp3", hit_position, listener_position, 700.0, 0.5, 0.1);
}

fn applyStatusEffect(options: *const Options, other_stats: *Stats) void {
    const onhit_effect = options.onhit_effect orelse return;
    switch (onhit_effect) {
        .slow => other_stats.applySlow(options.onhit_strength, options.onhit_duration),
        .root => other_stats.applyRoot(options.onhit_duration),
        .stun => other_stats.applyStun(options.onhit_duration),
    }
}

fn applyKnockback(
    options: *const Options,
    projectile_position: lm.Vector2,
    other: *lm.Entity,
) void {
    if (options.knockback_strength == 0 or options.knockback_duration == 0) return;

    const other_dashing = other.getComponent(Dashing) orelse return;
    const other_transform = other.getComponent(lm.Transform) orelse return;
    const other_position = lm.vec3ToVec2(other_transform.position);

    const to_target_vector = projectile_position.subtract(other_position);
    if (to_target_vector.length() < 0.001) return;

    const knockback_direction = to_target_vector.normalize().negate();
    const knockback_velocity = knockback_direction.multiply(
        .init(options.knockback_strength, options.knockback_strength),
    );

    other_dashing.applyEx(
        knockback_velocity,
        options.knockback_duration,
        false,
    );
}

fn resolveCasterPosition(options: *const Options) lm.Vector2 {
    const caster_uuid = options.caster_uuid orelse return options.caster_position orelse options.start_position;
    const caster_entity = lm.getEntity(.{ .uuid = caster_uuid }) orelse return options.caster_position orelse options.start_position;
    const caster_transform = caster_entity.getComponent(lm.Transform) orelse return options.caster_position orelse options.start_position;
    return lm.vec3ToVec2(caster_transform.position);
}

fn calculatePullStrength(options: *const Options, other_stats: *const Stats) f32 {
    const target_pull_speed = options.pull_speed orelse return options.pull_strength;
    const base_dash_speed = other_stats.current.movement_speed * other_stats.current.dash_speed_multiplier;
    if (base_dash_speed > 0) {
        return target_pull_speed / base_dash_speed;
    }
    return 1.0;
}

fn applyPull(
    options: *const Options,
    other: *lm.Entity,
    other_stats: *const Stats,
) void {
    if (options.pull_duration == 0) return;
    const has_pull_speed = options.pull_speed != null and options.pull_speed.? > 0;
    if (options.pull_strength == 0 and !has_pull_speed) return;

    const other_dashing = other.getComponent(Dashing) orelse return;
    const other_transform = other.getComponent(lm.Transform) orelse return;
    const other_position = lm.vec3ToVec2(other_transform.position);

    const target_position = resolveCasterPosition(options);
    const to_caster_vector = target_position.subtract(other_position);
    if (to_caster_vector.length() < 0.001) return;

    const pull_direction = to_caster_vector.normalize();
    const effective_strength = calculatePullStrength(options, other_stats);

    other_dashing.applyEx(
        pull_direction.multiply(.init(effective_strength, effective_strength)),
        options.pull_duration,
        false,
    );
}

/// Resolves combat effects, damage, callbacks, audio, and displacement when impacting an entity.
pub fn resolveEntityHit(options: *Options, projectile_position: lm.Vector2, other: *lm.Entity) void {
    const other_stats = other.getComponent(Stats) orelse return;
    if (other_stats.team != options.target_team) return;

    if (!options.passtrough) {
        if (options.inactive) return;
        options.inactive = true;
    } else {
        if (!options.recordHit(other.uuid)) return;
    }

    if (other_stats.isInvulnerable()) {
        if (other.getComponent(lm.Transform)) |other_transform| {
            playInvulnerableHitAudioAtPosition(lm.vec3ToVec2(other_transform.position));
        }
        return;
    }

    if (options.is_healing) {
        applyHealingHit(options, other, other_stats);
        return;
    }

    const damage_dealt = options.shooter_stats.calculateDamage(
        other_stats.*,
        options.damage_type,
        options.is_crit,
    ) * options.damage;
    other_stats.current.health -= damage_dealt;

    if (options.on_hit_callback) |callback| {
        callback(.{
            .projectile = null,
            .target = other,
            .caster_uuid = options.caster_uuid,
            .damage_dealt = damage_dealt,
            .is_crit = options.is_crit,
            .is_healing = options.is_healing,
            .options = options,
        });
    }

    if (other.getComponent(ReactiveAura)) |reactive_aura| {
        if (lm.getEntity(.{ .id = "player" })) |player_entity| {
            reactive_aura.onHitByAttacker(other, player_entity, damage_dealt);
        }
    }

    if (other.getComponent(lm.Transform)) |other_transform| {
        const hit_position = lm.vec3ToVec2(other_transform.position);

        if (other.getComponent(TrainingDummyBehaviour)) |dummy| {
            dummy.onHit(options.attack_kind, damage_dealt, hit_position);
        }

        playHitAudioAtPosition(hit_position, options.is_crit);
    }

    applyStatusEffect(options, other_stats);
    applyKnockback(options, projectile_position, other);
    applyPull(options, other, other_stats);
}

fn onCollisionDealDamage(self: *lm.Entity, other: *lm.Entity) !void {
    const options = try self.pullComponent(Options);
    const transform = self.getComponent(lm.Transform);
    const projectile_position = if (transform) |target_transform|
        lm.vec3ToVec2(target_transform.position)
    else
        options.start_position;

    if (other.getComponent(Wall)) |wall| {
        if (resolveWallCollision(options, projectile_position, wall.*)) {
            lm.removeEntity(.{ .uuid = self.uuid });
        }
        return;
    }

    const was_inactive = options.inactive;
    resolveEntityHit(options, projectile_position, other);
    if (!was_inactive and options.inactive) {
        lm.removeEntity(.{ .uuid = self.uuid });
    }
}

test "Projectile Options per-target hit tracking" {
    var options = Options{ .passtrough = true };
    try std.testing.expectEqual(false, options.hasHit(101));

    try std.testing.expect(options.recordHit(101));
    try std.testing.expect(options.hasHit(101));

    try std.testing.expectEqual(false, options.recordHit(101));

    try std.testing.expect(options.recordHit(202));
    try std.testing.expect(options.hasHit(202));
    try std.testing.expectEqual(2, options.hit_count);
}

test "Projectile processWallCollision destroys solid walls and ignores low walls" {
    var projectile_options = Options{};

    const low_wall = Wall{ .wall_type = .low };
    const low_result = processWallCollision(&projectile_options, low_wall);
    try std.testing.expectEqual(false, low_result);
    try std.testing.expectEqual(false, projectile_options.inactive);

    const solid_wall = Wall{ .wall_type = .solid };
    const solid_result = processWallCollision(&projectile_options, solid_wall);
    try std.testing.expectEqual(true, solid_result);
    try std.testing.expectEqual(true, projectile_options.inactive);

    var royale_options = Options{};
    const royale_wall = Wall{ .wall_type = .royale };
    const royale_result = processWallCollision(&royale_options, royale_wall);
    try std.testing.expectEqual(true, royale_result);
    try std.testing.expectEqual(true, royale_options.inactive);
}

test "Projectile resolveWallCollision destroys solid walls and marks inactive" {
    var projectile_options = Options{};
    const wall = Wall{ .wall_type = .solid };
    const hit_result = resolveWallCollision(&projectile_options, .init(0, 0), wall);
    try std.testing.expectEqual(true, hit_result);
    try std.testing.expectEqual(true, projectile_options.inactive);
}
