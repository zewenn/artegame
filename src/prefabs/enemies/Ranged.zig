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

var ranged_enemy_count: u32 = 0;

pub const ranged_abilities = [_]Ability{
    Ability{
        .id = "escape_root",
        .execution_type = .spell,
        .min_range = 0,
        .max_range = 140,
        .cooldown = 8.0,
        .conditions = .{
            .target_lacks_effect = .{ .effect_type = .root },
        },
        .spell_profile = SpellProfile{
            .target_type = .target,
            .effect = Effect{
                .id = "enemy_root_trap",
                .effect_type = .root,
                .duration = 1.5,
                .time_remaining = 1.5,
            },
            .sfx_path = "audio/click.wav",
        },
        .windup_animation = "windup-cast",
        .release_animation = "cast",
        .winddown_animation = "winddown-cast",
    },

    Ability{
        .id = "sniper_shot",
        .execution_type = .projectile,
        .min_range = 140,
        .max_range = 650,
        .cooldown = 3.0,
        .conditions = .{
            .target_has_effect = .{ .effect_type = .root },
        },
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemy_heavy_projectile.png",
            .damage = 2,
            .damage_type = .magic,
            .speed = 460,
            .lifetime = 1.8,
            .size = .init(56, 56),
            .is_crit = true,
            .knockback_strength = 0.15,
            .knockback_duration = 0.15,
            .sfx_path = "audio/click.wav",
        },
        .windup_animation = "windup-ranged",
        .release_animation = "fire-ranged",
        .winddown_animation = "winddown-ranged",
    },
};

const ranged_fallback = Ability{
    .id = "light_shot",
    .execution_type = .projectile,
    .min_range = 100,
    .max_range = 600,
    .cooldown = 1.4,
    .projectile_profile = ProjectileProfile{
        .sprite = "projectiles/enemy_light_projectile.png",
        .damage = 1.1,
        .damage_type = .physical,
        .speed = 380,
        .lifetime = 1.6,
        .size = .init(40, 40),
        .sfx_path = "audio/click.wav",
    },
    .windup_animation = "windup-ranged",
    .release_animation = "fire-ranged",
    .winddown_animation = "winddown-ranged",
};

pub fn RangedEnemy(position: lm.Vector2) !*lm.Entity {
    defer ranged_enemy_count +%= 1;

    return try lm.makeEntityI("ranged-enemy", ranged_enemy_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
        },
        lm.Renderer.sprite("characters/enemy_ranged_left.png"),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
        }),
        lm.Animator.init(&Enemy.Animation.ranged_animations),

        Stats.init(.enemy, .{
            .health = 75,
            .attack_speed = 0.7,
            .armour = 15,
            .movement_speed = 115,
            .aggro_range = 750,
        }),
        StatusOverlays{},
        Dashing{},

        Enemy.Movement.init(.kite_strafe),
        Enemy.Attack.init(&ranged_abilities, ranged_fallback),
        Enemy.Animation{},
        Enemy.Death{},
        Enemy.OverheadUI{},
    });
}
