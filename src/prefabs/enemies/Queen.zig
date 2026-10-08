const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const StatusOverlays = @import("../../components/effects/StatusOverlays.zig");
const Dashing = @import("../../components/Dashing.zig");
const Enemy = @import("../../components/enemy/export.zig");
const Ability = Enemy.Ability;
const ProjectileProfile = Enemy.Ability.ProjectileProfile;
const BondOfLife = Enemy.BondOfLife;
const CombatReactions = Enemy.CombatReactions;
const QueenMechanics = @import("../../components/enemy/QueenMechanics.zig");
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");

var queen_enemy_count: u32 = 0;

fn queenCastBondOfLife(
    enemy_entity: *lm.Entity,
    enemy_transform: *lm.Transform,
    enemy_stats: *Stats,
    player_transform: *lm.Transform,
    player_stats: ?*Stats,
) anyerror!void {
    _ = enemy_stats;
    _ = player_stats;

    const scene = lm.activeScene() orelse return;
    const player = scene.getEntityById("player") orelse return;

    const applied = BondOfLife.instance.apply(enemy_entity.uuid, player, 0.10, 5.0);
    if (!applied) return;

    const enemy_position = lm.vec3ToVec2(enemy_transform.position);
    const player_position = lm.vec3ToVec2(player_transform.position);
    SpatialAudio.playSpatialPitched("audio/sfx/boom.wav", enemy_position, player_position, 800.0, 0.45, 0.15);
}

pub const queen_abilities = [_]Ability{
    Ability{
        .id = "queen_bond_apply",
        .execution_type = .custom,
        .min_range = 0,
        .max_range = 1200,
        .cooldown = 6.5,
        .conditions = .{
            .target_lacks_effect = .byType(.bond_of_life),
        },
        .custom_action = queenCastBondOfLife,
        .windup_animation = "windup-ranged",
        .release_animation = "attack-ranged",
        .winddown_animation = "winddown-ranged",
    },

    Ability{
        .id = "queen_pop_radial",
        .execution_type = .projectile,
        .min_range = 0,
        .max_range = 1200,
        .cooldown = 12.0,
        .conditions = .{
            .target_has_effect = .byType(.bond_of_life),
        },
        .root_movement_during_action = false,
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/heavy.png",
            .is_channeled = true,
            .channel_duration = 5.0,
            .channel_fire_interval = 0.10,
            .channel_rotation_speed = 36.0,
            .initial_angle = 0,
            .spread_angles = &.{ 0, 45, -45, 90, -90, 135, -135, 180 },
            .damage = 0.15,
            .damage_type = .magic,
            .speed = 750,
            .lifetime = 5.0,
            .size = .init(36, 36),
            .on_hit_callback = CombatReactions.queenBondOfLifeEarlyCancel,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .release_animation = "attack-ranged",
    },

    Ability{
        .id = "queen_pop_dash",
        .execution_type = .projectile,
        .min_range = 100,
        .max_range = 750,
        .cooldown = 8.0,
        .conditions = .{
            .target_has_effect = .byType(.bond_of_life),
        },
        .root_movement_during_action = false,
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/light.png",
            .wave_count = 3,
            .wave_interval = 0.35,
            .spread_angles = &.{ -30, -15, 0, 15, 30 },
            .damage = 0.25,
            .damage_type = .magic,
            .speed = 600,
            .lifetime = 1.0,
            .size = .init(48, 48),
            .on_hit_callback = CombatReactions.queenBondOfLifeEarlyCancel,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-ranged",
        .release_animation = "attack-ranged",
        .winddown_animation = "winddown-ranged",
    },

    Ability{
        .id = "queen_pop_sniper",
        .execution_type = .projectile,
        .min_range = 150,
        .max_range = 1200,
        .cooldown = 9.0,
        .conditions = .{
            .target_has_effect = Stats.EffectTarget.byType(.bond_of_life),
        },
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/heavy.png",
            .damage = 0.50,
            .damage_type = .magic,
            .speed = 1200,
            .lifetime = 2.0,
            .size = .init(52, 52),
            .on_hit_callback = CombatReactions.queenBondOfLifeSniperOnHit,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-ranged",
        .release_animation = "attack-ranged",
        .winddown_animation = "winddown-ranged",
    },
};

const queen_fallback = Ability{
    .id = "queen_fallback_volley",
    .execution_type = .projectile,
    .min_range = 0,
    .max_range = 1000,
    .cooldown = 1.2,
    .projectile_profile = ProjectileProfile{
        .sprite = "projectiles/enemies/light.png",
        .spread_angles = &.{ -15, 0, 15 },
        .damage = 0.30,
        .damage_type = .magic,
        .speed = 500,
        .lifetime = 2.0,
        .size = .init(36, 36),
        .sfx_path = "audio/sfx/punch.mp3",
    },
    .windup_animation = "windup-ranged",
    .release_animation = "attack-ranged",
    .winddown_animation = "winddown-ranged",
};

pub fn QueenEnemy(position: lm.Vector2) !*lm.Entity {
    defer queen_enemy_count +%= 1;

    return try lm.makeEntityI("queen-enemy", queen_enemy_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(96, 96),
        },
        lm.Renderer.init(.{
            .img_path = "characters/enemies/ranged/left_1.png",
            .tint = lm.Color{ .r = 220, .g = 60, .b = 200, .a = 255 },
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
            .transform = .{ .scale = .init(100, 100) },
            .weight = 5.0,
        }),
        lm.Animator.init(&Enemy.Animation.ranged_animations),

        Stats.initUnstoppable(.enemy, .{
            .health = 2800,
            .magic_damage = 35,
            .physical_damage = 20,
            .attack_speed = 1.2,
            .armour = 55,
            .magic_resist = 65,
            .movement_speed = 145,
            .aggro_range = 1200,
        }),
        StatusOverlays{},
        Dashing{},
        QueenMechanics{},

        Enemy.Movement.init(.kite_strafe),
        Enemy.Attack.init(&queen_abilities, queen_fallback),
        Enemy.Animation{},
        Enemy.Death{ .enemy_type = .queen },
        Enemy.OverheadUI{ .show_health_bar = false },
    });
}
