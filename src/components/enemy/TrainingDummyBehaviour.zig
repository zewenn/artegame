const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");
const TutorialManager = @import("../../global/tutorial/TutorialManager.zig");
const Projectile = @import("../../prefabs/Projectile.zig");

const Self = @This();

const BASE_SCALE_PIXELS: lm.Vector2 = .init(64.0, 64.0);
const HIT_SCALE_PIXELS: lm.Vector2 = .init(74.0, 54.0);
const FLASH_DURATION_SECONDS: f32 = 0.12;

transform: ?*lm.Transform = null,
renderer: ?*lm.Renderer = null,
stats: ?*Stats = null,

flash_timer_seconds: f32 = 0.0,
wobble_timer_seconds: f32 = 0.0,
wobble_duration_seconds: f32 = 0.18,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.transform = try entity.pullComponent(lm.Transform);
    self.renderer = entity.getComponent(lm.Renderer);
    self.stats = entity.getComponent(Stats);
}

pub fn Update(self: *Self) void {
    if (lm.time.paused()) return;

    const delta_time_seconds = lm.time.deltaTime();
    self.maintainInfiniteHealth();
    self.updateHitFlash(delta_time_seconds);
    self.updateWobble(delta_time_seconds);
}

fn maintainInfiniteHealth(self: *Self) void {
    const stats = self.stats orelse return;
    if (stats.current.health < stats.max.health) {
        stats.current.health = stats.max.health;
    }
}

fn updateHitFlash(self: *Self, delta_time_seconds: f32) void {
    const renderer = self.renderer orelse return;
    if (self.flash_timer_seconds <= 0.0) return;

    self.flash_timer_seconds -= delta_time_seconds;
    if (self.flash_timer_seconds <= 0.0) {
        self.flash_timer_seconds = 0.0;
        renderer.tint = lm.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };
    }
}

fn updateWobble(self: *Self, delta_time_seconds: f32) void {
    const transform = self.transform orelse return;
    if (self.wobble_timer_seconds <= 0.0) return;

    self.wobble_timer_seconds -= delta_time_seconds;
    if (self.wobble_timer_seconds <= 0.0) {
        self.wobble_timer_seconds = 0.0;
        transform.scale = BASE_SCALE_PIXELS;
        return;
    }

    const progress = self.wobble_timer_seconds / self.wobble_duration_seconds;
    transform.scale = lm.Vec2(
        BASE_SCALE_PIXELS.x + (HIT_SCALE_PIXELS.x - BASE_SCALE_PIXELS.x) * progress,
        BASE_SCALE_PIXELS.y + (HIT_SCALE_PIXELS.y - BASE_SCALE_PIXELS.y) * progress,
    );
}

pub fn onHit(
    self: *Self,
    attack_kind: Projectile.AttackKind,
    damage_dealt: f32,
    hit_position: lm.Vector2,
) void {
    _ = damage_dealt;
    self.maintainInfiniteHealth();
    self.triggerVisualFeedback();
    self.triggerAudioFeedback(hit_position);
    TutorialManager.notifyDummyHit(attack_kind);
}

fn triggerVisualFeedback(self: *Self) void {
    self.flash_timer_seconds = FLASH_DURATION_SECONDS;
    self.wobble_timer_seconds = self.wobble_duration_seconds;

    if (self.renderer) |renderer| {
        renderer.tint = lm.Color{ .r = 255, .g = 180, .b = 180, .a = 255 };
    }
    if (self.transform) |transform| {
        transform.scale = HIT_SCALE_PIXELS;
    }
}

fn triggerAudioFeedback(self: *Self, hit_position: lm.Vector2) void {
    _ = self;
    var listener_position = hit_position;
    if (lm.getEntity(.{ .id = "player" })) |player| {
        if (player.getComponent(lm.Transform)) |player_transform| {
            listener_position = lm.vec3ToVec2(player_transform.position);
        }
    }

    SpatialAudio.playSpatialPitched(
        "audio/sfx/punch.mp3",
        hit_position,
        listener_position,
        800.0,
        0.85,
        0.15,
    );
}
