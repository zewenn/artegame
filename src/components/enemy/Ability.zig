const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Effect = @import("../effects/Effect.zig");
const Dashing = @import("../Dashing.zig");
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");
const projectiles = @import("../../prefabs/Projectile.zig");
const ProjectileOptions = projectiles.Options;
const Projectile = projectiles.Projectile;

pub const OnHitEffect = projectiles.OnHitEffect;

pub const ExecutionType = enum {
    projectile,
    spell,
    mobility,
};

pub const AimMode = enum {
    towards_player,
    absolute_world,
};

pub const AbilityCondition = struct {
    health_below_pct: ?f32 = null,
    health_above_pct: ?f32 = null,
    target_has_effect: ?Stats.EffectTarget = null,
    target_lacks_effect: ?Stats.EffectTarget = null,
    self_has_effect: ?Stats.EffectTarget = null,
    self_lacks_effect: ?Stats.EffectTarget = null,
    random_chance: ?f32 = null,
};

pub const ProjectileProfile = struct {
    sprite: ?[]const u8 = null,
    damage: f32 = 10,
    damage_type: Stats.DamageType = .physical,
    speed: f32 = 350,
    lifetime: f32 = 1.0,
    size: lm.Vector2 = .init(48, 48),
    passtrough: bool = false,
    is_crit: bool = false,
    onhit_effect: ?OnHitEffect = null,
    onhit_duration: f32 = 0,
    onhit_strength: f32 = 0,
    knockback_strength: f32 = 0,
    knockback_duration: f32 = 0,
    spread_angles: []const f32 = &.{0},
    sfx_path: ?[]const u8 = null,

    aim_mode: AimMode = .towards_player,
    base_angle: f32 = 0,

    target_team: Stats.Teams = .player,
    is_healing: bool = false,
    heal_amount: f32 = 0,

    pull_strength: f32 = 0,
    pull_speed: ?f32 = null,
    pull_duration: f32 = 0,

    on_hit_callback: ?projectiles.OnHitFn = null,

    wave_count: u32 = 1,
    wave_interval: f32 = 0.15,
    wave_angle_offset: f32 = 0,

    is_channeled: bool = false,
    channel_duration: f32 = 5.0,
    channel_fire_interval: f32 = 0.05,
    channel_rotation_speed: f32 = 72.0,
    initial_angle: f32 = 0,
};

pub const SpellProfile = struct {
    target_type: enum { self, target } = .self,
    effect: ?Effect = null,
    sfx_path: ?[]const u8 = null,
};

pub const MobilityProfile = struct {
    direction: enum { towards_target, away_from_target } = .towards_target,
    sfx_path: ?[]const u8 = null,
};

const Self = @This();
pub const Ability = Self;

id: []const u8,
execution_type: ExecutionType = .projectile,
min_range: f32 = 0,
max_range: f32 = std.math.floatMax(f32),
cooldown: f32 = 1.0,
cooldown_remaining: f32 = 0,
conditions: AbilityCondition = .{},

projectile_profile: ?ProjectileProfile = null,
spell_profile: ?SpellProfile = null,
mobility_profile: ?MobilityProfile = null,

windup_animation: ?[]const u8 = null,
release_animation: ?[]const u8 = null,
winddown_animation: ?[]const u8 = null,
root_movement_during_action: bool = true,

pub fn updateCooldown(self: *Self, dt: f32) void {
    if (self.cooldown_remaining > 0) {
        self.cooldown_remaining = @max(0, self.cooldown_remaining - dt);
    }
}

pub fn canExecute(
    self: *const Self,
    enemy_stats: Stats,
    player_stats: ?Stats,
    distance: f32,
) bool {
    if (self.cooldown_remaining > 0) return false;
    if (distance < self.min_range or distance > self.max_range) return false;

    const enemy_hp_pct = switch (enemy_stats.max.health > 0) {
        true => enemy_stats.current.health / enemy_stats.max.health,
        false => 0,
    };

    if (self.conditions.health_below_pct) |threshold|
        if (enemy_hp_pct > threshold) return false;

    if (self.conditions.health_above_pct) |threshold|
        if (enemy_hp_pct < threshold) return false;

    if (self.conditions.self_has_effect) |eff|
        if (!enemy_stats.hasEffect(eff)) return false;

    if (self.conditions.self_lacks_effect) |eff|
        if (enemy_stats.hasEffect(eff)) return false;

    has_or_lacks_effect: {
        const stats = player_stats orelse break :has_or_lacks_effect;
        if (self.conditions.target_has_effect) |effect| return stats.hasEffect(effect);
        if (self.conditions.target_lacks_effect) |effect| return !stats.hasEffect(effect);
    }

    if (self.conditions.random_chance) |chance| {
        if (lm.randFloat(f32, 0, 1) > chance) return false;
    }

    return true;
}

pub fn fireProjectileWave(
    self: *const Self,
    enemy_entity: *lm.Entity,
    enemy_transform: *lm.Transform,
    enemy_stats: *Stats,
    player_transform: *lm.Transform,
    player_stats: ?*Stats,
    wave_index: u32,
    angle_override_deg: ?f32,
) !void {
    _ = player_stats;
    const profile = self.projectile_profile orelse return;
    const start_pos = lm.vec3ToVec2(enemy_transform.position);
    const player_pos = lm.vec3ToVec2(player_transform.position);

    const base_angle_rad: f32 = if (angle_override_deg) |override_deg|
        std.math.degreesToRadians(override_deg)
    else switch (profile.aim_mode) {
        .towards_player => std.math.atan2(player_pos.y - start_pos.y, player_pos.x - start_pos.x),
        .absolute_world => std.math.degreesToRadians(profile.base_angle),
    };

    const wave_offset_rad = std.math.degreesToRadians(profile.wave_angle_offset * @as(f32, @floatFromInt(wave_index)));

    for (profile.spread_angles) |degree_offset| {
        const angle = base_angle_rad + wave_offset_rad + std.math.degreesToRadians(degree_offset);
        const target_dir = lm.Vec2(std.math.cos(angle), std.math.sin(angle));
        const target_pos = start_pos.add(target_dir.multiply(.init(100, 100)));

        try lm.summoning.entity(try Projectile(.{
            .start_position = start_pos,
            .target_position = target_pos,
            .shooter_stats = enemy_stats.*,
            .is_crit = profile.is_crit or (lm.randFloat(f32, 0, 1) <= enemy_stats.current.crit_chance),
            .target_team = profile.target_team,
            .is_healing = profile.is_healing,
            .heal_amount = profile.heal_amount,
            .speed = profile.speed,
            .lifetime = profile.lifetime,
            .size = profile.size,
            .damage = profile.damage,
            .damage_type = profile.damage_type,
            .passtrough = profile.passtrough,
            .override_sprite = profile.sprite,
            .onhit_effect = profile.onhit_effect,
            .onhit_duration = profile.onhit_duration,
            .onhit_strength = profile.onhit_strength,
            .knockback_strength = profile.knockback_strength,
            .knockback_duration = profile.knockback_duration,
            .pull_strength = profile.pull_strength,
            .pull_speed = profile.pull_speed,
            .pull_duration = profile.pull_duration,
            .caster_position = start_pos,
            .caster_uuid = enemy_entity.uuid,
            .on_hit_callback = profile.on_hit_callback,
        }));
    }

    if (profile.sfx_path) |sfx| {
        SpatialAudio.playSpatialPitched(sfx, start_pos, player_pos, 700.0, 0.45, 0.1);
    }
}

pub fn execute(
    self: *const Self,
    enemy_entity: *lm.Entity,
    enemy_transform: *lm.Transform,
    enemy_stats: *Stats,
    player_transform: *lm.Transform,
    player_stats: ?*Stats,
) !void {
    const start_pos = lm.vec3ToVec2(enemy_transform.position);
    const player_pos = lm.vec3ToVec2(player_transform.position);

    switch (self.execution_type) {
        .projectile => {
            try self.fireProjectileWave(
                enemy_entity,
                enemy_transform,
                enemy_stats,
                player_transform,
                player_stats,
                0,
                null,
            );
        },
        .spell => {
            const profile = self.spell_profile orelse return;

            switch (profile.target_type) {
                .self => self: {
                    const effect = profile.effect orelse break :self;
                    enemy_stats.addEffect(effect);
                },
                .target => player: {
                    const stats = player_stats orelse break :player;
                    const effect = profile.effect orelse break :player;

                    stats.addEffect(effect);
                },
            }

            if (profile.sfx_path) |sfx| {
                SpatialAudio.playSpatialPitched(sfx, start_pos, player_pos, 700.0, 0.55, 0.1);
            }
        },
        .mobility => {
            const profile = self.mobility_profile orelse MobilityProfile{};
            if (enemy_entity.getComponent(Dashing)) |dashing| {
                var dash_dir = player_pos.subtract(start_pos).normalize();
                if (profile.direction == .away_from_target) {
                    dash_dir = dash_dir.negate();
                }
                dashing.apply(dash_dir);
            }

            if (profile.sfx_path) |sfx| {
                SpatialAudio.playSpatialPitched(sfx, start_pos, player_pos, 700.0, 0.5, 0.1);
            }
        },
    }
}

test "Ability range and cooldown condition checks" {
    var ability = Self{
        .id = "test_shot",
        .min_range = 100,
        .max_range = 400,
        .cooldown = 2.0,
        .cooldown_remaining = 0,
    };

    const enemy_stats = Stats{
        .max = .{ .health = 100 },
        .current = .{ .health = 100 },
    };

    try std.testing.expect(ability.canExecute(enemy_stats, null, 250));

    try std.testing.expect(!ability.canExecute(enemy_stats, null, 50));

    try std.testing.expect(!ability.canExecute(enemy_stats, null, 500));

    ability.cooldown_remaining = 1.5;
    try std.testing.expect(!ability.canExecute(enemy_stats, null, 250));

    ability.updateCooldown(1.0);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), ability.cooldown_remaining, 0.001);
    try std.testing.expect(!ability.canExecute(enemy_stats, null, 250));

    ability.updateCooldown(1.0);
    try std.testing.expectEqual(@as(f32, 0), ability.cooldown_remaining);
    try std.testing.expect(ability.canExecute(enemy_stats, null, 250));
}

test "Ability health percentage conditions" {
    const ability_low_hp = Self{
        .id = "enrage",
        .cooldown = 5.0,
        .conditions = .{
            .health_below_pct = 0.5,
        },
    };

    var enemy_stats = Stats{
        .max = .{ .health = 100 },
        .current = .{ .health = 80 },
    };

    try std.testing.expect(!ability_low_hp.canExecute(enemy_stats, null, 100));

    enemy_stats.current.health = 40;
    try std.testing.expect(ability_low_hp.canExecute(enemy_stats, null, 100));
}

test "Ability target effect conditions (target_has_effect, target_lacks_effect)" {
    const sniper = Self{
        .id = "sniper",
        .conditions = .{
            .target_has_effect = .{ .effect_type = .root },
        },
    };

    const trap = Self{
        .id = "trap",
        .conditions = .{
            .target_lacks_effect = .{ .effect_type = .root },
        },
    };

    const enemy_stats = Stats{ .max = .{ .health = 100 }, .current = .{ .health = 100 } };
    var player_stats = Stats.init(.player, .{});
    defer player_stats.deinit();

    try std.testing.expect(!sniper.canExecute(enemy_stats, player_stats, 200));
    try std.testing.expect(trap.canExecute(enemy_stats, player_stats, 200));

    player_stats.applyRoot(2.0);

    try std.testing.expect(sniper.canExecute(enemy_stats, player_stats, 200));
    try std.testing.expect(!trap.canExecute(enemy_stats, player_stats, 200));
}

test "Ability absolute_world cardinal angle calculation" {
    const angler_profile = ProjectileProfile{
        .aim_mode = .absolute_world,
        .base_angle = 0,
        .spread_angles = &.{ 0, 90, -90, 180 },
    };

    const base_rad = std.math.degreesToRadians(angler_profile.base_angle);

    // 0 deg -> (1, 0)
    const angle_0 = base_rad + std.math.degreesToRadians(angler_profile.spread_angles[0]);
    try std.testing.expectApproxEqAbs(@as(f32, 1), std.math.cos(angle_0), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), std.math.sin(angle_0), 0.001);

    // 90 deg -> (0, 1)
    const angle_90 = base_rad + std.math.degreesToRadians(angler_profile.spread_angles[1]);
    try std.testing.expectApproxEqAbs(@as(f32, 0), std.math.cos(angle_90), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1), std.math.sin(angle_90), 0.001);

    // -90 deg -> (0, -1)
    const angle_neg90 = base_rad + std.math.degreesToRadians(angler_profile.spread_angles[2]);
    try std.testing.expectApproxEqAbs(@as(f32, 0), std.math.cos(angle_neg90), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, -1), std.math.sin(angle_neg90), 0.001);

    // 180 deg -> (-1, 0)
    const angle_180 = base_rad + std.math.degreesToRadians(angler_profile.spread_angles[3]);
    try std.testing.expectApproxEqAbs(@as(f32, -1), std.math.cos(angle_180), 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0), std.math.sin(angle_180), 0.001);
}

test "Ability ProjectileProfile multi-wave and channeled options defaults" {
    const prof = ProjectileProfile{};
    try std.testing.expectEqual(AimMode.towards_player, prof.aim_mode);
    try std.testing.expectEqual(@as(f32, 0), prof.base_angle);
    try std.testing.expectEqual(@as(u32, 1), prof.wave_count);
    try std.testing.expectEqual(@as(f32, 0.15), prof.wave_interval);
    try std.testing.expectEqual(@as(f32, 0), prof.wave_angle_offset);
    try std.testing.expectEqual(false, prof.is_channeled);
    try std.testing.expectEqual(@as(f32, 5.0), prof.channel_duration);
    try std.testing.expectEqual(@as(f32, 0.05), prof.channel_fire_interval);
    try std.testing.expectEqual(@as(f32, 72.0), prof.channel_rotation_speed);
}

