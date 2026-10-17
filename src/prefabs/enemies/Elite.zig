const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const StatusOverlays = @import("../../components/effects/StatusOverlays.zig");
const Effect = @import("../../components/effects/Effect.zig");
const Dashing = @import("../../components/Dashing.zig");
const Enemy = @import("../../components/enemy/export.zig");
const Ability = Enemy.Ability;
const ProjectileProfile = Enemy.Ability.ProjectileProfile;
const SpellProfile = Enemy.Ability.SpellProfile;

var elite_enemy_count: u32 = 0;

pub const elite_animations = [_]lm.Animation{
    lm.Animation.init("idle-left", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemies/elite/left_idle_1.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemies/elite/left_idle_2.png", .rotation = -3 },
        lm.Keyframe{ .sprite = "characters/enemies/elite/left_idle_1.png", .rotation = 0 },
    }),
    lm.Animation.init("idle-right", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemies/elite/right_idle_1.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemies/elite/right_idle_2.png", .rotation = 3 },
        lm.Keyframe{ .sprite = "characters/enemies/elite/right_idle_1.png", .rotation = 0 },
    }),
    lm.Animation.init("walk-left", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemies/elite/left_1.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemies/elite/left_2.png", .rotation = 10 },
        lm.Keyframe{ .sprite = "characters/enemies/elite/left_2.png", .rotation = -6 },
        lm.Keyframe{ .sprite = "characters/enemies/elite/left_1.png", .rotation = 0 },
    }),
    lm.Animation.init("walk-right", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemies/elite/right_1.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemies/elite/right_2.png", .rotation = -10 },
        lm.Keyframe{ .sprite = "characters/enemies/elite/right_2.png", .rotation = 6 },
        lm.Keyframe{ .sprite = "characters/enemies/elite/right_1.png", .rotation = 0 },
    }),
    lm.Animation.init("windup-fallback", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .rotation = 0, .height = 64, .width = 64 },
        lm.Keyframe{ .rotation = -18, .height = 64, .width = 80 },
    }),
    lm.Animation.init("cast-fallback", 0.15, lm.interpolation.lerp, &.{
        lm.Keyframe{ .rotation = -18, .height = 64, .width = 80 },
        lm.Keyframe{ .rotation = 24, .height = 64, .width = 48 },
    }),
    lm.Animation.init("winddown-fallback", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .rotation = 24, .height = 64, .width = 48 },
        lm.Keyframe{ .rotation = 0, .height = 64, .width = 64 },
    }),
    lm.Animation.init("windup-haste", 0.3, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemies/elite/spells/haste/windup_1.png", .height = 64, .width = 64 },
        lm.Keyframe{ .sprite = "characters/enemies/elite/spells/haste/windup_2.png", .height = 70, .width = 64 },
        lm.Keyframe{ .sprite = "characters/enemies/elite/spells/haste/windup_3.png", .height = 76, .width = 64 },
    }),
    lm.Animation.init("cast-haste", 0.2, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemies/elite/spells/haste/cast.png", .height = 76, .width = 64 },
        lm.Keyframe{ .sprite = "characters/enemies/elite/spells/haste/cast.png", .height = 76, .width = 64 },
    }),
    lm.Animation.init("winddown-haste", 0.3, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemies/elite/spells/haste/winddown_1.png", .height = 76, .width = 64 },
        lm.Keyframe{ .sprite = "characters/enemies/elite/spells/haste/winddown_2.png", .height = 70, .width = 64 },
        lm.Keyframe{ .sprite = "characters/enemies/elite/spells/haste/winddown_3.png", .height = 64, .width = 64 },
    }),
    lm.Animation.init("stunned", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .rotation = 25 },
        lm.Keyframe{ .rotation = 20 },
    }),
};

fn onHasteEnable(s: *Stats) void {
    s.current.movement_speed *= 1.4;
    s.current.attack_speed *= 1.4;
}

fn onHasteDisable(s: *Stats) void {
    s.current.movement_speed /= 1.4;
    s.current.attack_speed /= 1.4;
}

pub const elite_abilities = [_]Ability{
    Ability{
        .id = "elite_enrage",
        .execution_type = .spell,
        .min_range = 0,
        .max_range = 9999,
        .cooldown = 12.0,
        .conditions = .{
            .health_below_pct = 0.50,
            .self_lacks_effect = .{ .effect_type = .haste },
        },
        .spell_profile = SpellProfile{
            .target_type = .self,
            .effect = Effect{
                .id = "elite_enrage_haste",
                .effect_type = .haste,
                .duration = 6.0,
                .time_remaining = 6.0,
                .on_enable = onHasteEnable,
                .on_disable = onHasteDisable,
            },
            .sfx_path = "audio/sfx/click.wav",
        },
        .windup_animation = "windup-haste",
        .release_animation = "cast-haste",
        .winddown_animation = "winddown-haste",
    },

    Ability{
        .id = "elite_spread_volley",
        .execution_type = .projectile,
        .min_range = 120,
        .max_range = 650,
        .cooldown = 3.2,
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/heavy.png",
            .damage = 0.35,
            .damage_type = .magic,
            .speed = 360,
            .lifetime = 1.6,
            .size = .init(48, 48),
            .wave_count = 2,
            .wave_interval = 0.4,
            .spread_angles = &.{ -20, 0, 20 },
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-fallback",
        .release_animation = "cast-fallback",
        .winddown_animation = "winddown-fallback",
    },
};

const elite_fallback = Ability{
    .id = "elite_smash",
    .execution_type = .projectile,
    .min_range = 0,
    .max_range = 85,
    .cooldown = 0.9,
    .projectile_profile = ProjectileProfile{
        .damage = 0.85,
        .damage_type = .physical,
        .speed = 480,
        .lifetime = 0.12,
        .size = .init(56, 56),
        .knockback_strength = 0.4,
        .knockback_duration = 0.2,
        .sfx_path = "audio/sfx/punch.mp3",
    },
    .windup_animation = "windup-fallback",
    .release_animation = "cast-fallback",
    .winddown_animation = "winddown-fallback",
};

pub fn EliteEnemy(position: lm.Vector2) !*lm.Entity {
    defer elite_enemy_count +%= 1;

    return try lm.makeEntityI("elite-enemy", elite_enemy_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(64, 64),
        },
        lm.Renderer.init(.{
            .img_path = "characters/enemies/elite/left_idle_1.png",
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
            .transform = .{ .scale = .init(70, 70) },
        }),
        lm.Animator.init(&elite_animations),

        Stats.init(.enemy, .{
            .health = 120,
            .magic_damage = 20,
            .attack_speed = 0.9,
            .armour = 15,
            .movement_speed = 125,
            .aggro_range = 950,
        }),
        StatusOverlays{},
        Dashing{},

        Enemy.Movement.init(.hybrid),
        Enemy.Attack.init(&elite_abilities, elite_fallback),
        Enemy.Animation{},
        Enemy.Death{ .enemy_type = .elite },
        Enemy.OverheadUI{},
    });
}
