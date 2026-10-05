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

var lifeliner_enemy_count: u32 = 0;

pub const lifeliner_animations = [_]lm.Animation{
    lm.Animation.init("idle-left", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = -3, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
    }),
    lm.Animation.init("idle-right", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 3, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
    }),
    lm.Animation.init("walk-left", 0.30, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 8, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = -5, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
    }),
    lm.Animation.init("walk-right", 0.30, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = -8, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 5, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
    }),
    lm.Animation.init("windup-cast", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = -8, .width = 56, .height = 56 },
    }),
    lm.Animation.init("cast", 0.40, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = -8, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 12, .width = 56, .height = 56 },
    }),
    lm.Animation.init("winddown-cast", 0.20, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 12, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
    }),
    lm.Animation.init("stunned", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 20, .width = 56, .height = 56 },
    }),
};

pub fn lifelinerRescue(
    enemy_entity: *lm.Entity,
    enemy_transform: *lm.Transform,
    enemy_stats: *Stats,
    player_transform: *lm.Transform,
    player_stats: ?*Stats,
) anyerror!void {
    _ = enemy_transform;
    _ = enemy_stats;
    _ = player_stats;

    const ally_target = Enemy.SupportMechanics.findLowestHealthAlly(enemy_entity.uuid, 0.10) orelse return;
    const player_position = lm.vec3ToVec2(player_transform.position);

    Enemy.SupportMechanics.executeLifelinerRescue(
        enemy_entity,
        ally_target,
        player_position,
        1000.0,
    );
}

pub fn lifelinerRevive(
    enemy_entity: *lm.Entity,
    enemy_transform: *lm.Transform,
    enemy_stats: *Stats,
    player_transform: *lm.Transform,
    player_stats: ?*Stats,
) anyerror!void {
    _ = enemy_entity;
    _ = enemy_transform;
    _ = enemy_stats;
    _ = player_transform;
    _ = player_stats;

    const room_manager = RoomManager.get() orelse return;
    _ = try Enemy.SupportMechanics.executeEnemyRevive(room_manager, room_manager.current_room);
}

pub const lifeliner_abilities = [_]Ability{
    Ability{
        .id = "lifeliner_rescue",
        .execution_type = .custom,
        .min_range = 0,
        .max_range = 9999,
        .cooldown = 3.5,
        .custom_action = lifelinerRescue,
        .windup_animation = "windup-cast",
        .release_animation = "cast",
        .winddown_animation = "winddown-cast",
    },

    Ability{
        .id = "lifeliner_revive",
        .execution_type = .custom,
        .min_range = 0,
        .max_range = 9999,
        .cooldown = 14.0,
        .custom_action = lifelinerRevive,
        .windup_animation = "windup-cast",
        .release_animation = "cast",
        .winddown_animation = "winddown-cast",
    },
};

const lifeliner_fallback = Ability{
    .id = "lifeliner_rapid_dart",
    .execution_type = .projectile,
    .min_range = 60,
    .max_range = 750,
    .cooldown = 0.5,
    .projectile_profile = ProjectileProfile{
        .sprite = "empty.png",
        .damage = 0.35,
        .damage_type = .magic,
        .speed = 520,
        .lifetime = 1.2,
        .size = .init(32, 32),
        .sfx_path = "audio/sfx/click.wav",
    },
    .windup_animation = "windup-cast",
    .release_animation = "cast",
    .winddown_animation = "winddown-cast",
};

pub fn LifelinerEnemy(position: lm.Vector2) !*lm.Entity {
    defer lifeliner_enemy_count +%= 1;

    return try lm.makeEntityI("lifeliner-enemy", lifeliner_enemy_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(56, 56),
        },
        lm.Renderer.init(.{
            .img_path = "empty.png",
            .tint = lm.Color{ .r = 60, .g = 210, .b = 255, .a = 255 },
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
            .transform = .{ .scale = .init(56, 56) },
        }),
        lm.Animator.init(&lifeliner_animations),

        Stats.init(.enemy, .{
            .health = 110,
            .magic_damage = 15,
            .attack_speed = 2.0,
            .armour = 15,
            .movement_speed = 190,
            .aggro_range = 950,
        }),
        StatusOverlays{},
        Dashing{},

        Enemy.Movement.init(.kite_strafe),
        Enemy.Attack.init(&lifeliner_abilities, lifeliner_fallback),
        Enemy.Animation{},
        Enemy.Death{ .enemy_type = .lifeliner },
        Enemy.OverheadUI{},
    });
}

test "Lifeliner enemy creation and component configuration" {
    const lifeliner = try LifelinerEnemy(.init(300.0, 400.0));
    defer lifeliner.deinit();
    try lifeliner.addPreparedComponents(false);

    try std.testing.expect(std.mem.startsWith(u8, lifeliner.id, "lifeliner-enemy"));
    try std.testing.expect(lifeliner.getComponent(Stats) != null);
    try std.testing.expect(lifeliner.getComponent(Enemy.Attack) != null);

    const stats = lifeliner.getComponent(Stats).?;
    try std.testing.expectEqual(@as(f32, 110.0), stats.max.health);
    try std.testing.expectEqual(@as(f32, 190.0), stats.current.movement_speed);
    try std.testing.expectEqual(@as(f32, 2.0), stats.current.attack_speed);
}

test "Lifeliner ability profiles and animations" {
    try std.testing.expectEqual(@as(usize, 2), lifeliner_abilities.len);
    try std.testing.expectEqual(Ability.ExecutionType.custom, lifeliner_abilities[0].execution_type);
    try std.testing.expectEqual(Ability.ExecutionType.custom, lifeliner_abilities[1].execution_type);

    for (lifeliner_animations) |anim| {
        for (anim.base_keyframes) |keyframe| {
            try std.testing.expectEqualStrings("empty.png", keyframe.sprite.?);
            try std.testing.expectEqual(@as(f32, 56.0), keyframe.width.?);
            try std.testing.expectEqual(@as(f32, 56.0), keyframe.height.?);
        }
    }
}
