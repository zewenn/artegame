const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");

const projectiles = @import("../../prefabs/Projectile.zig");
const ProjectileOptions = projectiles.Options;
const Projectile = projectiles.Projectile;

const Self = @This();

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
player_transform: ?*lm.Transform = null,

projectile_options: ProjectileOptions = .{},

direction: lm.Vector2 = lm.Vec2(0, 0),
cooldown: f32 = 0,

pub fn init(projectile_options: ProjectileOptions) Self {
    return Self{
        .projectile_options = projectile_options,
    };
}

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
}

pub fn Start(self: *Self) !void {
    if (lm.eventloop.active_scene.?.getEntityById("player")) |player| {
        self.player_transform = player.getComponent(lm.Transform);
    }
}

pub fn Update(self: *Self) !void {
    const stats: *Stats = try lm.ensureComponent(self.stats);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const player_transform: *lm.Transform = try lm.ensureComponent(self.player_transform);

    self.cooldown -= lm.time.deltaTime();
    if (self.cooldown < 0) self.cooldown = 0;
    if (self.cooldown != 0) return;

    self.cooldown = 1 / stats.current.attack_speed;


    const distance = std.math.hypot(
        transform.position.x - player_transform.position.x,
        transform.position.y - player_transform.position.y,
    );

    if (distance > stats.current.aggro_range * 1.25) return;

    try lm.summon(&.{.{
        .entity = try Projectile(.{
            .start_position = lm.vec3ToVec2(transform.position),
            .target_position = lm.vec3ToVec2(player_transform.position),
            .shooter_stats = stats.*,
            .is_crit = lm.randFloat(f32, 0, 1) <= stats.current.crit_chance,
            .target_team = .player,

            .speed = stats.current.movement_speed * 3,
            .damage_multiplier = self.projectile_options.damage_multiplier,
            .damage_type = self.projectile_options.damage_type,
            .passtrough = self.projectile_options.passtrough,
            .lifetime = self.projectile_options.lifetime,
            .size = self.projectile_options.size,
        }),
    }});
}
