const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");

const Self = @This();

pub const WeakenState = enum {
    ready,
    weakened,
};

stats: ?*Stats = null,
transform: ?*lm.Transform = null,

weaken_state: WeakenState = .ready,
weaken_timer_seconds: f32 = 0.0,
weaken_prior_armour: f32 = 0.0,
weaken_prior_magic_resist: f32 = 0.0,

heal_channel_active: bool = false,
heal_channel_used: bool = false,
heal_channel_duration_seconds: f32 = 5.0,
heal_channel_timer_seconds: f32 = 0.0,
heal_rate_percent_per_second: f32 = 0.05,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
}

pub fn Update(self: *Self) void {
    if (lm.time.paused()) return;

    const delta_seconds = lm.time.deltaTime();

    self.updateWeaken(delta_seconds);
    self.updateHealChannel(delta_seconds);
}

fn updateWeaken(self: *Self, delta_seconds: f32) void {
    if (self.weaken_state != .weakened) return;

    self.weaken_timer_seconds -= delta_seconds;
    if (self.weaken_timer_seconds <= 0.0) {
        self.endWeaken();
    }
}

fn updateHealChannel(self: *Self, delta_seconds: f32) void {
    if (!self.heal_channel_active) return;

    const stats = self.stats orelse return;

    const heal_amount = stats.max.health * self.heal_rate_percent_per_second * delta_seconds;
    stats.current.health = @min(stats.max.health, stats.current.health + heal_amount);

    self.heal_channel_timer_seconds -= delta_seconds;
    if (self.heal_channel_timer_seconds <= 0.0) {
        self.endHealChannel();
    }
}

pub fn startWeaken(self: *Self, duration_seconds: f32) void {
    if (self.weaken_state == .weakened) return;

    const stats = self.stats orelse return;

    self.weaken_state = .weakened;
    self.weaken_timer_seconds = duration_seconds;
    self.weaken_prior_armour = stats.base.armour;
    self.weaken_prior_magic_resist = stats.base.magic_resist;

    stats.current.armour = self.weaken_prior_armour * 0.5;
    stats.current.magic_resist = self.weaken_prior_magic_resist * 0.5;
    stats.applyStun(duration_seconds);

    self.playWeakenFeedbackAudio();
}

pub fn endWeaken(self: *Self) void {
    self.weaken_state = .ready;
    self.weaken_timer_seconds = 0.0;

    const stats = self.stats orelse return;

    const bonus_defense: f32 = 15.0;
    stats.base.armour = self.weaken_prior_armour + bonus_defense;
    stats.base.magic_resist = self.weaken_prior_magic_resist + bonus_defense;
    stats.current.armour = stats.base.armour;
    stats.current.magic_resist = stats.base.magic_resist;

    self.playRecoverFeedbackAudio();
}

pub fn startHealChannel(self: *Self, duration_seconds: f32, round: u32) void {
    if (self.heal_channel_used) return;

    const stats = self.stats orelse return;

    self.heal_channel_used = true;
    self.heal_channel_active = true;
    self.heal_channel_duration_seconds = duration_seconds;
    self.heal_channel_timer_seconds = duration_seconds;

    const base_heal_rate: f32 = 0.05;
    const round_scaling_bonus: f32 = @as(f32, @floatFromInt(round)) * 0.005;
    self.heal_rate_percent_per_second = base_heal_rate + round_scaling_bonus;

    stats.applyStun(duration_seconds);

    self.playHealStartFeedbackAudio();
}

pub fn endHealChannel(self: *Self) void {
    self.heal_channel_active = false;
    self.heal_channel_timer_seconds = 0.0;

    const stats = self.stats orelse return;
    stats.removeEffect(.{ .effect_type = .stun });
}

fn playWeakenFeedbackAudio(self: *Self) void {
    const transform = self.transform orelse return;
    const caster_position = lm.vec3ToVec2(transform.position);
    SpatialAudio.playSpatialPitched("audio/sfx/punch.mp3", caster_position, caster_position, 800.0, 0.70, 0.15);
}

fn playRecoverFeedbackAudio(self: *Self) void {
    const transform = self.transform orelse return;
    const caster_position = lm.vec3ToVec2(transform.position);
    SpatialAudio.playSpatialPitched("audio/sfx/coin.wav", caster_position, caster_position, 800.0, 0.85, 0.10);
}

fn playHealStartFeedbackAudio(self: *Self) void {
    const transform = self.transform orelse return;
    const caster_position = lm.vec3ToVec2(transform.position);
    SpatialAudio.playSpatialPitched("audio/sfx/pickup.mp3", caster_position, caster_position, 800.0, 0.80, 0.15);
}

test "KnightMechanics Weaken lifecycle halves defenses and restores with +15 bonus" {
    var stats = Stats.init(.enemy, .{
        .health = 1000.0,
        .armour = 60.0,
        .magic_resist = 40.0,
    });
    defer stats.deinit();

    var mechanics = Self{
        .stats = &stats,
    };

    try std.testing.expectEqual(WeakenState.ready, mechanics.weaken_state);
    try std.testing.expectEqual(@as(f32, 60.0), stats.current.armour);
    try std.testing.expectEqual(@as(f32, 40.0), stats.current.magic_resist);

    mechanics.startWeaken(4.0);
    try std.testing.expectEqual(WeakenState.weakened, mechanics.weaken_state);
    try std.testing.expectEqual(@as(f32, 30.0), stats.current.armour);
    try std.testing.expectEqual(@as(f32, 20.0), stats.current.magic_resist);
    try std.testing.expect(stats.isStunned());

    mechanics.endWeaken();
    try std.testing.expectEqual(WeakenState.ready, mechanics.weaken_state);
    try std.testing.expectEqual(@as(f32, 75.0), stats.current.armour);
    try std.testing.expectEqual(@as(f32, 55.0), stats.current.magic_resist);
    try std.testing.expectEqual(@as(f32, 75.0), stats.base.armour);
    try std.testing.expectEqual(@as(f32, 55.0), stats.base.magic_resist);
}

test "KnightMechanics low-HP heal channel restores health over time" {
    var stats = Stats.init(.enemy, .{
        .health = 1000.0,
    });
    defer stats.deinit();

    stats.current.health = 200.0;

    var mechanics = Self{
        .stats = &stats,
    };

    mechanics.startHealChannel(5.0, 5);
    try std.testing.expect(mechanics.heal_channel_active);
    try std.testing.expect(mechanics.heal_channel_used);
    try std.testing.expect(stats.isStunned());

    const delta_seconds: f32 = 1.0;
    mechanics.updateHealChannel(delta_seconds);

    // Rate = 0.05 + 5 * 0.005 = 0.075 * 1000 = 75 HP restored per second
    try std.testing.expectApproxEqAbs(@as(f32, 275.0), stats.current.health, 0.01);

    mechanics.endHealChannel();
    try std.testing.expect(!mechanics.heal_channel_active);
}
