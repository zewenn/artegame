const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const StatusOverlays = @import("../../components/effects/StatusOverlays.zig");
const Dashing = @import("../../components/Dashing.zig");
const Enemy = @import("../../components/enemy/export.zig");
const Ability = Enemy.Ability;
const ProjectileProfile = Enemy.Ability.ProjectileProfile;
const SpellProfile = Enemy.Ability.SpellProfile;
const KingMechanics = @import("../../components/enemy/KingMechanics.zig");
const RoomManager = @import("../../global/RoomManager.zig");
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");

var king_enemy_count: u32 = 0;

fn kingCastScalingSlow(
    enemy_entity: *lm.Entity,
    enemy_transform: *lm.Transform,
    enemy_stats: *Stats,
    player_transform: *lm.Transform,
    player_stats: ?*Stats,
) anyerror!void {
    _ = enemy_entity;
    _ = enemy_stats;

    const stats = player_stats orelse return;
    const rooms_cleared = if (RoomManager.get()) |room_manager| room_manager.rooms_cleared else 0;
    const rooms_cleared_float: f32 = @floatFromInt(rooms_cleared);
    const bonus_slow = @min(40.0, rooms_cleared_float * 2.0);
    const slow_strength = 50.0 + bonus_slow;

    stats.applySlow(slow_strength, 1.5);

    const enemy_position = lm.vec3ToVec2(enemy_transform.position);
    const player_position = lm.vec3ToVec2(player_transform.position);
    SpatialAudio.playSpatialPitched(
        "audio/sfx/punch.mp3",
        enemy_position,
        player_position,
        800.0,
        0.45,
        0.1,
    );
}

pub const king_abilities = [_]Ability{
    Ability{
        .id = "king_root",
        .execution_type = .spell,
        .min_range = 0,
        .max_range = 1000,
        .cooldown = 9.0,
        .conditions = .{
            .health_below_pct = 0.50,
        },
        .spell_profile = SpellProfile{
            .target_type = .target,
            .effect = .{
                .id = "king_root_effect",
                .effect_type = .root,
                .duration = 1.5,
            },
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-melee",
        .release_animation = "attack-melee",
        .winddown_animation = "winddown-melee",
    },

    Ability{
        .id = "king_slow",
        .execution_type = .custom,
        .min_range = 0,
        .max_range = 1000,
        .cooldown = 6.5,
        .conditions = .{
            .health_below_pct = 0.50,
        },
        .custom_action = kingCastScalingSlow,
        .windup_animation = "windup-melee",
        .release_animation = "attack-melee",
        .winddown_animation = "winddown-melee",
    },

    Ability{
        .id = "king_cleave",
        .execution_type = .projectile,
        .min_range = 0,
        .max_range = 180,
        .cooldown = 3.5,
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/heavy.png",
            .damage = 1.2,
            .damage_type = .physical,
            .speed = 700,
            .lifetime = 0.22,
            .size = .init(64, 64),
            .spread_angles = &.{ -40, -20, 0, 20, 40 },
            .knockback_strength = 0.60,
            .knockback_duration = 0.25,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-melee",
        .release_animation = "attack-melee",
        .winddown_animation = "winddown-melee",
    },
};

const king_fallback = Ability{
    .id = "king_fallback_swing",
    .execution_type = .projectile,
    .min_range = 0,
    .max_range = 140,
    .cooldown = 1.0,
    .projectile_profile = ProjectileProfile{
        .damage = 1.0,
        .damage_type = .physical,
        .speed = 650,
        .lifetime = 0.20,
        .size = .init(60, 60),
        .spread_angles = &.{ -20, 0, 20 },
        .knockback_strength = 0.40,
        .knockback_duration = 0.20,
        .sfx_path = "audio/sfx/punch.mp3",
    },
    .windup_animation = "windup-melee",
    .release_animation = "attack-melee",
    .winddown_animation = "winddown-melee",
};

pub fn KingEnemy(position: lm.Vector2) !*lm.Entity {
    defer king_enemy_count +%= 1;

    return try lm.makeEntityI("king-enemy", king_enemy_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(100, 100),
        },
        lm.Renderer.init(.{
            .img_path = "characters/enemies/melee/left_1.png",
            .tint = lm.Color{ .r = 245, .g = 180, .b = 40, .a = 255 },
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
            .transform = .{ .scale = .init(104, 104) },
            .weight = 7.0,
        }),
        lm.Animator.init(&Enemy.Animation.melee_animations),

        Stats.initUnstoppable(.enemy, .{
            .health = 3200,
            .physical_damage = 35,
            .magic_damage = 20,
            .attack_speed = 1.0,
            .armour = 75,
            .magic_resist = 45,
            .movement_speed = 130,
            .aggro_range = 1200,
        }),
        StatusOverlays{},
        Dashing{},
        KingMechanics{},

        Enemy.Movement.init(.pursue),
        Enemy.Attack.init(&king_abilities, king_fallback),
        Enemy.Animation{},
        Enemy.Death{ .enemy_type = .king },
        Enemy.OverheadUI{ .show_health_bar = false },
    });
}
