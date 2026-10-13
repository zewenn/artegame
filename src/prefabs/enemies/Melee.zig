const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const StatusOverlays = @import("../../components/effects/StatusOverlays.zig");
const Dashing = @import("../../components/Dashing.zig");
const Enemy = @import("../../components/enemy/export.zig");
const Ability = Enemy.Ability;
const ProjectileProfile = Enemy.Ability.ProjectileProfile;
const MobilityProfile = Enemy.Ability.MobilityProfile;

var melee_enemy_count: u32 = 0;

inline fn assetPath(sprite: []const u8) []const u8 {
    return "characters/enemies/melee/" ++ sprite ++ ".png";
}

const melee_animations = [_]lm.Animation{
    lm.Animation.init("idle-left", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("left_idle_1"), .rotation = 0 },
        lm.Keyframe{ .sprite = assetPath("left_idle_2"), .rotation = -3 },
        lm.Keyframe{ .sprite = assetPath("left_idle_1"), .rotation = 0 },
    }),
    lm.Animation.init("idle-right", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("right_idle_1"), .rotation = 0 },
        lm.Keyframe{ .sprite = assetPath("right_idle_2"), .rotation = 3 },
        lm.Keyframe{ .sprite = assetPath("right_idle_1"), .rotation = 0 },
    }),
    lm.Animation.init("walk-left", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("left_1"), .rotation = 0 },
        lm.Keyframe{ .sprite = assetPath("left_2"), .rotation = 10 },
        lm.Keyframe{ .sprite = assetPath("left_2"), .rotation = -6 },
        lm.Keyframe{ .sprite = assetPath("left_1"), .rotation = 0 },
    }),
    lm.Animation.init("walk-right", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("right_1"), .rotation = 0 },
        lm.Keyframe{ .sprite = assetPath("right_2"), .rotation = -10 },
        lm.Keyframe{ .sprite = assetPath("right_2"), .rotation = 6 },
        lm.Keyframe{ .sprite = assetPath("right_1"), .rotation = 0 },
    }),
    lm.Animation.init("windup-melee", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/fallback/windup_1"), .rotation = 0, .height = 64, .width = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/fallback/windup_2"), .rotation = -18, .height = 64, .width = 80 },
    }),
    lm.Animation.init("attack-melee", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/fallback/cast_1"), .rotation = -18, .height = 64, .width = 80 },
        lm.Keyframe{ .sprite = assetPath("spells/fallback/cast_2"), .rotation = 24, .height = 64, .width = 48 },
    }),
    lm.Animation.init("winddown-melee", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/fallback/winddown_1"), .rotation = 24, .height = 64, .width = 48 },
        lm.Keyframe{ .sprite = assetPath("spells/fallback/winddown_2"), .rotation = 0, .height = 64, .width = 64 },
    }),
    lm.Animation.init("stunned", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .rotation = 25 },
        lm.Keyframe{ .rotation = 20 },
    }),
};

pub const melee_abilities = [_]Ability{
    Ability{
        .id = "lunge_dash",
        .execution_type = .mobility,
        .min_range = 120,
        .max_range = 420,
        .cooldown = 4.0,
        .mobility_profile = MobilityProfile{
            .direction = .towards_target,
            .sfx_path = "audio/sfx/dash.wav",
        },
        .windup_animation = "windup-melee",
        .release_animation = "attack-melee",
        .winddown_animation = "winddown-melee",
    },

    Ability{
        .id = "where_are_you_going",
        .execution_type = .projectile,
        .min_range = 420,
        .max_range = 620,
        .cooldown = 6,
        .projectile_profile = .{
            .damage = 0.1,
            .lifetime = 1,
            .speed = 450,
            .onhit_effect = .slow,
            .onhit_duration = 1,
            .onhit_strength = 80,
            .sfx_path = "audio/sfx/punch.mp3",
            .sprite = "projectiles/enemies/heavy.png",
        },

        .windup_animation = "windup-melee",
        .release_animation = "attack-melee",
        .winddown_animation = "winddown-melee",
    },
};

const melee_fallback = Ability{
    .id = "melee_strike",
    .execution_type = .projectile,
    .min_range = 0,
    .max_range = 120,
    .cooldown = 0.9,
    .projectile_profile = ProjectileProfile{
        .damage = 0.85,
        .damage_type = .physical,
        .speed = 1200,
        .lifetime = 0.12,
        .size = .init(48, 48),
        .knockback_strength = 0.2,
        .knockback_duration = 0.15,
        .sfx_path = "audio/sfx/punch.mp3",
    },
    .windup_animation = "windup-melee",
    .release_animation = "attack-melee",
    .winddown_animation = "winddown-melee",
};

pub fn MeleeEnemy(position: lm.Vector2) !*lm.Entity {
    defer melee_enemy_count +%= 1;

    return try lm.makeEntityI("melee-enemy", melee_enemy_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
        },
        lm.Renderer.sprite("characters/enemies/melee/left_1.png"),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
        }),
        lm.Animator.init(&melee_animations),

        Stats.init(.enemy, .{
            .health = 100,
            .attack_speed = 0.8,
            .armour = 30,
            .movement_speed = 140,
            .aggro_range = 900,
        }),
        StatusOverlays{},
        Dashing{},

        Enemy.Movement.init(.pursue),
        Enemy.Attack.init(&melee_abilities, melee_fallback),
        Enemy.Animation{},
        Enemy.Death{ .enemy_type = .melee },
        Enemy.OverheadUI{},
    });
}
