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
            .sfx_path = "audio/click.wav",
        },
        .windup_animation = "windup-melee",
        .release_animation = "attack-melee",
        .winddown_animation = "winddown-melee",
    },

    Ability{
        .id = "elite_spread_volley",
        .execution_type = .projectile,
        .min_range = 120,
        .max_range = 650,
        .cooldown = 3.2,
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemy_heavy_projectile.png",
            .damage = 0.35,
            .damage_type = .magic,
            .speed = 360,
            .lifetime = 1.6,
            .size = .init(48, 48),
            .spread_angles = &.{ -20, 0, 20 },
            .sfx_path = "audio/punch.mp3",
        },
        .windup_animation = "windup-melee",
        .release_animation = "attack-melee",
        .winddown_animation = "winddown-melee",
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
        .sfx_path = "audio/punch.mp3",
    },
    .windup_animation = "windup-melee",
    .release_animation = "attack-melee",
    .winddown_animation = "winddown-melee",
};

pub fn EliteEnemy(position: lm.Vector2) !*lm.Entity {
    defer elite_enemy_count +%= 1;

    return try lm.makeEntityI("elite-enemy", elite_enemy_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(64, 64),
        },
        lm.Renderer.init(.{
            .img_path = "characters/enemy_melee_left_1.png",
            .tint = lm.Color{ .r = 255, .g = 210, .b = 60, .a = 255 },
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
            .transform = .{ .scale = .init(70, 70) },
        }),
        lm.Animator.init(&Enemy.Animation.melee_animations),

        Stats.init(.enemy, .{
            .health = 260,
            .attack_speed = 0.9,
            .armour = 45,
            .movement_speed = 125,
            .aggro_range = 950,
        }),
        StatusOverlays{},
        Dashing{},

        Enemy.Movement.init(.hybrid),
        Enemy.Attack.init(&elite_abilities, elite_fallback),
        Enemy.Animation{},
        Enemy.Death{},
        Enemy.OverheadUI{},
    });
}
