const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");

const Self = @This();

experience_value: usize = 1,

velocity: lm.Vector2 = .init(0, 0),
deceleration: f32 = 4.0,

magnet_radius: f32 = 220.0,
pickup_radius: f32 = 28.0,

max_speed: f32 = 650.0,
acceleration: f32 = 1400.0,
current_speed: f32 = 0.0,

is_magnetized: bool = false,
spawn_delay: f32 = 0.1,
bob_timer: f32 = 0.0,
collected: bool = false,

transform: ?*lm.Transform = null,
player_transform: ?*lm.Transform = null,
player_stats: ?*Stats = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.transform = try entity.pullComponent(lm.Transform);
    self.acquirePlayer();
}

fn acquirePlayer(self: *Self) void {
    const scene = lm.activeScene() orelse return;
    const player = scene.getEntityById("player") orelse return;
    self.player_transform = player.getComponent(lm.Transform);
    self.player_stats = player.getComponent(Stats);
}

pub fn Update(self: *Self, entity: *lm.Entity) !void {
    if (lm.time.paused() or self.collected) return;

    const transform: *lm.Transform = try lm.ensureComponent(self.transform);

    if (self.player_transform == null or self.player_stats == null) {
        self.acquirePlayer();
    }

    const dt = lm.time.deltaTime();

    // Initial scatter velocity decay
    if (self.velocity.x != 0 or self.velocity.y != 0) {
        transform.position = transform.position.add(lm.vec2ToVec3(
            self.velocity.multiply(lm.time.deltaTimeVector2()),
        ));

        const decay = @max(0.0, 1.0 - self.deceleration * dt);
        self.velocity = self.velocity.multiply(.init(decay, decay));
        if (std.math.hypot(self.velocity.x, self.velocity.y) < 5.0) {
            self.velocity = .init(0, 0);
        }
    }

    if (self.spawn_delay > 0) {
        self.spawn_delay -= dt;
        return;
    }

    const player_transform = self.player_transform orelse return;
    const player_pos = lm.vec3ToVec2(player_transform.position);
    const orb_pos = lm.vec3ToVec2(transform.position);

    const distance = std.math.hypot(
        player_pos.x - orb_pos.x,
        player_pos.y - orb_pos.y,
    );

    // Magnetism attraction logic
    if (self.is_magnetized or distance <= self.magnet_radius) {
        self.is_magnetized = true;

        if (distance > 0.001) {
            const direction = player_pos.subtract(orb_pos).normalize();
            self.current_speed = @min(self.max_speed, self.current_speed + self.acceleration * dt);

            transform.position = transform.position.add(lm.vec2ToVec3(
                direction
                    .multiply(lm.time.deltaTimeVector2())
                    .multiply(.init(self.current_speed, self.current_speed)),
            ));
        }
    } else {
        // Idle gentle float bobbing when resting
        self.bob_timer += dt * 3.0;
        const bob_offset = std.math.sin(self.bob_timer) * 0.25;
        transform.position.y += bob_offset;
    }

    // Distance-based collection
    if (distance <= self.pickup_radius) {
        try self.collect(entity);
    }
}

pub fn collect(self: *Self, entity: *lm.Entity) !void {
    if (self.collected) return;
    self.collected = true;

    if (self.player_stats == null) {
        self.acquirePlayer();
    }

    if (self.player_stats) |stats| {
        stats.current.experience +%= self.experience_value;
    }

    // Audio chime on pickup
    lm.audio.playAdvanced("audio/pickup.mp3", .{
        .volume = 0.65,
        .pitch = lm.randFloat(f32, 0.95, 1.15),
    }) catch {};

    lm.removeEntity(.{ .uuid = entity.uuid });
}

pub fn onCollision(self: *lm.Entity, other: *lm.Entity) !void {
    const other_stats = other.getComponent(Stats) orelse return;
    if (other_stats.team != .player) return;

    const orb = self.getComponent(Self) orelse return;
    try orb.collect(self);
}
