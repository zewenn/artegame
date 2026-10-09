const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const StatusOverlays = @import("../../components/effects/StatusOverlays.zig");
const Dashing = @import("../../components/Dashing.zig");
const Enemy = @import("../../components/enemy/export.zig");
const Ability = Enemy.Ability;
const ProjectileProfile = Enemy.Ability.ProjectileProfile;
const RoomManager = @import("../../global/RoomManager.zig");
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");
const prefabs = @import("../prefabs.zig");

var shaman_enemy_count: u32 = 0;

inline fn assetPath(path: []const u8) []const u8 {
    return "characters/enemies/shaman/" ++ path ++ ".png";
}

pub const shaman_animations = [_]lm.Animation{
    lm.Animation.init("idle-left", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("left_idle_0"), .rotation = 0, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("left_idle_1"), .rotation = 0, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("left_idle_0"), .rotation = 0, .width = 64, .height = 64 },
    }),
    lm.Animation.init("idle-right", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("right_idle_0"), .rotation = 0, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("right_idle_1"), .rotation = 0, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("right_idle_0"), .rotation = 0, .width = 64, .height = 64 },
    }),
    lm.Animation.init("walk-left", 0.35, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("left_0"), .rotation = 0, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("left_1"), .rotation = 8, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("left_1"), .rotation = -5, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("left_0"), .rotation = 0, .width = 64, .height = 64 },
    }),
    lm.Animation.init("walk-right", 0.35, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("right_0"), .rotation = 0, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("right_1"), .rotation = -8, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("right_1"), .rotation = 5, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("right_0"), .rotation = 0, .width = 64, .height = 64 },
    }),
    lm.Animation.init("windup-cast", 0.35, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/fallback/windup_1"), .rotation = 0, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/fallback/windup_2"), .rotation = -2, .width = 66, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/fallback/windup_3"), .rotation = -4, .width = 68, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/fallback/windup_4"), .rotation = -6, .width = 70, .height = 64 },
    }),
    lm.Animation.init("cast", 0.50, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/fallback/cast_1"), .rotation = -6, .width = 70, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/fallback/cast_2"), .rotation = 14, .width = 70, .height = 64 },
    }),
    lm.Animation.init("winddown-cast", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/fallback/winddown_1"), .rotation = 14, .width = 70, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/fallback/winddown_2"), .rotation = 9, .width = 68, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/fallback/winddown_3"), .rotation = 4, .width = 66, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/fallback/winddown_4"), .rotation = 0, .width = 64, .height = 64 },
    }),
    lm.Animation.init("windup-cast-call-backup", 0.35, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/call_backup/windup_1"), .rotation = 0, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/call_backup/windup_2"), .rotation = -2, .width = 66, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/call_backup/windup_3"), .rotation = -4, .width = 68, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/call_backup/windup_4"), .rotation = -6, .width = 70, .height = 64 },
    }),
    lm.Animation.init("cast-call-backup", 0.50, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/call_backup/cast_1"), .rotation = -6, .width = 70, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/call_backup/cast_2"), .rotation = 14, .width = 70, .height = 64 },
    }),
    lm.Animation.init("winddown-cast-call-backup", 0.35, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/call_backup/winddown_1"), .rotation = 14, .width = 70, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/call_backup/winddown_2"), .rotation = 11, .width = 69, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/call_backup/winddown_3"), .rotation = 8, .width = 68, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/call_backup/winddown_4"), .rotation = 5, .width = 66, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/call_backup/winddown_5"), .rotation = 2, .width = 65, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/call_backup/winddown_6"), .rotation = 0, .width = 64, .height = 64 },
    }),
    lm.Animation.init("windup-cast-remote-healing", 0.35, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/remote_healing/windup_1"), .rotation = 0, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/remote_healing/windup_2"), .rotation = -1, .width = 65, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/remote_healing/windup_3"), .rotation = -3, .width = 67, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/remote_healing/windup_4"), .rotation = -5, .width = 69, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/remote_healing/windup_5"), .rotation = -6, .width = 70, .height = 64 },
    }),
    lm.Animation.init("cast-remote-healing", 0.50, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/remote_healing/cast_1"), .rotation = -6, .width = 70, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/remote_healing/cast_2"), .rotation = 14, .width = 70, .height = 64 },
    }),
    lm.Animation.init("winddown-cast-remote-healing", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/remote_healing/winddown_1"), .rotation = 14, .width = 70, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/remote_healing/winddown_2"), .rotation = 9, .width = 68, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/remote_healing/winddown_3"), .rotation = 4, .width = 66, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/remote_healing/winddown_4"), .rotation = 0, .width = 64, .height = 64 },
    }),
    lm.Animation.init("windup-cast-speed-boost", 0.35, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/speed_boost/windup_1"), .rotation = 0, .width = 64, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/speed_boost/windup_2"), .rotation = -2, .width = 66, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/speed_boost/windup_3"), .rotation = -4, .width = 68, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/speed_boost/windup_4"), .rotation = -6, .width = 70, .height = 64 },
    }),
    lm.Animation.init("cast-speed-boost", 0.50, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/speed_boost/cast_1"), .rotation = -6, .width = 70, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/speed_boost/cast_2"), .rotation = 14, .width = 70, .height = 64 },
    }),
    lm.Animation.init("winddown-cast-speed-boost", 0.30, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("spells/speed_boost/winddown_1"), .rotation = 14, .width = 70, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/speed_boost/winddown_2"), .rotation = 10, .width = 68, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/speed_boost/winddown_3"), .rotation = 7, .width = 67, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/speed_boost/winddown_4"), .rotation = 3, .width = 65, .height = 64 },
        lm.Keyframe{ .sprite = assetPath("spells/speed_boost/winddown_5"), .rotation = 0, .width = 64, .height = 64 },
    }),
    lm.Animation.init("stunned", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = assetPath("left_idle_0"), .rotation = 20, .width = 64, .height = 64 },
    }),
};

pub fn shamanCastSpeedBoost(
    enemy_entity: *lm.Entity,
    enemy_transform: *lm.Transform,
    enemy_stats: *Stats,
    player_transform: *lm.Transform,
    player_stats: ?*Stats,
) anyerror!void {
    _ = enemy_stats;
    _ = player_stats;

    const ally_target = Enemy.SupportMechanics.findRandomLivingAlly(enemy_entity.uuid) orelse return;
    const speed_boost_pixels_per_second = lm.randFloat(f32, 80.0, 140.0);
    Enemy.SupportMechanics.applySpeedBoost(ally_target, speed_boost_pixels_per_second, 5.0);

    const caster_position = lm.vec3ToVec2(enemy_transform.position);
    const listener_position = lm.vec3ToVec2(player_transform.position);
    SpatialAudio.playSpatialPitched("audio/sfx/pickup.mp3", caster_position, listener_position, 800.0, 0.65, 0.15);
}

pub fn shamanCallBackup(
    enemy_entity: *lm.Entity,
    enemy_transform: *lm.Transform,
    enemy_stats: *Stats,
    player_transform: *lm.Transform,
    player_stats: ?*Stats,
) anyerror!void {
    _ = enemy_entity;
    _ = player_stats;

    enemy_stats.applyStasis(10.0);

    const origin_position = lm.vec3ToVec2(enemy_transform.position);
    const listener_position = lm.vec3ToVec2(player_transform.position);

    const spawn_offsets = [_]lm.Vector2{
        .init(-70.0, 0.0),
        .init(70.0, 0.0),
        .init(0.0, -70.0),
        .init(0.0, 70.0),
    };

    for (spawn_offsets) |offset| {
        const spawn_position = origin_position.add(offset);
        const elite_entity = try prefabs.enemies.Elite(spawn_position);
        try lm.summoning.entity(elite_entity);
        RoomManager.registerSummonedEnemy(elite_entity.uuid);
    }

    SpatialAudio.playSpatialPitched("audio/sfx/boom.wav", origin_position, listener_position, 900.0, 0.8, 0.2);
}

pub const shaman_abilities = [_]Ability{
    Ability{
        .id = "shaman_backup_call",
        .execution_type = .custom,
        .min_range = 0,
        .max_range = 9999,
        .cooldown = 999.0,
        .conditions = .{
            .health_below_pct = 0.25,
        },
        .custom_action = shamanCallBackup,
        .windup_animation = "windup-cast-call-backup",
        .release_animation = "cast-call-backup",
        .winddown_animation = "winddown-cast-call-backup",
    },

    Ability{
        .id = "shaman_remote_healing",
        .execution_type = .projectile,
        .min_range = 0,
        .max_range = 800,
        .cooldown = 7.0,
        .projectile_profile = ProjectileProfile{
            .sprite = "empty.png",
            .aim_mode = .absolute_world,
            .base_angle = 0,
            .spread_angles = &.{ 0, 45, 90, 135, 180, 225, 270, 315 },
            .speed = 320,
            .lifetime = 1.8,
            .size = .init(40, 40),
            .target_team = .enemy,
            .is_healing = true,
            .heal_amount = 25.0,
            .passtrough = true,
            .sfx_path = "audio/sfx/pickup.mp3",
        },
        .windup_animation = "windup-cast-remote-healing",
        .release_animation = "cast-remote-healing",
        .winddown_animation = "winddown-cast-remote-healing",
    },

    Ability{
        .id = "shaman_speed_boost",
        .execution_type = .custom,
        .min_range = 0,
        .max_range = 800,
        .cooldown = 4.5,
        .custom_action = shamanCastSpeedBoost,
        .windup_animation = "windup-cast-speed-boost",
        .release_animation = "cast-speed-boost",
        .winddown_animation = "winddown-cast-speed-boost",
    },

    Ability{
        .id = "shaman_grieving_wounds",
        .execution_type = .projectile,
        .min_range = 100,
        .max_range = 750,
        .cooldown = 12.0,
        .projectile_profile = ProjectileProfile{
            .sprite = "empty.png",
            .aim_mode = .towards_player,
            .damage = 1.4,
            .damage_type = .magic,
            .speed = 550,
            .lifetime = 1.6,
            .size = .init(32, 32),
            .target_team = .player,
            .on_hit_callback = Enemy.CombatReactions.shamanGrievingWoundsOnHit,
            .sfx_path = "audio/sfx/click.wav",
        },
        .windup_animation = "windup-cast",
        .release_animation = "cast",
        .winddown_animation = "winddown-cast",
    },
};

const shaman_fallback = Ability{
    .id = "shaman_magic_shot",
    .execution_type = .projectile,
    .min_range = 80,
    .max_range = 650,
    .cooldown = 1.4,
    .projectile_profile = ProjectileProfile{
        .sprite = "empty.png",
        .damage = 0.4,
        .damage_type = .magic,
        .speed = 360,
        .lifetime = 1.6,
        .size = .init(40, 40),
        .sfx_path = "audio/sfx/punch.mp3",
    },
    .windup_animation = "windup-cast",
    .release_animation = "cast",
    .winddown_animation = "winddown-cast",
};

pub fn ShamanEnemy(position: lm.Vector2) !*lm.Entity {
    defer shaman_enemy_count +%= 1;

    return try lm.makeEntityI("shaman-enemy", shaman_enemy_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(64, 64),
        },
        lm.Renderer.init(.{
            .img_path = assetPath("left_idle_0"),
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
            .transform = .{ .scale = .init(64, 64) },
        }),
        lm.Animator.init(&shaman_animations),

        Stats.init(.enemy, .{
            .health = 140,
            .magic_damage = 15,
            .attack_speed = 0.8,
            .armour = 10,
            .movement_speed = 125,
            .aggro_range = 850,
        }),
        StatusOverlays{},
        Dashing{},
        Enemy.ReactiveAura{
            .on_death_retaliation = .{
                .player_max_health_damage_percent = 0.20,
                .ally_physical_damage_buff_percent = 0.15,
                .ally_magic_damage_buff_percent = 0.10,
                .buff_duration_seconds = 15.0,
            },
        },

        Enemy.Movement.init(.kite_strafe),
        Enemy.Attack.init(&shaman_abilities, shaman_fallback),
        Enemy.Animation{},
        Enemy.Death{ .enemy_type = .shaman },
        Enemy.OverheadUI{},
    });
}

test "Shaman enemy creation and component configuration" {
    const shaman = try ShamanEnemy(.init(100.0, 200.0));
    defer shaman.deinit();
    try shaman.addPreparedComponents(false);

    try std.testing.expect(std.mem.startsWith(u8, shaman.id, "shaman-enemy"));
    try std.testing.expect(shaman.getComponent(Stats) != null);
    try std.testing.expect(shaman.getComponent(Enemy.ReactiveAura) != null);
    try std.testing.expect(shaman.getComponent(Enemy.Attack) != null);

    const stats = shaman.getComponent(Stats).?;
    try std.testing.expectEqual(@as(f32, 140.0), stats.max.health);
    try std.testing.expectEqual(@as(f32, 125.0), stats.current.movement_speed);
}

test "Shaman ability profiles and animations" {
    try std.testing.expectEqual(@as(usize, 4), shaman_abilities.len);
    try std.testing.expectEqual(Ability.ExecutionType.custom, shaman_abilities[0].execution_type);
    try std.testing.expectEqual(@as(f32, 0.25), shaman_abilities[0].conditions.health_below_pct.?);
    try std.testing.expectEqualStrings("windup-cast-call-backup", shaman_abilities[0].windup_animation.?);

    const healing_ability = shaman_abilities[1];
    try std.testing.expect(healing_ability.projectile_profile.?.is_healing);
    try std.testing.expectEqual(@as(usize, 8), healing_ability.projectile_profile.?.spread_angles.len);
    try std.testing.expectEqual(Stats.Teams.enemy, healing_ability.projectile_profile.?.target_team);
    try std.testing.expectEqualStrings("windup-cast-remote-healing", healing_ability.windup_animation.?);

    try std.testing.expectEqualStrings("windup-cast-speed-boost", shaman_abilities[2].windup_animation.?);
    try std.testing.expectEqualStrings("windup-cast", shaman_abilities[3].windup_animation.?);

    for (shaman_animations) |anim| {
        for (anim.base_keyframes) |keyframe| {
            try std.testing.expect(std.mem.startsWith(u8, keyframe.sprite.?, "characters/enemies/shaman/"));
            try std.testing.expect(keyframe.width.? >= 64.0);
            try std.testing.expect(keyframe.height.? >= 64.0);
        }
    }
}
