const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const StatusOverlays = @import("../../components/effects/StatusOverlays.zig");
const Dashing = @import("../../components/Dashing.zig");
const Enemy = @import("../../components/enemy/export.zig");
const Ability = Enemy.Ability;
const ProjectileProfile = Enemy.Ability.ProjectileProfile;

var bishop_enemy_count: u32 = 0;

pub const bishop_abilities = [_]Ability{
    Ability{
        .id = "bishop_streak_stun",
        .execution_type = .projectile,
        .min_range = 0,
        .max_range = 1200,
        .cooldown = 20.0,
        .root_movement_during_action = false,
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/heavy.png",
            .is_channeled = true,
            .channel_duration = 5.0,
            .channel_fire_interval = 0.10,
            .channel_rotation_speed = 72.0,
            .initial_angle = 0,
            .spread_angles = &.{ 0, 90, -90, 180 },
            .damage = 0.35,
            .damage_type = .magic,
            .speed = 750,
            .lifetime = 5.0,
            .size = .init(36, 36),
            .onhit_effect = .stun,
            .onhit_duration = 0.5,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .release_animation = "attack-ranged",
    },

    Ability{
        .id = "bishop_streak_root",
        .execution_type = .projectile,
        .min_range = 0,
        .max_range = 1200,
        .cooldown = 13.0,
        .root_movement_during_action = false,
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/heavy.png",
            .is_channeled = true,
            .channel_duration = 5.0,
            .channel_fire_interval = 0.10,
            .channel_rotation_speed = 72.0,
            .initial_angle = 0,
            .spread_angles = &.{ 0, 90, -90, 180 },
            .damage = 0.35,
            .damage_type = .magic,
            .speed = 750,
            .lifetime = 5.0,
            .size = .init(36, 36),
            .onhit_effect = .root,
            .onhit_duration = 0.5,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .release_animation = "attack-ranged",
    },

    Ability{
        .id = "bishop_streak_slow",
        .execution_type = .projectile,
        .min_range = 0,
        .max_range = 1200,
        .cooldown = 8.0,
        .root_movement_during_action = false,
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/heavy.png",
            .is_channeled = true,
            .channel_duration = 5.0,
            .channel_fire_interval = 0.10,
            .channel_rotation_speed = 72.0,
            .initial_angle = 0,
            .spread_angles = &.{ 0, 90, -90, 180 },
            .damage = 0.35,
            .damage_type = .magic,
            .speed = 750,
            .lifetime = 5.0,
            .size = .init(36, 36),
            .onhit_effect = .slow,
            .onhit_duration = 2.0,
            .onhit_strength = 70.0,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .release_animation = "attack-ranged",
    },

    Ability{
        .id = "bishop_streak_knockback",
        .execution_type = .projectile,
        .min_range = 0,
        .max_range = 1200,
        .cooldown = 4.0,
        .root_movement_during_action = false,
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/heavy.png",
            .is_channeled = true,
            .channel_duration = 5.0,
            .channel_fire_interval = 0.10,
            .channel_rotation_speed = 72.0,
            .initial_angle = 0,
            .spread_angles = &.{ 0, 90, -90, 180 },
            .damage = 0.40,
            .damage_type = .magic,
            .speed = 750,
            .lifetime = 5.0,
            .size = .init(36, 36),
            .knockback_strength = 0.40,
            .knockback_duration = 0.25,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .release_animation = "attack-ranged",
    },
};

const bishop_fallback = Ability{
    .id = "bishop_fallback_cardinal",
    .execution_type = .projectile,
    .min_range = 0,
    .max_range = 1000,
    .cooldown = 0.6,
    .root_movement_during_action = false,
    .projectile_profile = ProjectileProfile{
        .sprite = "projectiles/enemies/heavy.png",
        .aim_mode = .absolute_world,
        .base_angle = 0,
        .spread_angles = &.{ 0, 90, -90, 180 },
        .damage = 0.25,
        .damage_type = .magic,
        .speed = 520,
        .lifetime = 2.5,
        .size = .init(32, 32),
        .sfx_path = "audio/sfx/punch.mp3",
    },
    .release_animation = "attack-ranged",
};

pub fn BishopEnemy(position: lm.Vector2) !*lm.Entity {
    defer bishop_enemy_count +%= 1;

    return try lm.makeEntityI("bishop-enemy", bishop_enemy_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(76, 76),
        },
        lm.Renderer.init(.{
            .img_path = "characters/enemies/ranged/left_1.png",
            .tint = lm.Color{ .r = 175, .g = 90, .b = 240, .a = 255 },
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
            .transform = .{ .scale = .init(78, 78) },
            .weight = 2.5,
        }),
        lm.Animator.init(&Enemy.Animation.ranged_animations),

        Stats.init(.enemy, .{
            .health = 950,
            .magic_damage = 25,
            .attack_speed = 1.0,
            .armour = 30,
            .magic_resist = 50,
            .movement_speed = 130,
            .aggro_range = 1100,
        }),
        StatusOverlays{},
        Dashing{},

        Enemy.Movement.init(.kite_strafe),
        Enemy.Attack.init(&bishop_abilities, bishop_fallback),
        Enemy.Animation{},
        Enemy.Death{ .enemy_type = .bishop },
        Enemy.OverheadUI{ .show_health_bar = false },
    });
}

test "Bishop enemy creation and component configuration" {
    const bishop = try BishopEnemy(.init(400.0, 500.0));
    defer bishop.deinit();
    try bishop.addPreparedComponents(false);

    try std.testing.expect(std.mem.startsWith(u8, bishop.id, "bishop-enemy"));
    try std.testing.expect(bishop.getComponent(Stats) != null);
    try std.testing.expect(bishop.getComponent(Enemy.Attack) != null);
    try std.testing.expect(bishop.getComponent(Enemy.Movement) != null);
    try std.testing.expect(bishop.getComponent(Enemy.Death) != null);

    const stats = bishop.getComponent(Stats).?;
    try std.testing.expectEqual(@as(f32, 950.0), stats.max.health);
    try std.testing.expectEqual(@as(f32, 25.0), stats.base.magic_damage);
    try std.testing.expectEqual(@as(f32, 30.0), stats.base.armour);
    try std.testing.expectEqual(@as(f32, 50.0), stats.base.magic_resist);
    try std.testing.expectEqual(@as(f32, 130.0), stats.current.movement_speed);
}

test "Bishop calculates non-zero magic damage against player" {
    const bishop = try BishopEnemy(.init(400.0, 500.0));
    defer bishop.deinit();

    const bishop_stats = bishop.getComponent(Stats).?;
    const player_stats = Stats.init(.player, .{
        .health = 100,
        .magic_resist = 10,
    });

    const damage = bishop_stats.calculateDamage(player_stats, .magic, false);
    try std.testing.expect(damage > 0.0);
}

test "Bishop 4 rotating streak ability variants configuration" {
    try std.testing.expectEqual(@as(usize, 4), bishop_abilities.len);

    for (bishop_abilities) |ability| {
        try std.testing.expectEqual(Ability.ExecutionType.projectile, ability.execution_type);
        const profile = ability.projectile_profile.?;
        try std.testing.expect(profile.is_channeled);
        try std.testing.expectEqual(@as(f32, 5.0), profile.channel_duration);
        try std.testing.expectEqual(@as(f32, 72.0), profile.channel_rotation_speed);
        try std.testing.expectEqual(@as(f32, 750.0), profile.speed);
        try std.testing.expectEqual(@as(f32, 5.0), profile.lifetime);
        try std.testing.expectEqual(@as(usize, 4), profile.spread_angles.len);
    }

    const stun_variant = bishop_abilities[0];
    try std.testing.expectEqual(Enemy.Ability.OnHitEffect.stun, stun_variant.projectile_profile.?.onhit_effect.?);
    try std.testing.expectEqual(@as(f32, 20.0), stun_variant.cooldown);

    const root_variant = bishop_abilities[1];
    try std.testing.expectEqual(Enemy.Ability.OnHitEffect.root, root_variant.projectile_profile.?.onhit_effect.?);
    try std.testing.expectEqual(@as(f32, 13.0), root_variant.cooldown);

    const slow_variant = bishop_abilities[2];
    try std.testing.expectEqual(Enemy.Ability.OnHitEffect.slow, slow_variant.projectile_profile.?.onhit_effect.?);
    try std.testing.expectEqual(@as(f32, 8.0), slow_variant.cooldown);

    const knockback_variant = bishop_abilities[3];
    try std.testing.expect(knockback_variant.projectile_profile.?.knockback_strength > 0);
    try std.testing.expectEqual(@as(f32, 4.0), knockback_variant.cooldown);
}
