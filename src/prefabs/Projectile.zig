const std = @import("std");
const lm = @import("loom");

const Stats = @import("../components/Stats.zig");
const ProjectileMovement = @import("../components/ProjectileMovement.zig");

const Options = struct {
    start_position: lm.Vector2 = .init(0, 0),
    target_position: lm.Vector2 = .init(1, 0),

    lifetime: f32 = 1,
    speed: f32 = 330,
    size: lm.Vector2 = .init(64, 64),
    passtrough: bool = false,

    is_crit: bool = false,
    shooter_stats: Stats = .{},

    damage_type: Stats.DamageType = .physical,
    damage_multiplier: f32 = 1,
    target_team: Stats.Teams = .neutral,

    inactive: bool = false,
    override_sprite: ?[]const u8 = null,

    pub fn getProjectileSprite(self: Options) []const u8 {
        return self.override_sprite orelse switch (self.target_team) {
            .player => "enemy_light_projectile.png",
            else => "light_attack_projectile.png",
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
            .onCollidion = onCollisionDealDamage,
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
    }

    other_stats.current.health -= options.shooter_stats.calculateDamage(
        other_stats.*,
        options.damage_type,
        options.is_crit,
    ) * if (options.passtrough) lm.time.deltaTime() else 1 * options.damage_multiplier;
}
