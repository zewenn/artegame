const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const StatusOverlays = @import("../../components/effects/StatusOverlays.zig");
const Dashing = @import("../../components/Dashing.zig");
const Enemy = @import("../../components/enemy/export.zig");
const Ability = Enemy.Ability;
const ProjectileProfile = Enemy.Ability.ProjectileProfile;

var angler_enemy_count: u32 = 0;

pub const angler_animations = [_]lm.Animation{
    lm.Animation.init("idle-left", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = -2, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
    }),
    lm.Animation.init("idle-right", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 2, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
    }),
    lm.Animation.init("walk-left", 0.35, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 8, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = -5, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
    }),
    lm.Animation.init("walk-right", 0.35, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = -8, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 5, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
    }),
    lm.Animation.init("fire-cardinal", 0.10, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 4, .width = 56, .height = 56 },
        lm.Keyframe{ .sprite = "empty.png", .rotation = 0, .width = 56, .height = 56 },
    }),
    lm.Animation.init("stunned", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "empty.png", .rotation = 20, .width = 56, .height = 56 },
    }),
};

pub const angler_abilities = [_]Ability{
    Ability{
        .id = "angler_cardinal_rapid",
        .execution_type = .projectile,
        .min_range = 0,
        .max_range = 800,
        .cooldown = 0.10,
        .root_movement_during_action = false,
        .projectile_profile = ProjectileProfile{
            .sprite = "empty.png",
            .aim_mode = .absolute_world,
            .base_angle = 0,
            .spread_angles = &.{ 0, 90, -90, 180 },
            .damage = 0.10,
            .damage_type = .physical,
            .speed = 360,
            .lifetime = 1.8,
            .size = .init(32, 32),
            .sfx_path = "audio/sfx/punch.mp3",
        },
        .release_animation = "fire-cardinal",
    },
};

const angler_fallback = Ability{
    .id = "angler_cardinal_fallback",
    .execution_type = .projectile,
    .min_range = 0,
    .max_range = 800,
    .cooldown = 0.10,
    .root_movement_during_action = false,
    .projectile_profile = ProjectileProfile{
        .sprite = "empty.png",
        .aim_mode = .absolute_world,
        .base_angle = 0,
        .spread_angles = &.{ 0, 90, -90, 180 },
        .damage = 0.10,
        .damage_type = .physical,
        .speed = 360,
        .lifetime = 1.8,
        .size = .init(32, 32),
        .sfx_path = "audio/sfx/punch.mp3",
    },
    .release_animation = "fire-cardinal",
};

pub fn AnglerEnemy(position: lm.Vector2) !*lm.Entity {
    defer angler_enemy_count +%= 1;

    return try lm.makeEntityI("angler-enemy", angler_enemy_count, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(56, 56),
        },
        lm.Renderer.init(.{
            .img_path = "empty.png",
            .tint = lm.Color{ .r = 255, .g = 200, .b = 40, .a = 255 },
        }),
        lm.RectangleCollider.initConfig(.{
            .type = .dynamic,
            .transform = .{ .scale = .init(56, 56) },
        }),
        lm.Animator.init(&angler_animations),

        Stats.init(.enemy, .{
            .health = 220,
            .attack_speed = 10.0,
            .armour = 20,
            .movement_speed = 110,
            .aggro_range = 900,
        }),
        StatusOverlays{},
        Dashing{},

        Enemy.Movement.init(.hybrid),
        Enemy.Attack.init(&angler_abilities, angler_fallback),
        Enemy.Animation{},
        Enemy.Death{ .enemy_type = .angler },
    });
}

test "Angler enemy creation and component configuration" {
    const angler = try AnglerEnemy(.init(200.0, 300.0));
    defer angler.deinit();
    try angler.addPreparedComponents(false);

    try std.testing.expect(std.mem.startsWith(u8, angler.id, "angler-enemy"));
    try std.testing.expect(angler.getComponent(Stats) != null);
    try std.testing.expect(angler.getComponent(Enemy.Attack) != null);

    const stats = angler.getComponent(Stats).?;
    try std.testing.expectEqual(@as(f32, 220.0), stats.max.health);
    try std.testing.expectEqual(@as(f32, 10.0), stats.current.attack_speed);
}

test "Angler rapid cardinal fire profile and animations" {
    try std.testing.expectEqual(@as(usize, 1), angler_abilities.len);

    const cardinal_shot = angler_abilities[0];
    try std.testing.expectEqual(Ability.AimMode.absolute_world, cardinal_shot.projectile_profile.?.aim_mode);
    try std.testing.expectEqual(@as(usize, 4), cardinal_shot.projectile_profile.?.spread_angles.len);
    try std.testing.expectEqual(@as(f32, 0.10), cardinal_shot.cooldown);
    try std.testing.expect(cardinal_shot.projectile_profile.?.damage <= 10.0);

    for (angler_animations) |anim| {
        for (anim.base_keyframes) |keyframe| {
            try std.testing.expectEqualStrings("empty.png", keyframe.sprite.?);
            try std.testing.expectEqual(@as(f32, 56.0), keyframe.width.?);
            try std.testing.expectEqual(@as(f32, 56.0), keyframe.height.?);
        }
    }
}
