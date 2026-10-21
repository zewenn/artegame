const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const StatusOverlays = @import("../../components/effects/StatusOverlays.zig");
const Dashing = @import("../../components/Dashing.zig");
const Enemy = @import("../../components/enemy/export.zig");
const Ability = Enemy.Ability;
const ProjectileProfile = Enemy.Ability.ProjectileProfile;
const KnightMechanics = Enemy.KnightMechanics;
const projectiles = @import("../Projectile.zig");
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");

var knight_enemy_count: u32 = 0;

inline fn assetPath(sprite: []const u8) []const u8 {
    return "characters/enemies/knight/" ++ sprite ++ ".png";
}

pub const knight_animations = [_]lm.Animation{
    lm.Animation.init("idle-left", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("idle_1"), .rotation = 0, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("idle_2"), .rotation = -3, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("idle_1"), .rotation = 0, .width = 128, .height = 128 },
    }),
    lm.Animation.init("idle-right", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("idle_1"), .rotation = 0, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("idle_2"), .rotation = 3, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("idle_3"), .rotation = 0, .width = 128, .height = 128 },
    }),
    lm.Animation.init("walk-left", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("left_1"), .rotation = 0, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("left_2"), .rotation = 10, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("left_3"), .rotation = -6, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("left_1"), .rotation = 0, .width = 128, .height = 128 },
    }),
    lm.Animation.init("walk-right", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("right_1"), .rotation = 0, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("right_2"), .rotation = -10, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("right_3"), .rotation = 6, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("right_1"), .rotation = 0, .width = 128, .height = 128 },
    }),
    lm.Animation.init("windup-melee", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/attack/windup_1"), .width = 256, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/attack/windup_2"), .width = 256, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/attack/windup_3"), .width = 256, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/attack/cast_1"), .width = 256, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/attack/cast_2"), .width = 256, .height = 128 },
    }),
    lm.Animation.init("attack-melee", 0.2, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/attack/cast_1"), .width = 256, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/attack/cast_2"), .width = 256, .height = 128 },
    }),
    lm.Animation.init("winddown-melee", 0.3, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/attack/winddown_1"), .width = 256, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/attack/winddown_2"), .width = 256, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/attack/winddown_3"), .width = 256, .height = 128 },
    }),
    lm.Animation.init("windup-slow-down", 0.7, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/slow_down/windup_1"), .width = 128, .height = 256 },
        lm.Keyframe{ .sprite = assetPath("spells/slow_down/windup_2"), .width = 128, .height = 256 },
        lm.Keyframe{ .sprite = assetPath("spells/slow_down/windup_3"), .width = 128, .height = 256 },
        lm.Keyframe{ .sprite = assetPath("spells/slow_down/windup_4"), .width = 128, .height = 256 },
        lm.Keyframe{ .sprite = assetPath("spells/slow_down/windup_5"), .width = 128, .height = 256 },
        lm.Keyframe{ .sprite = assetPath("spells/slow_down/windup_6"), .width = 128, .height = 256 },
        lm.Keyframe{ .sprite = assetPath("spells/slow_down/windup_7"), .width = 128, .height = 256 },
    }),
    lm.Animation.init("attack-slow-down", 0.4, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/slow_down/cast_1"), .width = 128, .height = 256 },
        lm.Keyframe{ .sprite = assetPath("spells/slow_down/cast_2"), .width = 128, .height = 256 },
        lm.Keyframe{ .sprite = assetPath("spells/slow_down/cast_1"), .width = 128, .height = 256 },
        lm.Keyframe{ .sprite = assetPath("spells/slow_down/cast_2"), .width = 128, .height = 256 },
    }),
    lm.Animation.init("winddown-slow-down", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/slow_down/winddown_1"), .width = 128, .height = 256 },
        lm.Keyframe{ .sprite = assetPath("spells/slow_down/winddown_2"), .width = 128, .height = 256 },
        lm.Keyframe{ .sprite = assetPath("spells/slow_down/winddown_3"), .width = 128, .height = 256 },
        lm.Keyframe{ .sprite = assetPath("spells/slow_down/winddown_4"), .width = 128, .height = 256 },
        lm.Keyframe{ .sprite = assetPath("spells/slow_down/winddown_5"), .width = 128, .height = 256 },
    }),
    lm.Animation.init("windup-heal-channel", 0.6, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/heal_channel/windup_1"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/heal_channel/windup_2"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/heal_channel/windup_3"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/heal_channel/windup_4"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/heal_channel/windup_5"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/heal_channel/windup_6"), .width = 128, .height = 128 },
    }),
    lm.Animation.init("attack-heal-channel", 4, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/heal_channel/cast_1"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/heal_channel/cast_2"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/heal_channel/cast_3"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/heal_channel/cast_4"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/heal_channel/cast_1"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/heal_channel/cast_2"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/heal_channel/cast_3"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/heal_channel/cast_4"), .width = 128, .height = 128 },
    }),
    lm.Animation.init("winddown-heal-channel", 0.4, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/heal_channel/winddown_1"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/heal_channel/winddown_2"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/heal_channel/winddown_3"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/heal_channel/winddown_4"), .width = 128, .height = 128 },
    }),
    lm.Animation.init("windup-weaken", 0.3, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/weaken/windup_1"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/weaken/windup_2"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/weaken/windup_3"), .width = 128, .height = 128 },
    }),
    lm.Animation.init("attack-weaken", 3.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/weaken/cast_1"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/weaken/cast_2"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/weaken/cast_1"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/weaken/cast_2"), .width = 128, .height = 128 },
    }),
    lm.Animation.init("winddown-weaken", 0.3, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/weaken/winddown_1"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/weaken/winddown_2"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/weaken/winddown_3"), .width = 128, .height = 128 },
    }),
    lm.Animation.init("stunned", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .rotation = 2 },
        lm.Keyframe{ .rotation = -2 },
    }),
};

fn knightBeheadingOnHit(hit: projectiles.HitInfo) void {
    const player_stats = hit.target.getComponent(Stats) orelse return;
    const damage_percent: f32 = 0.15;
    const damage_amount = player_stats.max.health * damage_percent;
    player_stats.current.health = @max(0.0, player_stats.current.health - damage_amount);

    if (hit.target.getComponent(lm.Transform)) |transform| {
        const hit_position = lm.vec3ToVec2(transform.position);
        SpatialAudio.playSpatialPitched("audio/sfx/punch.mp3", hit_position, hit_position, 800.0, 0.70, 0.15);
    }
}

fn knightCastWeaken(
    enemy_entity: *lm.Entity,
    enemy_transform: *lm.Transform,
    enemy_stats: *Stats,
    player_transform: *lm.Transform,
    player_stats: ?*Stats,
) anyerror!void {
    _ = enemy_transform;
    _ = enemy_stats;
    _ = player_transform;
    _ = player_stats;

    if (enemy_entity.getComponent(KnightMechanics)) |mechanics| {
        mechanics.startWeaken(3.5);
    }
}

fn knightCastHealChannel(
    enemy_entity: *lm.Entity,
    enemy_transform: *lm.Transform,
    enemy_stats: *Stats,
    player_transform: *lm.Transform,
    player_stats: ?*Stats,
) anyerror!void {
    _ = enemy_transform;
    _ = enemy_stats;
    _ = player_transform;
    _ = player_stats;

    if (enemy_entity.getComponent(KnightMechanics)) |mechanics| {
        mechanics.startHealChannel(4.0, 1);
    }
}

pub const knight_abilities = [_]Ability{
    Ability{
        .id = "knight_heal_channel",
        .execution_type = .custom,
        .min_range = 0,
        .max_range = 9999,
        .cooldown = 999.0,
        .conditions = .{
            .health_below_pct = 0.25,
        },
        .custom_action = knightCastHealChannel,
        .windup_animation = "windup-heal-channel",
        .release_animation = "attack-heal-channel",
        .winddown_animation = "winddown-heal-channel",
    },

    Ability{
        .id = "knight_weaken",
        .execution_type = .custom,
        .min_range = 0,
        .max_range = 9999,
        .cooldown = 22.0,
        .conditions = .{
            .health_below_pct = 0.85,
        },
        .custom_action = knightCastWeaken,
        .windup_animation = "windup-weaken",
        .release_animation = "attack-weaken",
        .winddown_animation = "winddown-weaken",
    },

    Ability{
        .id = "knight_beheading",
        .execution_type = .projectile,
        .min_range = 0,
        .max_range = 450,
        .cooldown = 4.5,
        .conditions = .{
            .health_below_pct = 0.66,
        },
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/knight/beheading.png",
            .damage = 0.6,
            .damage_type = .physical,
            .speed = 1000,
            .lifetime = 0.45,
            .size = .init(64, 128),
            .onhit_effect = .stun,
            .onhit_duration = 1.5,
            .on_hit_callback = knightBeheadingOnHit,
            .sfx_path = "audio/sfx/punch.mp3",

            .aim_mode = .absolute_world,
            .spread_angles = &.{ 0, -30, 30, 60, -60, 90, -90, 120, -120, 150, -150, 180 },

            .is_channeled = true,
            .channel_rotation_speed = 15,
            .channel_duration = 0.5,
            .channel_fire_interval = 0.26,
        },
        .windup_animation = "windup-melee",
        .release_animation = "attack-melee",
        .winddown_animation = "winddown-melee",
    },

    Ability{
        .id = "knight_strike",
        .execution_type = .projectile,
        .min_range = 0,
        .max_range = 500,
        .cooldown = 2.2,
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/knight/strike.png",
            .damage = 1.6,
            .damage_type = .physical,
            .speed = 1200,
            .lifetime = 0.35,
            .size = .init(96, 48),
            .spread_angles = &.{ 0, 15, -15 },
            .knockback_strength = 0.35,
            .knockback_duration = 0.2,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-melee",
        .release_animation = "attack-melee",
        .winddown_animation = "winddown-melee",
    },

    Ability{
        .id = "slow_down",
        .execution_type = .projectile,
        .min_range = 510,
        .max_range = 9999,
        .cooldown = 5,
        .conditions = .{
            .health_above_pct = 0.5,
        },
        .projectile_profile = .{
            .sprite = "projectiles/enemies/knight/slow_down.png",
            .speed = 900,
            .lifetime = 1.65,
            .aim_mode = .absolute_world,
            .spread_angles = &.{ 0, -30, 30, 60, -60, 90, -90, 120, -120, 150, -150, 180 },

            .is_channeled = true,
            .channel_rotation_speed = 10,
            .channel_duration = 0.5,
            .channel_fire_interval = 0.25,

            .damage_type = .magic,
            .damage = 0.75,
            .onhit_duration = 3,
            .onhit_effect = .slow,
            .onhit_strength = 250,
            .size = .init(96, 64),
        },
        .windup_animation = "windup-slow-down",
        .release_animation = "attack-slow-down",
        .winddown_animation = "winddown-slow-down",
    },

    Ability{
        .id = "knight_slow_down_2",
        .execution_type = .projectile,
        .min_range = 520,
        .max_range = 9999,
        .cooldown = 5,
        .conditions = .{
            .health_below_pct = 0.50,
        },
        .projectile_profile = .{
            .sprite = "projectiles/enemies/knight/slow_down_2.png",
            .speed = 900,
            .lifetime = 1.65,
            .aim_mode = .absolute_world,
            .spread_angles = &.{ 0, -30, 30, 60, -60, 90, -90, 120, -120, 150, -150, 180 },

            .is_channeled = true,
            .channel_rotation_speed = 10,
            .channel_duration = 0.5,
            .channel_fire_interval = 0.25,

            .damage_type = .magic,
            .damage = 1.25,
            .onhit_duration = 2.5,
            .onhit_effect = .root,
            .onhit_strength = 100,
            .size = .init(128, 96),
        },
        .windup_animation = "windup-slow-down",
        .release_animation = "attack-slow-down",
        .winddown_animation = "winddown-slow-down",
    },
};

const knight_fallback = Ability{
    .id = "knight_fallback_cleave",
    .execution_type = .projectile,
    .min_range = 0,
    .max_range = 400,
    .cooldown = 1.0,
    .projectile_profile = ProjectileProfile{
        .sprite = "projectiles/enemies/knight/fallback.png",
        .damage = 1.0,
        .damage_type = .physical,
        .speed = 850,
        .lifetime = 0.35,
        .size = .init(64, 64),
        .sfx_path = "audio/sfx/punch.mp3",

        .onhit_duration = 2,
        .onhit_effect = .slow,
        .onhit_strength = 100,
    },
    .windup_animation = "windup-melee",
    .release_animation = "attack-melee",
    .winddown_animation = "winddown-melee",
};

pub fn KnightEnemy(position: lm.Vector2) !*lm.Entity {
    defer knight_enemy_count +%= 1;

    return try lm.makeEntityI("knight-enemy", knight_enemy_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(128, 128),
        },
        lm.Renderer.init(.{
            .img_path = "characters/enemies/knight/idle_1.png",
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
            .transform = .{ .scale = .init(90, 90) },
            .weight = 4.0,
        }),
        lm.Animator.init(&knight_animations),

        Stats.initUnstoppable(.enemy, .{
            .health = 1500,
            .attack_speed = 0.85,
            .armour = 60,
            .magic_resist = 35,
            .movement_speed = 175,
            .magic_damage = 5,
            .aggro_range = 9999,
        }),
        StatusOverlays{},
        Dashing{},

        Enemy.ProximityAura{
            .parabolic_defense = .{
                .inner_distance_pixels = 400.0,
                .outer_distance_pixels = 1000.0,
                .max_bonus_defense = 10000.0,
            },
            .distance_drain = .{
                .inner_distance_pixels = 550.0,
                .outer_distance_pixels = 1000.0,
                .min_damage_per_second = 1.0,
                .max_damage_per_second = 15.0,
                .room_scaling_factor = 1.0,
            },
        },
        KnightMechanics{},

        Enemy.Movement.init(.pursue),
        Enemy.Attack.init(&knight_abilities, knight_fallback),
        Enemy.Animation{},
        Enemy.Death{ .enemy_type = .knight },
        Enemy.OverheadUI{ .show_health_bar = false },
    });
}

test "Knight enemy creation and component configuration" {
    const knight = try KnightEnemy(.init(300.0, 400.0));
    defer knight.deinit();
    try knight.addPreparedComponents(false);

    try std.testing.expect(std.mem.startsWith(u8, knight.id, "knight-enemy"));
    try std.testing.expect(knight.getComponent(Stats) != null);
    try std.testing.expect(knight.getComponent(Enemy.ProximityAura) != null);
    try std.testing.expect(knight.getComponent(KnightMechanics) != null);
    try std.testing.expect(knight.getComponent(Enemy.Attack) != null);
    try std.testing.expect(knight.getComponent(Enemy.Death) != null);

    const stats = knight.getComponent(Stats).?;
    try std.testing.expectEqual(@as(f32, 1200.0), stats.max.health);
    try std.testing.expectEqual(@as(f32, 60.0), stats.base.armour);
    try std.testing.expectEqual(@as(f32, 35.0), stats.base.magic_resist);
    try std.testing.expectEqual(@as(f32, 120.0), stats.current.movement_speed);
}
