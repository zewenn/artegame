const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const StatusOverlays = @import("../../components/effects/StatusOverlays.zig");
const Dashing = @import("../../components/Dashing.zig");
const Enemy = @import("../../components/enemy/export.zig");
const Ability = Enemy.Ability;
const ProjectileProfile = Enemy.Ability.ProjectileProfile;
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");

var tank_enemy_count: u32 = 0;

pub const tank_animations = [_]lm.Animation{
    lm.Animation.init("idle-left", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 80, .height = 80 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = -2, .width = 80, .height = 80 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 80, .height = 80 },
    }),
    lm.Animation.init("idle-right", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 80, .height = 80 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 2, .width = 80, .height = 80 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 80, .height = 80 },
    }),
    lm.Animation.init("walk-left", 0.40, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 80, .height = 80 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 6, .width = 80, .height = 80 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = -4, .width = 80, .height = 80 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 80, .height = 80 },
    }),
    lm.Animation.init("walk-right", 0.40, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 80, .height = 80 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = -6, .width = 80, .height = 80 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 4, .width = 80, .height = 80 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 80, .height = 80 },
    }),
    lm.Animation.init("windup-tank", 0.40, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 80, .height = 80 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = -12, .width = 96, .height = 80 },
    }),
    lm.Animation.init("attack-tank", 0.20, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = -12, .width = 96, .height = 80 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 16, .width = 70, .height = 80 },
    }),
    lm.Animation.init("winddown-tank", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 16, .width = 70, .height = 80 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 80, .height = 80 },
    }),
    lm.Animation.init("stunned", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 15, .width = 80, .height = 80 },
    }),
};

pub fn tankActivateShield(
    enemy_entity: *lm.Entity,
    enemy_transform: *lm.Transform,
    enemy_stats: *Stats,
    player_transform: *lm.Transform,
    player_stats: ?*Stats,
) anyerror!void {
    _ = enemy_stats;
    _ = player_stats;

    if (enemy_entity.getComponent(Enemy.ReactiveAura)) |aura| {
        aura.activateShield(5.0);
    }

    const caster_position = lm.vec3ToVec2(enemy_transform.position);
    const listener_position = lm.vec3ToVec2(player_transform.position);
    SpatialAudio.playSpatialPitched("audio/sfx/boom.wav", caster_position, listener_position, 800.0, 0.60, 0.10);
}

pub const tank_abilities = [_]Ability{
    Ability{
        .id = "tank_root_shield",
        .execution_type = .custom,
        .min_range = 0,
        .max_range = 800,
        .cooldown = 15.0,
        .custom_action = tankActivateShield,
        .windup_animation = "windup-tank",
        .release_animation = "attack-tank",
        .winddown_animation = "winddown-tank",
    },

    Ability{
        .id = "tank_slow_barrage",
        .execution_type = .projectile,
        .min_range = 80,
        .max_range = 650,
        .cooldown = 4.5,
        .projectile_profile = ProjectileProfile{
            .sprite = "empty.png",
            .wave_count = 3,
            .wave_interval = 0.12,
            .spread_angles = &.{ -12, 0, 12 },
            .damage = 0.25,
            .damage_type = .physical,
            .speed = 360,
            .lifetime = 1.4,
            .size = .init(44, 44),
            .onhit_effect = .slow,
            .onhit_strength = 35,
            .onhit_duration = 1.8,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-tank",
        .release_animation = "attack-tank",
        .winddown_animation = "winddown-tank",
    },

    Ability{
        .id = "tank_knockback_shot",
        .execution_type = .projectile,
        .min_range = 60,
        .max_range = 550,
        .cooldown = 3.5,
        .projectile_profile = ProjectileProfile{
            .sprite = "empty.png",
            .damage = 0.4,
            .damage_type = .physical,
            .speed = 440,
            .lifetime = 1.3,
            .size = .init(52, 52),
            .knockback_strength = 0.65,
            .knockback_duration = 0.30,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-tank",
        .release_animation = "attack-tank",
        .winddown_animation = "winddown-tank",
    },

    Ability{
        .id = "tank_stun_burst",
        .execution_type = .projectile,
        .min_range = 0,
        .max_range = 700,
        .cooldown = 8.0,
        .projectile_profile = ProjectileProfile{
            .sprite = "empty.png",
            .aim_mode = .absolute_world,
            .base_angle = 0,
            .spread_angles = &.{ 0, 45, -45, 90, -90, 135, -135, 180 },
            .damage = 0.30,
            .damage_type = .physical,
            .speed = 350,
            .lifetime = 1.6,
            .size = .init(48, 48),
            .onhit_effect = .stun,
            .onhit_duration = 1.0,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-tank",
        .release_animation = "attack-tank",
        .winddown_animation = "winddown-tank",
    },
};

const tank_fallback = Ability{
    .id = "tank_melee_smash",
    .execution_type = .projectile,
    .min_range = 0,
    .max_range = 80,
    .cooldown = 1.2,
    .projectile_profile = ProjectileProfile{
        .damage = 0.70,
        .damage_type = .physical,
        .speed = 500,
        .lifetime = 0.15,
        .size = .init(64, 64),
        .knockback_strength = 0.40,
        .knockback_duration = 0.20,
        .sfx_path = "audio/sfx/punch.mp3",
    },
    .windup_animation = "windup-tank",
    .release_animation = "attack-tank",
    .winddown_animation = "winddown-tank",
};

pub fn TankEnemy(position: lm.Vector2) !*lm.Entity {
    defer tank_enemy_count +%= 1;

    return try lm.makeEntityI("tank-enemy", tank_enemy_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(80, 80),
        },
        lm.Renderer.init(.{
            .img_path = "empty.png",
            .tint = lm.Color{ .r = 130, .g = 140, .b = 160, .a = 255 },
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
            .transform = .{ .scale = .init(84, 84) },
            .weight = 3.0,
        }),
        lm.Animator.init(&tank_animations),

        Stats.init(.enemy, .{
            .health = 650,
            .attack_speed = 0.8,
            .armour = 45,
            .magic_resist = 30,
            .movement_speed = 95,
            .aggro_range = 850,
        }),
        StatusOverlays{},
        Dashing{},
        Enemy.ReactiveAura{
            .apply_effect_on_hit = .{
                .effect_type = .root,
                .duration_seconds = 1.0,
            },
            .cooldown_seconds = 15.0,
        },

        Enemy.Movement.init(.pursue),
        Enemy.Attack.init(&tank_abilities, tank_fallback),
        Enemy.Animation{},
        Enemy.Death{ .enemy_type = .tank },
    });
}

test "Tank enemy creation and component configuration" {
    const tank = try TankEnemy(.init(400.0, 500.0));
    defer tank.deinit();
    try tank.addPreparedComponents(false);

    try std.testing.expect(std.mem.startsWith(u8, tank.id, "tank-enemy"));
    try std.testing.expect(tank.getComponent(Stats) != null);
    try std.testing.expect(tank.getComponent(Enemy.ReactiveAura) != null);
    try std.testing.expect(tank.getComponent(Enemy.Attack) != null);

    const stats = tank.getComponent(Stats).?;
    try std.testing.expectEqual(@as(f32, 650.0), stats.max.health);
    try std.testing.expectEqual(@as(f32, 45.0), stats.base.armour);
    try std.testing.expectEqual(@as(f32, 95.0), stats.current.movement_speed);
}

test "Tank ability profiles and animations" {
    try std.testing.expectEqual(@as(usize, 4), tank_abilities.len);

    const shield_ability = tank_abilities[0];
    try std.testing.expectEqual(Ability.ExecutionType.custom, shield_ability.execution_type);

    const slow_barrage = tank_abilities[1];
    try std.testing.expectEqual(@as(u32, 3), slow_barrage.projectile_profile.?.wave_count);
    try std.testing.expectEqual(Enemy.Ability.OnHitEffect.slow, slow_barrage.projectile_profile.?.onhit_effect.?);

    const knockback = tank_abilities[2];
    try std.testing.expect(knockback.projectile_profile.?.knockback_strength > 0);

    const stun_burst = tank_abilities[3];
    try std.testing.expectEqual(@as(usize, 8), stun_burst.projectile_profile.?.spread_angles.len);
    try std.testing.expectEqual(Enemy.Ability.OnHitEffect.stun, stun_burst.projectile_profile.?.onhit_effect.?);

    for (tank_animations) |anim| {
        for (anim.base_keyframes) |keyframe| {
            try std.testing.expectEqualStrings("empty.png", keyframe.sprite.?);
            try std.testing.expect(keyframe.width.? >= 70.0);
            try std.testing.expect(keyframe.height.? >= 80.0);
        }
    }
}
