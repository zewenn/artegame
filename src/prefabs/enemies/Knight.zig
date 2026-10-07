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
        mechanics.startHealChannel(5.0, 1);
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
        .windup_animation = "windup-melee",
        .release_animation = "attack-melee",
        .winddown_animation = "winddown-melee",
    },

    Ability{
        .id = "knight_weaken",
        .execution_type = .custom,
        .min_range = 0,
        .max_range = 9999,
        .cooldown = 22.0,
        .custom_action = knightCastWeaken,
        .windup_animation = "windup-melee",
        .release_animation = "attack-melee",
        .winddown_animation = "winddown-melee",
    },

    Ability{
        .id = "knight_beheading",
        .execution_type = .projectile,
        .min_range = 0,
        .max_range = 140,
        .cooldown = 7.5,
        .projectile_profile = ProjectileProfile{
            .sprite = "projectiles/enemies/heavy.png",
            .damage = 0.6,
            .damage_type = .physical,
            .speed = 1300,
            .lifetime = 0.12,
            .size = .init(64, 64),
            .onhit_effect = .stun,
            .onhit_duration = 1.5,
            .on_hit_callback = knightBeheadingOnHit,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-melee",
        .release_animation = "attack-melee",
        .winddown_animation = "winddown-melee",
    },

    Ability{
        .id = "knight_strike",
        .execution_type = .projectile,
        .min_range = 0,
        .max_range = 140,
        .cooldown = 2.2,
        .projectile_profile = ProjectileProfile{
            .damage = 1.6,
            .damage_type = .physical,
            .speed = 1200,
            .lifetime = 0.12,
            .size = .init(56, 56),
            .knockback_strength = 0.35,
            .knockback_duration = 0.2,
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .windup_animation = "windup-melee",
        .release_animation = "attack-melee",
        .winddown_animation = "winddown-melee",
    },
};

const knight_fallback = Ability{
    .id = "knight_fallback_cleave",
    .execution_type = .projectile,
    .min_range = 0,
    .max_range = 120,
    .cooldown = 1.0,
    .projectile_profile = ProjectileProfile{
        .damage = 1.0,
        .damage_type = .physical,
        .speed = 1000,
        .lifetime = 0.12,
        .size = .init(52, 52),
        .knockback_strength = 0.25,
        .knockback_duration = 0.15,
        .sfx_path = "audio/sfx/punch.mp3",
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
            .scale = .init(88, 88),
        },
        lm.Renderer.init(.{
            .img_path = "characters/enemies/melee/left_1.png",
            .tint = lm.Color{ .r = 235, .g = 195, .b = 65, .a = 255 },
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
            .transform = .{ .scale = .init(90, 90) },
            .weight = 4.0,
        }),
        lm.Animator.init(&Enemy.Animation.melee_animations),

        Stats.initUnstoppable(.enemy, .{
            .health = 1200,
            .attack_speed = 0.85,
            .armour = 60,
            .magic_resist = 35,
            .movement_speed = 120,
            .aggro_range = 1000,
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
                .inner_distance_pixels = 400.0,
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

test "Knight abilities configuration and conditions" {
    try std.testing.expectEqual(@as(usize, 4), knight_abilities.len);

    const heal_channel_ability = knight_abilities[0];
    try std.testing.expectEqual(Ability.ExecutionType.custom, heal_channel_ability.execution_type);
    try std.testing.expectEqual(@as(?f32, 0.25), heal_channel_ability.conditions.health_below_pct);

    const weaken_ability = knight_abilities[1];
    try std.testing.expectEqual(Ability.ExecutionType.custom, weaken_ability.execution_type);
    try std.testing.expectEqual(@as(f32, 22.0), weaken_ability.cooldown);

    const beheading_ability = knight_abilities[2];
    try std.testing.expectEqual(Ability.ExecutionType.projectile, beheading_ability.execution_type);
    try std.testing.expect(beheading_ability.projectile_profile.?.on_hit_callback != null);
    try std.testing.expectEqual(Enemy.Ability.OnHitEffect.stun, beheading_ability.projectile_profile.?.onhit_effect.?);

    const strike_ability = knight_abilities[3];
    try std.testing.expectEqual(Ability.ExecutionType.projectile, strike_ability.execution_type);
    try std.testing.expect(strike_ability.projectile_profile.?.damage > 1.0);
}
