const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Weapon = @import("Weapon.zig");

const Self = @This();

const BASE_ANIM_LENGTH: comptime_float = 0.25;

fn Hand() !lm.Prefab {
    return try lm.prefab("hand", .{
        lm.Transform{
            .scale = .init(48, 48),
        },

        lm.Renderer.sprite("gloves_0.png"),
        lm.Animator.init(&.{
            lm.Animation.init("hit-left-close", BASE_ANIM_LENGTH, lm.interpolation.lerp, &.{
                lm.Keyframe{
                    .pos_x = 0,
                    .pos_y = 0,
                    .rotation = 0,
                },
                lm.Keyframe{
                    .pos_x = 32,
                    .pos_y = 0,
                    .rotation = 0,
                },
                lm.Keyframe{
                    .pos_x = 0,
                    .pos_y = 0,
                    .rotation = 0,
                },
                lm.Keyframe{
                    .pos_x = 0,
                    .pos_y = 0,
                    .rotation = 0,
                },
            }),
            lm.Animation.init("hit-right-close", BASE_ANIM_LENGTH, lm.interpolation.lerp, &.{
                lm.Keyframe{
                    .pos_x = 0,
                    .pos_y = 0,
                    .rotation = 0,
                },
                lm.Keyframe{
                    .pos_x = 0,
                    .pos_y = 0,
                    .rotation = 0,
                },
                lm.Keyframe{
                    .pos_x = 32,
                    .pos_y = 0,
                    .rotation = 0,
                },
                lm.Keyframe{
                    .pos_x = 0,
                    .pos_y = 0,
                    .rotation = 0,
                },
            }),
            lm.Animation.init("hit-left-wide", BASE_ANIM_LENGTH, lm.interpolation.lerp, &.{
                lm.Keyframe{
                    .pos_x = 0,
                    .pos_y = 0,
                    .rotation = 0,
                },
                lm.Keyframe{
                    .pos_x = 0,
                    .pos_y = -32,
                    .rotation = -30,
                },
                lm.Keyframe{
                    .pos_x = 32,
                    .rotation = 90,
                    .pos_y = 0,
                },
                lm.Keyframe{
                    .rotation = 0,
                    .pos_x = 0,
                    .pos_y = 0,
                },
            }),
            lm.Animation.init("hit-right-wide", BASE_ANIM_LENGTH, lm.interpolation.lerp, &.{
                lm.Keyframe{
                    .pos_x = 0,
                    .pos_y = 0,
                    .rotation = 0,
                },
                lm.Keyframe{
                    .pos_x = 0,
                    .pos_y = 32,
                    .rotation = 30,
                },
                lm.Keyframe{
                    .rotation = -90,
                    .pos_x = 32,
                    .pos_y = 0,
                },
                lm.Keyframe{
                    .rotation = 0,
                    .pos_x = 0,
                    .pos_y = 0,
                },
            }),
        }),
    });
}

right_hand: ?*lm.Entity = null,
left_hand: ?*lm.Entity = null,

transform: ?*lm.Transform = null,
stats: ?*Stats = null,

right_hand_transfrom: ?*lm.Transform = null,
left_hand_transfrom: ?*lm.Transform = null,

left_hand_animator: ?*lm.Animator = null,
right_hand_animator: ?*lm.Animator = null,

left_hand_renderer: ?*lm.Renderer = null,
right_hand_renderer: ?*lm.Renderer = null,

camera: ?*lm.Camera = null,

last_input: enum { gamepad, mouse } = .mouse,
last_mouse: lm.Vector2 = .init(0, 0),

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.transform = try entity.pullComponent(lm.Transform);
    self.stats = try entity.pullComponent(Stats);
    self.camera = lm.activeScene().?.getCamera("main");
}

pub fn Start(self: *Self) !void {
    const right_hand = try (try Hand()).makeInstance();
    const left_hand = try (try Hand()).makeInstance();

    try lm.summon(&.{
        .{ .entity = right_hand },
        .{ .entity = left_hand },
    });

    self.right_hand = right_hand;
    self.left_hand = left_hand;

    self.right_hand_transfrom = try right_hand.getComponentUnsafe(lm.Transform).unwrap();
    self.left_hand_transfrom = try left_hand.getComponentUnsafe(lm.Transform).unwrap();

    self.right_hand_animator = try right_hand.getComponentUnsafe(lm.Animator).unwrap();
    self.left_hand_animator = try left_hand.getComponentUnsafe(lm.Animator).unwrap();

    self.right_hand_renderer = try right_hand.getComponentUnsafe(lm.Renderer).unwrap();
    self.left_hand_renderer = try left_hand.getComponentUnsafe(lm.Renderer).unwrap();
}

pub fn Update(self: *Self) !void {
    const right_hand_transform: *lm.Transform = try lm.ensureComponent(self.right_hand_transfrom);
    const left_hand_transform: *lm.Transform = try lm.ensureComponent(self.left_hand_transfrom);

    const right_hand_animator: *lm.Animator = try lm.ensureComponent(self.right_hand_animator);
    const left_hand_animator: *lm.Animator = try lm.ensureComponent(self.left_hand_animator);

    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const stats: *Stats = try lm.ensureComponent(self.stats);
    const camera: *lm.Camera = try lm.ensureComponent(self.camera);

    for (right_hand_animator.animations.items()) |anim| {
        anim.length = 1.25 * (1 + 4 / stats.current.attack_speed);
    }
    for (left_hand_animator.animations.items()) |anim| {
        anim.length = 1.25 * (1 + 4 / stats.current.attack_speed);
    }

    // right_hand_transform.position = transform.position.add(.init(32, 32, 10));
    // left_hand_transform.position = transform.position.subtract(.init(32, -32, 10));

    const mouse_position = camera.screenToWorldPos(lm.mouse.getPosition());

    const angle_vec = get_angle_vetor: {
        const mouse = mouse_position.subtract(lm.vec3ToVec2(transform.position)).normalize();
        defer self.last_mouse = mouse;

        if (!lm.gamepad.isAvailable(0)) break :get_angle_vetor mouse;

        const gamepad = lm.gamepad.getStickVector(0, .right, 0.1);
        if (gamepad.length() == 0) break :get_angle_vetor mouse;

        break :get_angle_vetor gamepad.normalize();
    };
    const angle = std.math.atan2(angle_vec.y, angle_vec.x);

    const right_vector = lm.Vec2(32, 16)
        .add(if (right_hand_animator.playing.len() > 0) lm.vec3ToVec2(right_hand_transform.position) else .init(0, 0))
        .rotate(angle);

    const left_vector = lm.Vec2(32, -16)
        .add(if (left_hand_animator.playing.len() > 0) lm.vec3ToVec2(left_hand_transform.position) else .init(0, 0))
        .rotate(angle);

    right_hand_transform.position = transform.position.add(lm.vec2ToVec3(right_vector));
    left_hand_transform.position = transform.position.add(lm.vec2ToVec3(left_vector));

    right_hand_transform.rotation = std.math.radiansToDegrees(angle) - 85 + if (right_hand_animator.playing.len() > 0) right_hand_transform.rotation else 0;
    left_hand_transform.rotation = std.math.radiansToDegrees(angle) - 95 + if (left_hand_animator.playing.len() > 0) left_hand_transform.rotation else 0;
}

fn aroundEquals(vec: lm.Vector2, other: lm.Vector2) bool {
    return vec.x > -2 + other.x and
        vec.x < 2 + other.x and
        vec.y > -2 + other.y and
        vec.y < 2 + other.y;
}

pub fn play(self: *Self, weapon: Weapon) !void {
    const right_hand_animator: *lm.Animator = try lm.ensureComponent(self.right_hand_animator);
    const left_hand_animator: *lm.Animator = try lm.ensureComponent(self.left_hand_animator);
    const right_hand_renderer: *lm.Renderer = try lm.ensureComponent(self.right_hand_renderer);
    const left_hand_renderer: *lm.Renderer = try lm.ensureComponent(self.left_hand_renderer);

    switch (weapon.type) {
        .close => {
            try right_hand_animator.play("hit-right-close");
            try left_hand_animator.play("hit-left-close");
        },
        .wide => {
            try right_hand_animator.play("hit-right-wide");
            try left_hand_animator.play("hit-left-wide");
        },
    }

    right_hand_renderer.img_path = weapon.sprite_right;
    left_hand_renderer.img_path = weapon.sprite_left;
}
