const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Attack = @import("../player/Attack.zig");
const Weapon = @import("Weapon.zig");

const Self = @This();

const HandAnimationPair = struct {
    right: []const u8,
    left: []const u8,
};

const hand_animation_names = blk: {
    var array = std.EnumArray(Weapon.WeaponType, HandAnimationPair).initUndefined();
    for (std.enums.values(Weapon.WeaponType)) |weapon_type| {
        const type_name = @tagName(weapon_type);
        array.set(weapon_type, .{
            .right = "hit-right-" ++ type_name,
            .left = "hit-left-" ++ type_name,
        });
    }
    break :blk array;
};

const HAND_ANIMATIONS = &[_]lm.Animation{
    lm.Animation.init("hit-left-close", 0.25, lm.interpolation.lerp, &[_]lm.Keyframe{
        lm.Keyframe{ .pos_x = 0, .pos_y = 0, .rotation = 0 },
        lm.Keyframe{ .pos_x = 32, .pos_y = 0, .rotation = 0 },
        lm.Keyframe{ .pos_x = 0, .pos_y = 0, .rotation = 0 },
        lm.Keyframe{ .pos_x = 0, .pos_y = 0, .rotation = 0 },
    }),
    lm.Animation.init("hit-right-close", 0.025, lm.interpolation.lerp, &[_]lm.Keyframe{
        lm.Keyframe{ .pos_x = 0, .pos_y = 0, .rotation = 0 },
        lm.Keyframe{ .pos_x = 0, .pos_y = 0, .rotation = 0 },
        lm.Keyframe{ .pos_x = 32, .pos_y = 0, .rotation = 0 },
        lm.Keyframe{ .pos_x = 0, .pos_y = 0, .rotation = 0 },
    }),
    lm.Animation.init("hit-left-wide", 0.025, lm.interpolation.lerp, &[_]lm.Keyframe{
        lm.Keyframe{ .pos_x = 0, .pos_y = 0, .rotation = 0 },
        lm.Keyframe{ .pos_x = 0, .pos_y = -32, .rotation = -30 },
        lm.Keyframe{ .pos_x = 32, .rotation = 90, .pos_y = 0 },
        lm.Keyframe{ .rotation = 0, .pos_x = 0, .pos_y = 0 },
    }),
    lm.Animation.init("hit-right-wide", 0.025, lm.interpolation.lerp, &[_]lm.Keyframe{
        lm.Keyframe{ .pos_x = 0, .pos_y = 0, .rotation = 0 },
        lm.Keyframe{ .pos_x = 0, .pos_y = 32, .rotation = 30 },
        lm.Keyframe{ .rotation = -90, .pos_x = 32, .pos_y = 0 },
        lm.Keyframe{ .rotation = 0, .pos_x = 0, .pos_y = 0 },
    }),
};

var hand_entity_index: u32 = 0;

right_hand: ?*lm.Entity = null,
left_hand: ?*lm.Entity = null,

transform: ?*lm.Transform = null,
stats: ?*Stats = null,
player_attack: ?*Attack = null,

right_hand_transform: ?*lm.Transform = null,
left_hand_transform: ?*lm.Transform = null,

left_hand_animator: ?*lm.Animator = null,
right_hand_animator: ?*lm.Animator = null,

left_hand_renderer: ?*lm.Renderer = null,
right_hand_renderer: ?*lm.Renderer = null,

last_attack_speed: f32 = -1.0,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.transform = try entity.pullComponent(lm.Transform);
    self.stats = try entity.pullComponent(Stats);
    self.player_attack = try entity.pullComponent(Attack);

    const right_hand = try makeHandEntity();
    const left_hand = try makeHandEntity();

    try lm.summoning.entities(&.{ right_hand, left_hand });

    self.right_hand = right_hand;
    self.left_hand = left_hand;
}

pub fn Start(self: *Self) !void {
    const right_hand = self.right_hand orelse return;
    const left_hand = self.left_hand orelse return;

    self.right_hand_transform = try right_hand.getComponentUnsafe(lm.Transform).unwrap();
    self.left_hand_transform = try left_hand.getComponentUnsafe(lm.Transform).unwrap();

    self.right_hand_animator = try right_hand.getComponentUnsafe(lm.Animator).unwrap();
    self.left_hand_animator = try left_hand.getComponentUnsafe(lm.Animator).unwrap();

    self.right_hand_renderer = try right_hand.getComponentUnsafe(lm.Renderer).unwrap();
    self.left_hand_renderer = try left_hand.getComponentUnsafe(lm.Renderer).unwrap();
}

pub fn Update(self: *Self) !void {
    const right_hand_transform: *lm.Transform = try lm.ensureComponent(self.right_hand_transform);
    const left_hand_transform: *lm.Transform = try lm.ensureComponent(self.left_hand_transform);

    const right_hand_animator: *lm.Animator = try lm.ensureComponent(self.right_hand_animator);
    const left_hand_animator: *lm.Animator = try lm.ensureComponent(self.left_hand_animator);

    if (right_hand_animator.display == null or left_hand_animator.display == null) return;

    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    const stats: *Stats = try lm.ensureComponent(self.stats);
    const player_attack: *Attack = try lm.ensureComponent(self.player_attack);

    self.syncAnimationLengthIfChanged(stats.current.attack_speed, right_hand_animator, left_hand_animator);

    const aim_direction = player_attack.last_aim_direction;
    const aim_angle_radians = std.math.atan2(aim_direction.y, aim_direction.x);
    const aim_angle_degrees = std.math.radiansToDegrees(aim_angle_radians);

    const right_offset_pixels = lm.Vec2(32, 16)
        .add(if (right_hand_animator.playing.len() > 0) lm.vec3ToVec2(right_hand_transform.position) else .init(0, 0))
        .rotate(aim_angle_radians);

    const left_offset_pixels = lm.Vec2(32, -16)
        .add(if (left_hand_animator.playing.len() > 0) lm.vec3ToVec2(left_hand_transform.position) else .init(0, 0))
        .rotate(aim_angle_radians);

    right_hand_transform.position = transform.position.add(lm.vec2ToVec3(right_offset_pixels));
    left_hand_transform.position = transform.position.add(lm.vec2ToVec3(left_offset_pixels));

    right_hand_transform.rotation = aim_angle_degrees - 85 + if (right_hand_animator.playing.len() > 0) right_hand_transform.rotation else 0;
    left_hand_transform.rotation = aim_angle_degrees - 95 + if (left_hand_animator.playing.len() > 0) left_hand_transform.rotation else 0;
}

pub fn End(self: *Self) void {
    if (self.right_hand) |right_hand| {
        lm.removeEntity(.{ .uuid = right_hand.uuid });
        self.right_hand = null;
    }
    if (self.left_hand) |left_hand| {
        lm.removeEntity(.{ .uuid = left_hand.uuid });
        self.left_hand = null;
    }
}

fn makeHandEntity() !*lm.Entity {
    defer hand_entity_index += 1;

    return try lm.makeEntityI("hand", hand_entity_index, .{
        lm.Transform{
            .scale = .init(48, 48),
        },
        lm.RectangleCollider.initConfig(.{
            .type = .passtrough,
            .transform = .{ .scale = .init(48, 48) },
        }),
        lm.Renderer.sprite("weapons/gloves/gloves_0.png"),
        lm.Animator.init(HAND_ANIMATIONS),
    });
}

fn syncAnimationLengthIfChanged(
    self: *Self,
    attack_speed: f32,
    right_hand_animator: *lm.Animator,
    left_hand_animator: *lm.Animator,
) void {
    if (attack_speed == self.last_attack_speed) return;
    self.last_attack_speed = attack_speed;

    const safe_attack_speed = @max(0.01, attack_speed);
    const animation_length_seconds = 0.125 * (1.0 + 4.0 / safe_attack_speed);

    for (right_hand_animator.animations.items()) |animation| {
        animation.length = animation_length_seconds;
    }
    for (left_hand_animator.animations.items()) |animation| {
        animation.length = animation_length_seconds;
    }
}

pub fn setWeapon(self: *Self, weapon: Weapon) void {
    if (self.right_hand_renderer) |renderer| renderer.img_path = weapon.sprite_right;
    if (self.left_hand_renderer) |renderer| renderer.img_path = weapon.sprite_left;
}

pub fn play(self: *Self, weapon: Weapon) !void {
    const right_hand_animator: *lm.Animator = try lm.ensureComponent(self.right_hand_animator);
    const left_hand_animator: *lm.Animator = try lm.ensureComponent(self.left_hand_animator);
    const right_hand_renderer: *lm.Renderer = try lm.ensureComponent(self.right_hand_renderer);
    const left_hand_renderer: *lm.Renderer = try lm.ensureComponent(self.left_hand_renderer);

    if (right_hand_animator.display == null or left_hand_animator.display == null) return;

    const animation_names = hand_animation_names.get(weapon.type);
    try right_hand_animator.play(animation_names.right);
    try left_hand_animator.play(animation_names.left);

    right_hand_renderer.img_path = weapon.sprite_right;
    left_hand_renderer.img_path = weapon.sprite_left;
}
