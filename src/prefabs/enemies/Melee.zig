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

var melee_abilities = [_]Ability{
    Ability{
        .id = "lunge_dash",
        .execution_type = .mobility,
        .min_range = 120,
        .max_range = 220,
        .cooldown = 4.0,
        .mobility_profile = MobilityProfile{
            .direction = .towards_target,
            .sfx_path = "audio/dash.wav",
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
    .max_range = 80,
    .cooldown = 0.9,
    .projectile_profile = ProjectileProfile{
        .damage = 0.65,
        .damage_type = .physical,
        .speed = 450,
        .lifetime = 0.12,
        .size = .init(48, 48),
        .knockback_strength = 0.2,
        .knockback_duration = 0.15,
        .sfx_path = "audio/punch.mp3",
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
        lm.Renderer.sprite("characters/enemy_melee_left_1.png"),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
        }),
        lm.Animator.init(&Enemy.Animation.melee_animations),

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
        Enemy.Death{},
        Enemy.OverheadUI{},
    });
}
