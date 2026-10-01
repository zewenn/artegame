const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const StatusOverlays = @import("../../components/effects/StatusOverlays.zig");
const Dashing = @import("../../components/Dashing.zig");
const Enemy = @import("../../components/enemy/export.zig");
const Ability = Enemy.Ability;
const ProjectileProfile = Enemy.Ability.ProjectileProfile;
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");

var magician_enemy_count: u32 = 0;

pub const magician_animations = [_]lm.Animation{
    lm.Animation.init("idle-left", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = -3, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 64, .height = 64 },
    }),
    lm.Animation.init("idle-right", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 3, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 64, .height = 64 },
    }),
    lm.Animation.init("walk-left", 0.35, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 8, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = -5, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 64, .height = 64 },
    }),
    lm.Animation.init("walk-right", 0.35, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = -8, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 5, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 64, .height = 64 },
    }),
    lm.Animation.init("windup-cast", 0.30, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = -8, .width = 64, .height = 64 },
    }),
    lm.Animation.init("cast", 0.45, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = -8, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 14, .width = 64, .height = 64 },
    }),
    lm.Animation.init("winddown-cast", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 14, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 64, .height = 64 },
    }),
    lm.Animation.init("stunned", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 20, .width = 64, .height = 64 },
    }),
};

pub fn magicianBlink(
    enemy_entity: *lm.Entity,
    enemy_transform: *lm.Transform,
    enemy_stats: *Stats,
    player_transform: *lm.Transform,
    player_stats: ?*Stats,
) anyerror!void {
    _ = enemy_entity;
    _ = enemy_stats;

    const player_position = lm.vec3ToVec2(player_transform.position);
    enemy_transform.position.x = player_position.x;
    enemy_transform.position.y = player_position.y;

    if (player_stats) |stats| {
        stats.current.health = @max(0.0, stats.current.health - 15.0);
    }

    SpatialAudio.playSpatialPitched("audio/sfx/dash.wav", player_position, player_position, 800.0, 0.75, 0.1);
}

pub const magician_abilities = [_]Ability{
    Ability{
        .id = "magician_blink",
        .execution_type = .custom,
        .min_range = 100,
        .max_range = 800,
        .cooldown = 4.5,
        .custom_action = magicianBlink,
        .windup_animation = "windup-cast",
        .release_animation = "cast",
        .winddown_animation = "winddown-cast",
    },

    Ability{
        .id = "magician_where_are_you_going",
        .execution_type = .projectile,
        .min_range = 140,
        .max_range = 800,
        .cooldown = 9.0,
        .projectile_profile = ProjectileProfile{
            .sprite = "empty.png",
            .aim_mode = .towards_player,
            .damage = 2.5,
            .damage_type = .magic,
            .speed = 420,
            .lifetime = 1.6,
            .size = .init(48, 48),
            .pull_speed = 800.0,
            .pull_duration = 2.0,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-cast",
        .release_animation = "cast",
        .winddown_animation = "winddown-cast",
    },

    Ability{
        .id = "magician_covered_attack",
        .execution_type = .projectile,
        .min_range = 0,
        .max_range = 400,
        .cooldown = 6.0,
        .projectile_profile = ProjectileProfile{
            .sprite = "empty.png",
            .aim_mode = .towards_player,
            .spread_angles = &.{ -15, 0, 15 },
            .damage = 2.0,
            .damage_type = .magic,
            .speed = 480,
            .lifetime = 1.2,
            .size = .init(44, 44),
            .onhit_effect = .stun,
            .onhit_duration = 1.0,
            .sfx_path = "audio/sfx/click.wav",
        },
        .windup_animation = "windup-cast",
        .release_animation = "cast",
        .winddown_animation = "winddown-cast",
    },
};

const magician_fallback = Ability{
    .id = "magician_magic_dart",
    .execution_type = .projectile,
    .min_range = 0,
    .max_range = 650,
    .cooldown = 1.2,
    .projectile_profile = ProjectileProfile{
        .sprite = "empty.png",
        .damage = 0.5,
        .damage_type = .magic,
        .speed = 380,
        .lifetime = 1.5,
        .size = .init(40, 40),
        .sfx_path = "audio/sfx/punch.mp3",
    },
    .windup_animation = "windup-cast",
    .release_animation = "cast",
    .winddown_animation = "winddown-cast",
};

pub fn MagicianEnemy(position: lm.Vector2) !*lm.Entity {
    defer magician_enemy_count +%= 1;

    return try lm.makeEntityI("magician-enemy", magician_enemy_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(64, 64),
        },
        lm.Renderer.init(.{
            .img_path = "empty.png",
            .tint = lm.Color{ .r = 180, .g = 80, .b = 240, .a = 255 },
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
            .transform = .{ .scale = .init(64, 64) },
        }),
        lm.Animator.init(&magician_animations),

        Stats.init(.enemy, .{
            .health = 260,
            .attack_speed = 1.0,
            .armour = 15,
            .movement_speed = 140,
            .aggro_range = 900,
        }),
        StatusOverlays{},
        Dashing{},
        Enemy.ProximityAura{
            .proximity_slow = .{
                .threshold_distance_pixels = 400.0,
                .slow_strength = 60.0,
            },
        },

        Enemy.Movement.init(.kite_strafe),
        Enemy.Attack.init(&magician_abilities, magician_fallback),
        Enemy.Animation{},
        Enemy.Death{ .enemy_type = .magician },
    });
}

test "Magician enemy creation and component configuration" {
    const magician = try MagicianEnemy(.init(150.0, 250.0));
    defer magician.deinit();
    try magician.addPreparedComponents(false);

    try std.testing.expect(std.mem.startsWith(u8, magician.id, "magician-enemy"));
    try std.testing.expect(magician.getComponent(Stats) != null);
    try std.testing.expect(magician.getComponent(Enemy.ProximityAura) != null);
    try std.testing.expect(magician.getComponent(Enemy.Attack) != null);

    const stats = magician.getComponent(Stats).?;
    try std.testing.expectEqual(@as(f32, 260.0), stats.max.health);
    try std.testing.expectEqual(@as(f32, 140.0), stats.current.movement_speed);
}

test "Magician ability profiles and animations" {
    try std.testing.expectEqual(@as(usize, 3), magician_abilities.len);

    const blink_ability = magician_abilities[0];
    try std.testing.expectEqual(Ability.ExecutionType.custom, blink_ability.execution_type);

    const pull_ability = magician_abilities[1];
    try std.testing.expectEqual(@as(f32, 800.0), pull_ability.projectile_profile.?.pull_speed.?);
    try std.testing.expectEqual(@as(f32, 2.0), pull_ability.projectile_profile.?.pull_duration);

    const stun_burst = magician_abilities[2];
    try std.testing.expectEqual(@as(f32, 400.0), stun_burst.max_range);
    try std.testing.expectEqual(Enemy.Ability.OnHitEffect.stun, stun_burst.projectile_profile.?.onhit_effect.?);
    try std.testing.expectEqual(@as(usize, 3), stun_burst.projectile_profile.?.spread_angles.len);

    for (magician_animations) |anim| {
        for (anim.base_keyframes) |keyframe| {
            try std.testing.expectEqualStrings("empty.png", keyframe.sprite.?);
            try std.testing.expectEqual(@as(f32, 64.0), keyframe.width.?);
            try std.testing.expectEqual(@as(f32, 64.0), keyframe.height.?);
        }
    }
}
