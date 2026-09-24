const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const AudioManager = @import("../../global/audio/AudioManager.zig");

const Self = @This();

var last_pickup_audio_seconds: f64 = -1.0;
const min_audio_interval_seconds: f64 = 0.045;

experience_value: usize = 1,

velocity: lm.Vector2 = .init(0, 0),
deceleration_rate: f32 = 4.0,

pickup_radius_pixels: f32 = 40.0,
max_speed_pixels_per_second: f32 = 950.0,
acceleration_pixels_per_second_squared: f32 = 2400.0,
current_speed_pixels_per_second: f32 = 120.0,

spawn_delay_seconds: f32 = 0.08,
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

    const delta_seconds = lm.time.deltaTime();

    if (self.velocity.x != 0 or self.velocity.y != 0) {
        transform.position.x += self.velocity.x * delta_seconds;
        transform.position.y += self.velocity.y * delta_seconds;

        const decay = @max(0.0, 1.0 - self.deceleration_rate * delta_seconds);
        self.velocity.x *= decay;
        self.velocity.y *= decay;
        if (self.velocity.x * self.velocity.x + self.velocity.y * self.velocity.y < 25.0) {
            self.velocity = .init(0, 0);
        }
    }

    if (self.spawn_delay_seconds > 0) {
        self.spawn_delay_seconds -= delta_seconds;
        return;
    }

    const player_transform = self.player_transform orelse return;
    const player_position = lm.vec3ToVec2(player_transform.position);
    const orb_position = lm.vec3ToVec2(transform.position);

    const delta_x = player_position.x - orb_position.x;
    const delta_y = player_position.y - orb_position.y;
    const distance_squared = delta_x * delta_x + delta_y * delta_y;
    const pickup_radius_squared = self.pickup_radius_pixels * self.pickup_radius_pixels;

    if (distance_squared <= pickup_radius_squared) {
        try self.collect(entity);
        return;
    }

    const distance = @sqrt(distance_squared);
    if (distance > 0.001) {
        const inverse_distance = 1.0 / distance;
        const direction_x = delta_x * inverse_distance;
        const direction_y = delta_y * inverse_distance;

        self.current_speed_pixels_per_second = @min(
            self.max_speed_pixels_per_second,
            self.current_speed_pixels_per_second + self.acceleration_pixels_per_second_squared * delta_seconds,
        );

        const step_distance = self.current_speed_pixels_per_second * delta_seconds;
        transform.position.x += direction_x * step_distance;
        transform.position.y += direction_y * step_distance;
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

    const current_time_seconds = lm.time.appTime();
    if (current_time_seconds - last_pickup_audio_seconds >= min_audio_interval_seconds) {
        last_pickup_audio_seconds = current_time_seconds;
        AudioManager.playSfxPitched("audio/sfx/pickup.mp3", 0.18, 0.10);
    }

    lm.removeEntity(.{ .uuid = entity.uuid });
}

pub fn onCollision(self: *lm.Entity, other: *lm.Entity) !void {
    const other_stats = other.getComponent(Stats) orelse return;
    if (other_stats.team != .player) return;

    const orb = self.getComponent(Self) orelse return;
    try orb.collect(self);
}
