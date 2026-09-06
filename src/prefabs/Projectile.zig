const std = @import("std");
const lm = @import("loom");

const Stats = @import("../components/Stats.zig");
const ProjectileMovement = @import("../components/ProjectileMovement.zig");
const Dashing = @import("../components/Dashing.zig");
const SpatialAudio = @import("../global/audio/SpatialAudio.zig");

pub const OnHitEffect = enum { slow, root, stun };

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
            .player => "projectiles/enemy_light_projectile.png",
            else => "projectiles/light_attack_projectile.png",
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

    if (other_stats.team != options.target_team) return;

    if (!options.passtrough) {
        if (options.inactive) return;

        options.inactive = true;
        lm.removeEntity(.{ .uuid = self.uuid });
    } else {
        if (!options.recordHit(other.uuid)) return;
    }

    other_stats.current.health -= options.shooter_stats.calculateDamage(
        other_stats.*,
        options.damage_type,
        options.is_crit,
    ) * options.damage;

    if (other.getComponent(lm.Transform)) |other_t| {
        const hit_pos = lm.vec3ToVec2(other_t.position);
        var listener_pos = hit_pos;
        if (lm.activeScene()) |scene| {
            if (scene.getEntityById("player")) |player| {
                if (player.getComponent(lm.Transform)) |pt| {
                    listener_pos = lm.vec3ToVec2(pt.position);
                }
            }
        }
        if (options.is_crit) {
            SpatialAudio.playSpatialPitched("audio/boom.wav", hit_pos, listener_pos, 700.0, 0.65, 0.15);
        } else {
            SpatialAudio.playSpatialPitched("audio/punch.mp3", hit_pos, listener_pos, 700.0, 0.5, 0.1);
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
}

test "Projectile Options per-target hit tracking" {
    var opts = Options{ .passtrough = true };
    try std.testing.expectEqual(false, opts.hasHit(101));

    // First hit should record successfully
    try std.testing.expect(opts.recordHit(101));
    try std.testing.expect(opts.hasHit(101));

    // Second hit against same target should be rejected
    try std.testing.expectEqual(false, opts.recordHit(101));

    // Different target should record
    try std.testing.expect(opts.recordHit(202));
    try std.testing.expect(opts.hasHit(202));
    try std.testing.expectEqual(2, opts.hit_count);
}

