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
transform: ?*lm.Transform = null,
animator: ?*lm.Animator = null,
attack: ?*Attack = null,
movement: ?*Movement = null,

facing: Facing = .left,
current_anim: ?[]const u8 = null,

pub fn getAnimationDuration(animator: *lm.Animator, name: []const u8) f32 {
    for (animator.animations.items()) |anim| {
        if (std.mem.eql(u8, anim.name, name)) {
            return lm.tof32(anim.length);
        }
    }
    return 0;
}

pub fn playSafe(animator: *lm.Animator, name: []const u8) void {
    animator.play(name) catch {};
}

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
    self.animator = try entity.pullComponent(lm.Animator);
    self.attack = entity.getComponent(Attack);
    self.movement = entity.getComponent(Movement);
}

pub fn Update(self: *Self) !void {
    if (lm.time.paused()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);
    const animator: *lm.Animator = try lm.ensureComponent(self.animator);

    if (stats.isStunned() or stats.isSleeping()) {
        animator.stop("walk-left");
        animator.stop("walk-right");
        animator.stop("idle-left");
        animator.stop("idle-right");

        playSafe(animator, "stunned");
        return;
    }

    if_winding_anim_is_playing: {
        const attack = self.attack orelse break :if_winding_anim_is_playing;
        if (attack.action_state == .idle) break :if_winding_anim_is_playing;

        animator.stop("walk-left");
        animator.stop("walk-right");
        animator.stop("idle-left");
        animator.stop("idle-right");
        return;
    }

    const movement = self.movement orelse return;
    const is_moving = movement.move_vector.length() > 0.05;

    if (!is_moving) {
        animator.stop("walk-left");
        animator.stop("walk-right");

        switch (self.facing) {
            .left => {
                animator.stop("idle-right");
                playSafe(animator, "idle-left");
            },
            .right => {
                animator.stop("idle-left");
                playSafe(animator, "idle-right");
            },
        }

        return;
    }

    self.facing = switch (movement.move_vector.x < -0.05) {
        true => .left,
        false => .right,
    };

    if (self.facing == .left) {
        animator.stop("walk-right");
        animator.stop("idle-left");
        animator.stop("idle-right");

        playSafe(animator, "walk-left");
    } else {
        animator.stop("walk-left");
        animator.stop("idle-left");
        animator.stop("idle-right");

        playSafe(animator, "walk-right");
    }
}

pub const melee_animations = [_]lm.Animation{
    lm.Animation.init("idle-left", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemy_melee_left_1.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemy_melee_left_1.png", .rotation = -3 },
        lm.Keyframe{ .sprite = "characters/enemy_melee_left_1.png", .rotation = 0 },
    }),
    lm.Animation.init("idle-right", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemy_melee_right_1.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemy_melee_right_1.png", .rotation = 3 },
        lm.Keyframe{ .sprite = "characters/enemy_melee_right_1.png", .rotation = 0 },
    }),
    lm.Animation.init("walk-left", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemy_melee_left_1.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemy_melee_left_2.png", .rotation = 10 },
        lm.Keyframe{ .sprite = "characters/enemy_melee_left_1.png", .rotation = -6 },
        lm.Keyframe{ .sprite = "characters/enemy_melee_left_2.png", .rotation = 0 },
    }),
    lm.Animation.init("walk-right", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemy_melee_right_1.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemy_melee_right_2.png", .rotation = -10 },
        lm.Keyframe{ .sprite = "characters/enemy_melee_right_1.png", .rotation = 6 },
        lm.Keyframe{ .sprite = "characters/enemy_melee_right_2.png", .rotation = 0 },
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
        lm.Keyframe{ .sprite = "characters/enemy_ranged_left.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemy_ranged_left.png", .rotation = -2 },
        lm.Keyframe{ .sprite = "characters/enemy_ranged_left.png", .rotation = 0 },
    }),
    lm.Animation.init("idle-right", 0.5, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemy_ranged_right.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemy_ranged_right.png", .rotation = 2 },
        lm.Keyframe{ .sprite = "characters/enemy_ranged_right.png", .rotation = 0 },
    }),
    lm.Animation.init("walk-left", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemy_ranged_left.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemy_ranged_left.png", .rotation = 8 },
        lm.Keyframe{ .sprite = "characters/enemy_ranged_left.png", .rotation = -5 },
        lm.Keyframe{ .sprite = "characters/enemy_ranged_left.png", .rotation = 0 },
    }),
    lm.Animation.init("walk-right", 0.25, lm.interpolation.lerp, &.{
        lm.Keyframe{ .sprite = "characters/enemy_ranged_right.png", .rotation = 0 },
        lm.Keyframe{ .sprite = "characters/enemy_ranged_right.png", .rotation = -8 },
        lm.Keyframe{ .sprite = "characters/enemy_ranged_right.png", .rotation = 5 },
        lm.Keyframe{ .sprite = "characters/enemy_ranged_right.png", .rotation = 0 },
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
