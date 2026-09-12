const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");

const Self = @This();

pub const ParabolicDefenseConfig = struct {
    inner_distance_pixels: f32 = 400.0,
    outer_distance_pixels: f32 = 1000.0,
    max_bonus_defense: f32 = 10000.0,
};

pub const DistanceDrainConfig = struct {
    inner_distance_pixels: f32 = 400.0,
    outer_distance_pixels: f32 = 1000.0,
    min_damage_per_second: f32 = 1.0,
    max_damage_per_second: f32 = 15.0,
    room_scaling_factor: f32 = 1.0,
};

pub const ProximitySlowConfig = struct {
    threshold_distance_pixels: f32 = 400.0,
    slow_strength: f32 = 60.0,
};

is_active: bool = true,
parabolic_defense: ?ParabolicDefenseConfig = null,
distance_drain: ?DistanceDrainConfig = null,
proximity_slow: ?ProximitySlowConfig = null,

applied_defense_bonus: f32 = 0.0,
is_player_slow_applied: bool = false,

stats: ?*Stats = null,
transform: ?*lm.Transform = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
}

pub fn Update(self: *Self) void {
    if (lm.time.paused()) return;
    if (!self.is_active) return;

    const stats = self.stats orelse return;
    const transform = self.transform orelse return;
    const scene = lm.activeScene() orelse return;

    const player = scene.getEntityById("player") orelse return;
    const player_transform = player.getComponent(lm.Transform) orelse return;
    const player_stats = player.getComponent(Stats) orelse return;

    const caster_position = lm.vec3ToVec2(transform.position);
    const player_position = lm.vec3ToVec2(player_transform.position);
    const distance_pixels = caster_position.distance(player_position);

    const delta_time_seconds = lm.time.deltaTime();

    self.updateParabolicDefense(stats, distance_pixels);
    self.updateDistanceDrain(stats, player_stats, distance_pixels, delta_time_seconds);
    self.updateProximitySlow(player_stats, distance_pixels);
}

pub fn End(self: *Self) void {
    if (self.stats) |stats| {
        stats.current.armour = @max(0.0, stats.current.armour - self.applied_defense_bonus);
        stats.current.magic_resist = @max(0.0, stats.current.magic_resist - self.applied_defense_bonus);
    }
    self.applied_defense_bonus = 0.0;

    if (!self.is_player_slow_applied) return;

    if (lm.getEntity(.{ .id = "player" })) |player| remove_effect: {
        const player_stats = player.getComponent(Stats) orelse break :remove_effect;

        player_stats.removeEffect(.{ .id = "proximity_aura_slow" });
    }

    self.is_player_slow_applied = false;
}

fn updateParabolicDefense(self: *Self, stats: *Stats, distance_pixels: f32) void {
    const config = self.parabolic_defense orelse return;
    const target_bonus = calculateParabolicBonus(
        config.inner_distance_pixels,
        config.outer_distance_pixels,
        config.max_bonus_defense,
        distance_pixels,
    );

    const delta_bonus = target_bonus - self.applied_defense_bonus;
    stats.current.armour += delta_bonus;
    stats.current.magic_resist += delta_bonus;
    self.applied_defense_bonus = target_bonus;
}

fn updateDistanceDrain(
    self: *Self,
    caster_stats: *Stats,
    player_stats: *Stats,
    distance_pixels: f32,
    delta_time_seconds: f32,
) void {
    const config = self.distance_drain orelse return;
    const damage_per_second = calculateDrainRate(
        config.inner_distance_pixels,
        config.outer_distance_pixels,
        config.min_damage_per_second,
        config.max_damage_per_second,
        config.room_scaling_factor,
        distance_pixels,
    );

    if (damage_per_second <= 0.0) return;

    const drain_amount = damage_per_second * delta_time_seconds;
    player_stats.current.health = @max(1.0, player_stats.current.health - drain_amount);
    caster_stats.current.health = @min(caster_stats.max.health, caster_stats.current.health + drain_amount);
}

fn updateProximitySlow(self: *Self, player_stats: *Stats, distance_pixels: f32) void {
    const config = self.proximity_slow orelse return;

    if (distance_pixels < config.threshold_distance_pixels) {
        if (!self.is_player_slow_applied) {
            player_stats.addEffect(.{
                .id = "proximity_aura_slow",
                .effect_type = .slow,
                .duration = 0.0, // Continuous until removed
                .value = config.slow_strength,
                .on_enable = struct {
                    pub fn onEnable(s: *Stats) void {
                        if (s.getEffect(.{ .id = "proximity_aura_slow" })) |effect| {
                            s.current.movement_speed = @max(10.0, s.current.movement_speed - effect.value);
                        }
                    }
                }.onEnable,
                .on_disable = struct {
                    pub fn onDisable(s: *Stats) void {
                        if (s.getEffect(.{ .id = "proximity_aura_slow" })) |effect| {
                            s.current.movement_speed += effect.value;
                        }
                    }
                }.onDisable,
            });
            self.is_player_slow_applied = true;
        }
    } else {
        if (self.is_player_slow_applied) {
            player_stats.removeEffect(.{ .id = "proximity_aura_slow" });
            self.is_player_slow_applied = false;
        }
    }
}

pub fn calculateParabolicBonus(
    inner_distance: f32,
    outer_distance: f32,
    max_bonus: f32,
    current_distance: f32,
) f32 {
    if (current_distance <= inner_distance) return 0.0;
    if (current_distance >= outer_distance) return max_bonus;

    const span = outer_distance - inner_distance;
    if (span <= 0.001) return max_bonus;

    const normalized_t = (current_distance - inner_distance) / span;
    return max_bonus * (normalized_t * normalized_t);
}

pub fn calculateDrainRate(
    inner_distance: f32,
    outer_distance: f32,
    min_rate: f32,
    max_rate: f32,
    room_scaling: f32,
    current_distance: f32,
) f32 {
    if (current_distance <= inner_distance) return 0.0;

    const span = outer_distance - inner_distance;
    if (span <= 0.001) return max_rate * room_scaling;

    const clamped_distance = @min(outer_distance, current_distance);
    const normalized_t = (clamped_distance - inner_distance) / span;
    const base_rate = min_rate + (max_rate - min_rate) * normalized_t;

    return base_rate * room_scaling;
}
