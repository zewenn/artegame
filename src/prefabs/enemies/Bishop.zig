const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const StatusOverlays = @import("../../components/effects/StatusOverlays.zig");
const Dashing = @import("../../components/Dashing.zig");
const Enemy = @import("../../components/enemy/export.zig");
const Ability = Enemy.Ability;
const ProjectileProfile = Enemy.Ability.ProjectileProfile;

const HitInfo = @import("../Projectile.zig").HitInfo;

var bishop_enemy_count: u32 = 0;

inline fn assetPath(sprite: []const u8) []const u8 {
    return "characters/enemies/bishop/" ++ sprite ++ ".png";
}

pub const bishop_animations = [_]lm.Animation{
    lm.Animation.init("idle-left", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("idle_left_1"), .rotation = 0, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("idle_left_2"), .rotation = -3, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("idle_left_1"), .rotation = 0, .width = 128, .height = 128 },
    }),
    lm.Animation.init("idle-right", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("idle_right_1"), .rotation = 0, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("idle_right_2"), .rotation = 3, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("idle_right_3"), .rotation = 0, .width = 128, .height = 128 },
    }),
    lm.Animation.init("walk-left", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("left_1"), .rotation = 0, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("left_2"), .rotation = 10, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("left_2"), .rotation = -6, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("left_1"), .rotation = 0, .width = 128, .height = 128 },
    }),
    lm.Animation.init("walk-right", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("right_1"), .rotation = 0, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("right_2"), .rotation = -10, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("right_2"), .rotation = 6, .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("right_1"), .rotation = 0, .width = 128, .height = 128 },
    }),
    lm.Animation.init("windup-bake-attack", 1.7, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/windup_1"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/windup_2"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/windup_3"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/windup_4"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/windup_5"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/windup_6"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/windup_7"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/windup_8"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/windup_9"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/windup_10"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/windup_11"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/windup_12"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/windup_13"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/windup_14"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/windup_15"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/windup_16"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/windup_17"), .width = 128, .height = 128 },
    }),
    lm.Animation.init("cast-bake-attack", 5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/cast_1"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/cast_2"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/cast_3"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/cast_4"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/cast_5"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/cast_6"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/cast_7"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/cast_8"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/cast_9"), .width = 128, .height = 128 },
    }),
    lm.Animation.init("winddown-bake-attack", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/winddown_1"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/winddown_2"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/winddown_3"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/winddown_4"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/bake-attack/winddown_5"), .width = 128, .height = 128 },
    }),
    lm.Animation.init("windup-pancake-attack", 0.8, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/pancake-attack/windup_1"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/pancake-attack/windup_2"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/pancake-attack/windup_3"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/pancake-attack/windup_4"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/pancake-attack/windup_5"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/pancake-attack/windup_6"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/pancake-attack/windup_7"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/pancake-attack/windup_8"), .width = 128, .height = 128 },
    }),
    lm.Animation.init("cast-pancake-attack", 0.3, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/pancake-attack/cast_1"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/pancake-attack/cast_2"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/pancake-attack/cast_3"), .width = 128, .height = 128 },
    }),
    lm.Animation.init("winddown-pancake-attack", 0.3, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/pancake-attack/winddown_1"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/pancake-attack/winddown_2"), .width = 128, .height = 128 },
        lm.Keyframe{ .sprite = assetPath("spells/pancake-attack/winddown_3"), .width = 128, .height = 128 },
    }),
    lm.Animation.init("stunned", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .rotation = 2 },
        lm.Keyframe{ .rotation = -2 },
    }),
};

pub const bishop_abilities = [_]Ability{
    Ability{
        .id = "bishop_streak_knockback_lvl1_cw",
        .execution_type = .projectile,
        .min_range = 500,
        .max_range = 1200,
        .cooldown = 4.0,
        .root_movement_during_action = false,
        .conditions = .{
            .health_above_pct = 0.75,
        },
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/bishop/muffin_lvl1.png",
            .is_channeled = true,
            .channel_duration = 5.0,
            .channel_fire_interval = 0.10,
            .channel_rotation_speed = 25.0,
            .initial_angle = 0,
            .spread_angles = &.{ 0, 180 },
            .damage = 0.10,
            .damage_type = .magic,
            .speed = 750,
            .lifetime = 5.0,
            .size = .init(64, 64),
            .knockback_strength = 0.40,
            .knockback_duration = 0.25,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-bake-attack",
        .release_animation = "cast-bake-attack",
        .winddown_animation = "winddown-bake-attack",
    },
    Ability{
        .id = "bishop_streak_knockback_lvl1_ccw",
        .execution_type = .projectile,
        .min_range = 500,
        .max_range = 1200,
        .cooldown = 4.0,
        .root_movement_during_action = false,
        .conditions = .{
            .health_above_pct = 0.75,
        },
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/bishop/muffin_lvl1.png",
            .is_channeled = true,
            .channel_duration = 5.0,
            .channel_fire_interval = 0.10,
            .channel_rotation_speed = -25.0,
            .initial_angle = 0,
            .spread_angles = &.{ 0, 180 },
            .damage = 0.10,
            .damage_type = .magic,
            .speed = 750,
            .lifetime = 5.0,
            .size = .init(64, 64),
            .knockback_strength = 0.40,
            .knockback_duration = 0.25,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-bake-attack",
        .release_animation = "cast-bake-attack",
        .winddown_animation = "winddown-bake-attack",
    },
    Ability{
        .id = "bishop_streak_knockback_lvl2",
        .execution_type = .projectile,
        .min_range = 500,
        .max_range = 1200,
        .cooldown = 4.0,
        .conditions = .{
            .health_above_pct = 0.50,
            .health_below_pct = 0.76,
        },
        .root_movement_during_action = false,
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/bishop/muffin_lvl2.png",
            .is_channeled = true,
            .channel_duration = 5.0,
            .channel_fire_interval = 0.10,
            .channel_rotation_speed = -25.0,
            .initial_angle = 0,
            .spread_angles = &.{ 0, 90, -90, 180 },
            .damage = 0.20,
            .damage_type = .magic,
            .speed = 750,
            .lifetime = 5.0,
            .size = .init(64, 64),
            .knockback_strength = 0.40,
            .knockback_duration = 0.25,
            .onhit_effect = .slow,
            .onhit_duration = 2.0,
            .onhit_strength = 70.0,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-bake-attack",
        .release_animation = "cast-bake-attack",
        .winddown_animation = "winddown-bake-attack",
    },
    Ability{
        .id = "bishop_streak_knockback_lvl3",
        .execution_type = .projectile,
        .min_range = 500,
        .max_range = 1200,
        .cooldown = 4.0,
        .conditions = .{
            .health_above_pct = 0.25,
            .health_below_pct = 0.51,
        },
        .root_movement_during_action = false,
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/bishop/muffin_lvl3.png",
            .is_channeled = true,
            .channel_duration = 5.0,
            .channel_fire_interval = 0.10,
            .channel_rotation_speed = -35.0,
            .initial_angle = 0,
            .spread_angles = &.{ 0, 60, -60, 120, -120, 180 },
            .damage = 0.30,
            .damage_type = .magic,
            .speed = 750,
            .lifetime = 5.0,
            .size = .init(64, 64),
            .knockback_strength = 0.40,
            .knockback_duration = 0.25,
            .onhit_effect = .root,
            .onhit_duration = 0.5,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-bake-attack",
        .release_animation = "cast-bake-attack",
        .winddown_animation = "winddown-bake-attack",
    },
    Ability{
        .id = "bishop_streak_knockback_lvl4",
        .execution_type = .projectile,
        .min_range = 500,
        .max_range = 1200,
        .cooldown = 4.0,
        .conditions = .{
            .health_below_pct = 0.26,
        },
        .root_movement_during_action = false,
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/bishop/muffin_lvl4.png",
            .is_channeled = true,
            .channel_duration = 5.0,
            .channel_fire_interval = 0.10,
            .channel_rotation_speed = -35.0,
            .initial_angle = 0,
            .spread_angles = &.{ 0, 45, -45, 90, -90, 135, -135, 180 },
            .damage = 0.40,
            .damage_type = .magic,
            .speed = 750,
            .lifetime = 5.0,
            .size = .init(64, 64),
            .knockback_strength = 0.40,
            .knockback_duration = 0.25,
            .onhit_effect = .stun,
            .onhit_duration = 0.5,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-bake-attack",
        .release_animation = "cast-bake-attack",
        .winddown_animation = "winddown-bake-attack",
    },
    Ability{
        .id = "bishop_pancake_snipe",
        .execution_type = .projectile,
        .min_range = 600,
        .max_range = 9999,
        .cooldown = 0.6,
        .root_movement_during_action = false,
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/bishop/pancake_narrow.png",
            .aim_mode = .towards_player,
            .base_angle = 0,
            .spread_angles = &.{ 0, 2, -2 },
            .damage = 0.33,
            .damage_type = .magic,
            .speed = 1200,
            .lifetime = 2.5,
            .size = .init(32, 64),
            .sfx_path = "audio/sfx/punch.mp3",
            .onhit_effect = .stun,
            .onhit_duration = 1.0,
            .on_hit_callback = pancakeOnHit,
        },
        .windup_animation = "windup-pancake-attack",
        .release_animation = "cast-pancake-attack",
        .winddown_animation = "winddown-pancake-attack",
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
        .sprite = "projectiles/enemies/bishop/pancake_normal.png",
        .aim_mode = .towards_player,
        .base_angle = 0,
        .spread_angles = &.{ 0, 15, -15, 45, -45 },
        .damage = 0.75,
        .damage_type = .magic,
        .speed = 720,
        .lifetime = 2.5,
        .size = .init(64, 64),
        .sfx_path = "audio/sfx/punch.mp3",
        .knockback_duration = 0.25,
        .knockback_strength = 1,
        .on_hit_callback = pancakeOnHit,
    },
    .windup_animation = "windup-pancake-attack",
    .release_animation = "cast-pancake-attack",
    .winddown_animation = "winddown-pancake-attack",
};

fn pancakeOnHit(info: HitInfo) void {
    const caster = lm.getEntity(.byUUID(info.caster_uuid orelse return)) orelse return;
    const stats = caster.getComponent(Stats) orelse return;

    stats.addEffect(.{
        .id = "pancake_heal",
        .effect_type = .regen,
        .duration = 0.25,
        .value = 2,
        .on_tick = struct {
            pub fn cb(enemy_stats: *Stats) void {
                enemy_stats.current.health = @min(enemy_stats.max.health, enemy_stats.current.health + 1.25);
            }
        }.cb,
    });
}

pub fn BishopEnemy(position: lm.Vector2) !*lm.Entity {
    defer bishop_enemy_count +%= 1;

    return try lm.makeEntityI("bishop-enemy", bishop_enemy_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(128, 128),
        },
        lm.Renderer.init(.{
            .img_path = assetPath("idle_left_1"),
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
            .transform = .{ .scale = .init(128, 128) },
            .weight = 2.5,
        }),
        lm.Animator.init(&bishop_animations),

        Stats.initUnstoppable(.enemy, .{
            .health = 1250,
            .magic_damage = 50,
            .attack_speed = 1.0,
            .armour = 30,
            .magic_resist = 50,
            .movement_speed = 230,
            .aggro_range = 9999,
        }),
        StatusOverlays{},
        Dashing{},

        Enemy.Movement.init(.kite_strafe),
        Enemy.Attack.init(&bishop_abilities, bishop_fallback),
        Enemy.Animation{},
        Enemy.Death{ .enemy_type = .bishop },
        Enemy.OverheadUI{ .show_health_bar = false },
        Enemy.BossBar{ .boss_name = "Bishop", .rank = .mini_boss },
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
    try std.testing.expect(bishop.getComponent(Enemy.BossBar) != null);

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
