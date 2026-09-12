const std = @import("std");
const lm = @import("loom");

const Stats = @import("../components/Stats.zig");
const ProjectileMovement = @import("../components/ProjectileMovement.zig");
const Dashing = @import("../components/Dashing.zig");
const SpatialAudio = @import("../global/audio/SpatialAudio.zig");
const ReactiveAura = @import("../components/enemy/ReactiveAura.zig");

pub const OnHitEffect = enum { slow, root, stun };

pub const HitInfo = struct {
    projectile: *lm.Entity,
    target: *lm.Entity,
    caster_uuid: ?u128 = null,
    damage_dealt: f32 = 0,
    is_crit: bool = false,
    is_healing: bool = false,
    options: *Options,
};

pub const OnHitFn = *const fn (hit: HitInfo) void;

pub const Options = struct {
    pub const MAX_HIT_TARGETS: usize = 64;

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

    hit_targets: [MAX_HIT_TARGETS]u128 = [_]u128{0} ** MAX_HIT_TARGETS,
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

fn onCollisionDealDamage(self: *lm.Entity, other: *lm.Entity) !void {
    const other_stats = other.getComponent(Stats) orelse return;
    const options = try self.pullComponent(Options);

    const player = lm.getEntity(.{ .id = "player" }) orelse return;

    if (other_stats.team != options.target_team) return;

    if (!options.passtrough) {
        if (options.inactive) return;

        options.inactive = true;
        lm.removeEntity(.{ .uuid = self.uuid });
    } else {
        if (!options.recordHit(other.uuid)) return;
    }

    if (other_stats.isInvulnerable()) {
        if (other.getComponent(lm.Transform)) |other_transform| {
            const hit_position = lm.vec3ToVec2(other_transform.position);
            var listener_position = hit_position;
            if (player.getComponent(lm.Transform)) |player_transform| {
                listener_position = lm.vec3ToVec2(player_transform.position);
            }
            SpatialAudio.playSpatialPitched("audio/sfx/punch.mp3", hit_position, listener_position, 600.0, 0.4, 0.2);
        }
        return;
    }

    var damage_dealt: f32 = 0;

    if (options.on_hit_callback) |callback| {
        callback(.{
            .projectile = self,
            .target = other,
            .caster_uuid = options.caster_uuid,
            .damage_dealt = damage_dealt,
            .is_crit = options.is_crit,
            .is_healing = options.is_healing,
            .options = options,
        });
    }

    if (options.is_healing) healing: {
        const heal_value = if (options.heal_amount > 0) options.heal_amount else options.damage;
        other_stats.current.health = @min(other_stats.max.health, other_stats.current.health + heal_value);

        const other_transform = other.getComponent(lm.Transform) orelse break :healing;

        const hit_position = lm.vec3ToVec2(other_transform.position);
        var listener_position = hit_position;

        if (player.getComponent(lm.Transform)) |player_transform| {
            listener_position = lm.vec3ToVec2(player_transform.position);
        }

        SpatialAudio.playSpatialPitched("audio/sfx/pickup.mp3", hit_position, listener_position, 700.0, 0.5, 0.1);

        return;
    }

    damage_dealt = options.shooter_stats.calculateDamage(
        other_stats.*,
        options.damage_type,
        options.is_crit,
    ) * options.damage;
    other_stats.current.health -= damage_dealt;

    if (other.getComponent(ReactiveAura)) |reactive_aura| {
        reactive_aura.onHitByAttacker(other, player, damage_dealt);
    }

    if (other.getComponent(lm.Transform)) |other_transform| {
        const hit_position = lm.vec3ToVec2(other_transform.position);
        var listener_position = hit_position;

        if (player.getComponent(lm.Transform)) |player_transform| {
            listener_position = lm.vec3ToVec2(player_transform.position);
        }

        if (options.is_crit) {
            SpatialAudio.playSpatialPitched("audio/sfx/boom.wav", hit_position, listener_position, 700.0, 0.65, 0.15);
        } else {
            SpatialAudio.playSpatialPitched("audio/sfx/punch.mp3", hit_position, listener_position, 700.0, 0.5, 0.1);
        }
    }

    if (options.onhit_effect) |onhit_effect| switch (onhit_effect) {
        .slow => other_stats.applySlow(options.onhit_strength, options.onhit_duration),
        .root => other_stats.applyRoot(options.onhit_duration),
        .stun => other_stats.applyStun(options.onhit_duration),
    };

    if (other.getComponent(Dashing)) |other_dashing| knockback: {
        if (options.knockback_strength == 0 or options.knockback_duration == 0) break :knockback;
        const transform = self.getComponent(lm.Transform) orelse break :knockback;
        const other_transform = other.getComponent(lm.Transform) orelse break :knockback;

        other_dashing.applyEx(
            lm.vec3ToVec2(transform.position)
                .subtract(lm.vec3ToVec2(other_transform.position))
                .normalize()
                .negate()
                .multiply(.init(options.knockback_strength, options.knockback_strength)),
            options.knockback_duration,
            false,
        );
    }

    if (other.getComponent(Dashing)) |other_dashing| pull: {
        if (options.pull_duration == 0) break :pull;
        if (options.pull_strength == 0 and (options.pull_speed == null or options.pull_speed.? <= 0)) break :pull;

        const other_transform = other.getComponent(lm.Transform) orelse break :pull;
        const other_position = lm.vec3ToVec2(other_transform.position);

        var caster_position: ?lm.Vector2 = options.caster_position;
        if (options.caster_uuid) |caster_uuid| {
            if (lm.getEntity(.{ .uuid = caster_uuid })) |caster_entity| {
                if (caster_entity.getComponent(lm.Transform)) |caster_transform| {
                    caster_position = lm.vec3ToVec2(caster_transform.position);
                }
            }
        }

        const target_position = caster_position orelse options.start_position;
        const to_caster_vector = target_position.subtract(other_position);
        if (to_caster_vector.length() < 0.001) break :pull;
        const pull_direction = to_caster_vector.normalize();

        const effective_strength = if (options.pull_speed) |target_pull_speed| effective: {
            const base_dash_speed = other_stats.current.movement_speed * other_stats.current.dash_speed_multiplier;
            break :effective if (base_dash_speed > 0) target_pull_speed / base_dash_speed else 1.0;
        } else options.pull_strength;

        other_dashing.applyEx(
            pull_direction.multiply(.init(effective_strength, effective_strength)),
            options.pull_duration,
            false,
        );
    }
}

test "Projectile Options per-target hit tracking" {
    var opts = Options{ .passtrough = true };
    try std.testing.expectEqual(false, opts.hasHit(101));

    try std.testing.expect(opts.recordHit(101));
    try std.testing.expect(opts.hasHit(101));

    try std.testing.expectEqual(false, opts.recordHit(101));

    try std.testing.expect(opts.recordHit(202));
    try std.testing.expect(opts.hasHit(202));
    try std.testing.expectEqual(2, opts.hit_count);
}

test "Projectile healing and pull options defaults" {
    const opts = Options{};
    try std.testing.expectEqual(false, opts.is_healing);
    try std.testing.expectEqual(@as(f32, 0), opts.heal_amount);
    try std.testing.expectEqual(@as(f32, 0), opts.pull_strength);
    try std.testing.expectEqual(@as(?f32, null), opts.pull_speed);
    try std.testing.expectEqual(@as(f32, 0), opts.pull_duration);
    try std.testing.expect(opts.on_hit_callback == null);
}

test "Projectile HitInfo callback invocation" {
    const Context = struct {
        var called: bool = false;
        var recorded_dmg: f32 = 0;
        var recorded_caster: ?u128 = null;

        fn onHit(hit: HitInfo) void {
            called = true;
            recorded_dmg = hit.damage_dealt;
            recorded_caster = hit.caster_uuid;
        }
    };

    var opts = Options{
        .caster_uuid = 987654,
        .on_hit_callback = Context.onHit,
    };

    var dummy_proj = lm.Entity.init(std.testing.allocator, "proj");
    defer dummy_proj.prepared_components.deinit();
    defer dummy_proj.components.deinit();

    var dummy_target = lm.Entity.init(std.testing.allocator, "target");
    defer dummy_target.prepared_components.deinit();
    defer dummy_target.components.deinit();

    if (opts.on_hit_callback) |cb| {
        cb(.{
            .projectile = &dummy_proj,
            .target = &dummy_target,
            .caster_uuid = opts.caster_uuid,
            .damage_dealt = 42.5,
            .is_crit = false,
            .is_healing = false,
            .options = &opts,
        });
    }

    try std.testing.expect(Context.called);
    try std.testing.expectEqual(@as(f32, 42.5), Context.recorded_dmg);
    try std.testing.expectEqual(@as(?u128, 987654), Context.recorded_caster);
}

test "Projectile healing mode restores HP up to max" {
    var target_stats = Stats{
        .team = .enemy,
        .max = .{ .health = 100 },
        .current = .{ .health = 50 },
    };

    const heal_opts = Options{
        .target_team = .enemy,
        .is_healing = true,
        .heal_amount = 30,
    };

    const heal_val = if (heal_opts.heal_amount > 0) heal_opts.heal_amount else heal_opts.damage;
    target_stats.current.health = @min(target_stats.max.health, target_stats.current.health + heal_val);

    try std.testing.expectEqual(@as(f32, 80), target_stats.current.health);

    target_stats.current.health = @min(target_stats.max.health, target_stats.current.health + 50);
    try std.testing.expectEqual(@as(f32, 100), target_stats.current.health);
}
