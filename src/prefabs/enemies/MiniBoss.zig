const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const StatusOverlays = @import("../../components/effects/StatusOverlays.zig");
const Dashing = @import("../../components/Dashing.zig");
const Enemy = @import("../../components/enemy/export.zig");
const Ability = Enemy.Ability;
const ProjectileProfile = Enemy.Ability.ProjectileProfile;
const MobilityProfile = Enemy.Ability.MobilityProfile;

var mini_boss_enemy_count: u32 = 0;

pub const mini_boss_abilities = [_]Ability{
    Ability{
        .id = "mini_boss_lunge",
        .execution_type = .mobility,
        .min_range = 100,
        .max_range = 500,
        .cooldown = 3.5,
        .mobility_profile = MobilityProfile{
            .direction = .towards_target,
            .sfx_path = "audio/sfx/dash.wav",
        },
        .windup_animation = "windup-melee",
        .release_animation = "attack-melee",
        .winddown_animation = "winddown-melee",
    },
    Ability{
        .id = "mini_boss_spread_volley",
        .execution_type = .projectile,
        .min_range = 140,
        .max_range = 750,
        .cooldown = 4.0,
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/heavy.png",
            .damage = 0.45,
            .damage_type = .magic,
            .speed = 380,
            .lifetime = 1.8,
            .size = .init(52, 52),
            .spread_angles = &.{ -30, -15, 0, 15, 30 },
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-melee",
        .release_animation = "attack-melee",
        .winddown_animation = "winddown-melee",
    },
};

const mini_boss_fallback = Ability{
    .id = "mini_boss_cleave",
    .execution_type = .projectile,
    .min_range = 0,
    .max_range = 100,
    .cooldown = 0.8,
    .projectile_profile = ProjectileProfile{
        .damage = 1.2,
        .damage_type = .physical,
        .speed = 520,
        .lifetime = 0.15,
        .size = .init(64, 64),
        .knockback_strength = 0.5,
        .knockback_duration = 0.25,
        .sfx_path = "audio/sfx/punch.mp3",
    },
    .windup_animation = "windup-melee",
    .release_animation = "attack-melee",
    .winddown_animation = "winddown-melee",
};

pub fn MiniBossEnemy(position: lm.Vector2) !*lm.Entity {
    defer mini_boss_enemy_count +%= 1;

    return try lm.makeEntityI("mini-boss-enemy", mini_boss_enemy_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(80, 80),
        },
        lm.Renderer.init(.{
            .img_path = "characters/enemies/melee/left_1.png",
            .tint = lm.Color{ .r = 255, .g = 80, .b = 80, .a = 255 },
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
            .transform = .{ .scale = .init(84, 84) },
            .weight = 3.0,
        }),
        lm.Animator.init(&Enemy.Animation.melee_animations),

        Stats.init(.enemy, .{
            .health = 800,
            .attack_speed = 1.0,
            .armour = 55,
            .movement_speed = 135,
            .aggro_range = 1000,
        }),
        StatusOverlays{},
        Dashing{},

        Enemy.Movement.init(.hybrid),
        Enemy.Attack.init(&mini_boss_abilities, mini_boss_fallback),
        Enemy.Animation{},
        Enemy.Death{ .enemy_type = .mini_boss },
        Enemy.OverheadUI{ .show_health_bar = false },
    });
}
