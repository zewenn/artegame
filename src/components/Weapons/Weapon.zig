const std = @import("std");
const lm = @import("loom");

const projectiles = @import("../../prefabs/Projectile.zig");
const ProjectileOptions = projectiles.Options;
const Projectile = projectiles.Projectile;

const Stats = @import("../Stats.zig");

const Attack = struct {
    shooting_degrees: []const f32 = &.{0},
    projectile_options: ProjectileOptions = .{},
};

pub const WeaponType = enum {
    close,
    wide,
};

const Self = @This();

id: []const u8,

light_attack: Attack = .{},
heavy_attack: Attack = .{},
dash_attack: Attack = .{},

sprite_left: []const u8 = "empty_icon.png",
sprite_right: []const u8 = "empty_icon.png",

type: WeaponType = .close,

pub fn doAttack(attack: Attack, position: lm.Vector2, target: lm.Vector2, shooter_stats: Stats) !void {
    const angle = std.math.atan2(
        target.y - position.y,
        target.x - position.x,
    );

    for (attack.shooting_degrees) |degree_offset| {
        const new_angle = std.math.degreesToRadians(degree_offset) + angle;
        const target_vector = lm.Vec2(1, 0).rotate(new_angle);

        const options = attack.projectile_options;

        try lm.summon(&.{.{
            .entity = try Projectile(.{
                .start_position = position,
                .target_position = target_vector.add(position),

                .target_team = switch (shooter_stats.team) {
                    .enemy => .player,
                    else => .enemy,
                },

                .shooter_stats = shooter_stats,

                .speed = options.speed,

                .damage_multiplier = options.damage_multiplier,
                .damage_type = options.damage_type,
                .passtrough = options.passtrough,
                .lifetime = options.lifetime,
                .size = options.size,
                .override_sprite = options.override_sprite,

                .onhit_effect = options.onhit_effect,
                .onhit_duration = options.onhit_duration,
                .onhit_strength = options.onhit_strength,
            }),
        }});
    }
}

pub fn lightAttack(self: *Self, position: lm.Vector2, target: lm.Vector2, shooter_stats: Stats) !void {
    try doAttack(self.light_attack, position, target, shooter_stats);
}

pub fn heavyAttack(self: *Self, position: lm.Vector2, target: lm.Vector2, shooter_stats: Stats) !void {
    try doAttack(self.heavy_attack, position, target, shooter_stats);
}

pub fn dashAttack(self: *Self, position: lm.Vector2, target: lm.Vector2, shooter_stats: Stats) !void {
    try doAttack(self.dash_attack, position, target, shooter_stats);
}
