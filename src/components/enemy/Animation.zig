const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Attack = @import("Attack.zig");
const Movement = @import("Movement.zig");

const Self = @This();

pub const Facing = enum {
    left,
    right,
};

stats: ?*Stats = null,
animator: ?*lm.Animator = null,
attack: ?*Attack = null,
movement: ?*Movement = null,

facing: Facing = .left,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.animator = try entity.pullComponent(lm.Animator);
    self.attack = entity.getComponent(Attack);
    self.movement = entity.getComponent(Movement);
}

pub fn Update(self: *Self) !void {
    if (lm.time.paused()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);
    const animator: *lm.Animator = try lm.ensureComponent(self.animator);

    if (stats.isStunned() or stats.isStasis() or stats.isWeakened()) {
        stopMovementAnimations(animator);
        playSafe(animator, "stunned");
        return;
    }

    if (self.attack) |attack| {
        if (attack.isActing()) {
            stopMovementAnimations(animator);
            return;
        }
    }

    const movement = self.movement orelse return;
    const is_moving = movement.move_vector.length() > 0.05;

    if (is_moving) {
        self.facing = if (movement.move_vector.x < -0.05) .left else .right;
        playLocomotionAnimation(animator, "walk", self.facing);
        return;
    }

    playLocomotionAnimation(animator, "idle", self.facing);
}

pub fn getAnimationDuration(animator: *lm.Animator, name: []const u8) f32 {
    for (animator.animations.items()) |animation| {
        if (std.mem.eql(u8, animation.name, name)) {
            return lm.tof32(animation.length);
        }
    }
    return 0;
}

pub fn playSafe(animator: *lm.Animator, name: []const u8) void {
    animator.play(name) catch {};
}

fn stopMovementAnimations(animator: *lm.Animator) void {
    animator.stop("walk-left");
    animator.stop("walk-right");
    animator.stop("idle-left");
    animator.stop("idle-right");
}

fn playLocomotionAnimation(animator: *lm.Animator, comptime action_prefix: []const u8, facing: Facing) void {
    const target_animation = switch (facing) {
        .left => action_prefix ++ "-left",
        .right => action_prefix ++ "-right",
    };

    inline for ([_][]const u8{ "walk-left", "walk-right", "idle-left", "idle-right" }) |animation_name| {
        if (!std.mem.eql(u8, animation_name, target_animation)) {
            animator.stop(animation_name);
        }
    }
    playSafe(animator, target_animation);
}

pub const melee_animations = [_]lm.Animation{
    lm.Animation.init("idle-left", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemies/melee/left_1.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemies/melee/left_1.png", .rotation = -3 },
        lm.Keyframe{ .sprite = "characters/enemies/melee/left_1.png", .rotation = 0 },
    }),
    lm.Animation.init("idle-right", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemies/melee/right_1.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemies/melee/right_1.png", .rotation = 3 },
        lm.Keyframe{ .sprite = "characters/enemies/melee/right_1.png", .rotation = 0 },
    }),
    lm.Animation.init("walk-left", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemies/melee/left_1.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemies/melee/left_2.png", .rotation = 10 },
        lm.Keyframe{ .sprite = "characters/enemies/melee/left_1.png", .rotation = -6 },
        lm.Keyframe{ .sprite = "characters/enemies/melee/left_2.png", .rotation = 0 },
    }),
    lm.Animation.init("walk-right", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemies/melee/right_1.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemies/melee/right_2.png", .rotation = -10 },
        lm.Keyframe{ .sprite = "characters/enemies/melee/right_1.png", .rotation = 6 },
        lm.Keyframe{ .sprite = "characters/enemies/melee/right_2.png", .rotation = 0 },
    }),
    lm.Animation.init("windup-melee", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .rotation = 0, .height = 64, .width = 64 },
        lm.Keyframe{ .rotation = -18, .height = 64, .width = 80 },
    }),
    lm.Animation.init("attack-melee", 0.15, lm.interpolation.lerp, &.{
        lm.Keyframe{ .rotation = -18, .height = 64, .width = 80 },
        lm.Keyframe{ .rotation = 24, .height = 64, .width = 48 },
    }),
    lm.Animation.init("winddown-melee", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .rotation = 24, .height = 64, .width = 48 },
        lm.Keyframe{ .rotation = 0, .height = 64, .width = 64 },
    }),
    lm.Animation.init("stunned", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .rotation = 25 },
        lm.Keyframe{ .rotation = 20 },
    }),
};

pub const ranged_animations = [_]lm.Animation{
    lm.Animation.init("idle-left", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemies/ranged/left_0.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemies/ranged/left_0.png", .rotation = -2 },
        lm.Keyframe{ .sprite = "characters/enemies/ranged/left_0.png", .rotation = 0 },
    }),
    lm.Animation.init("idle-right", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemies/ranged/right_0.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemies/ranged/right_0.png", .rotation = 2 },
        lm.Keyframe{ .sprite = "characters/enemies/ranged/right_0.png", .rotation = 0 },
    }),
    lm.Animation.init("walk-left", 0.35, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemies/ranged/left_0.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemies/ranged/left_1.png", .rotation = 8 },
        lm.Keyframe{ .sprite = "characters/enemies/ranged/left_1.png", .rotation = -5 },
        lm.Keyframe{ .sprite = "characters/enemies/ranged/left_0.png", .rotation = 0 },
    }),
    lm.Animation.init("walk-right", 0.35, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemies/ranged/right_0.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemies/ranged/right_1.png", .rotation = -8 },
        lm.Keyframe{ .sprite = "characters/enemies/ranged/right_1.png", .rotation = 5 },
        lm.Keyframe{ .sprite = "characters/enemies/ranged/right_0.png", .rotation = 0 },
    }),
    lm.Animation.init("windup-ranged", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .rotation = 0, .height = 64, .width = 64 },
        lm.Keyframe{ .rotation = 12, .height = 96, .width = 48 },
    }),
    lm.Animation.init("fire-ranged", 0.125, lm.interpolation.lerp, &.{
        lm.Keyframe{ .rotation = 12, .height = 96, .width = 48 },
        lm.Keyframe{ .rotation = -14, .height = 48, .width = 86 },
    }),
    lm.Animation.init("winddown-ranged", 0.30, lm.interpolation.lerp, &.{
        lm.Keyframe{ .rotation = -14, .height = 48, .width = 86 },
        lm.Keyframe{ .rotation = 0, .height = 64, .width = 64 },
    }),
    lm.Animation.init("windup-cast", 0.3, lm.interpolation.lerp, &.{
        lm.Keyframe{ .rotation = 0 },
        lm.Keyframe{ .rotation = -6 },
        lm.Keyframe{ .rotation = 6 },
        lm.Keyframe{ .rotation = -8 },
    }),
    lm.Animation.init("cast", 0.65, lm.interpolation.lerp, &.{
        lm.Keyframe{ .rotation = -8 },
        lm.Keyframe{ .rotation = 15 },
    }),
    lm.Animation.init("winddown-cast", 0.35, lm.interpolation.lerp, &.{
        lm.Keyframe{ .rotation = 15 },
        lm.Keyframe{ .rotation = 0 },
    }),
    lm.Animation.init("stunned", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .rotation = 25 },
        lm.Keyframe{ .rotation = 20 },
    }),
};
