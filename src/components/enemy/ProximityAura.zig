const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Tether = @import("Tether.zig");

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
    health_cap: f32 = 10,
    heal_percentage: f32 = 1.0,
};

pub const ProximitySlowConfig = struct {
    threshold_distance_pixels: f32 = 400.0,
    slow_strength: f32 = 60.0,
};

parabolic_defense: ?ParabolicDefenseConfig = null,
distance_drain: ?DistanceDrainConfig = null,
proximity_slow: ?ProximitySlowConfig = null,

applied_defense_bonus: f32 = 0.0,
is_player_slow_applied: bool = false,

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
tether: ?Tether = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);

    if (self.distance_drain != null) {
        self.tether = .init(
            try .load(
                "effects/drain/right.png",
                "effects/drain/left.png",
                &.{
                    "effects/drain/middle_1.png",
                    "effects/drain/middle_2.png",
                    "effects/drain/middle_3.png",
                    "effects/drain/middle_4.png",
                },
            ),
            .{},
        );
    }
}

pub fn Update(self: *Self) !void {
    if (lm.time.paused()) return;

    const stats = self.stats orelse return;
    const transform = self.transform orelse return;
    const scene = lm.activeScene() orelse return;

    const player = scene.getEntityById("player") orelse return;
    const player_transform = player.getComponent(lm.Transform) orelse return;
    const player_stats = player.getComponent(Stats) orelse return;

    const caster_position = lm.vec3ToVec2(transform.position);
    const player_position = lm.vec3ToVec2(player_transform.position);
    const distance_pixels = caster_position.distance(player_position);
    const delta_seconds = lm.time.deltaTime();

    self.updateParabolicDefense(stats, distance_pixels);
    self.updateDistanceDrain(stats, player_stats, distance_pixels, delta_seconds);
    self.updateProximitySlow(player_stats, distance_pixels);

    if (self.distance_drain != null) {
        if (self.tether) |*tether| {
            try tether.render(caster_position, player_position, distance_pixels);
        }
    }
}

pub fn End(self: *Self) void {
    if (self.tether) |*tether| {
        tether.deinit();
        self.tether = null;
    }

    if (self.stats) |stats| {
        stats.current.armour = @max(0.0, stats.current.armour - self.applied_defense_bonus);
        stats.current.magic_resist = @max(0.0, stats.current.magic_resist - self.applied_defense_bonus);
    }
    self.applied_defense_bonus = 0.0;

    if (!self.is_player_slow_applied) return;

    if (lm.getEntity(.{ .id = "player" })) |player| {
        if (player.getComponent(Stats)) |player_stats| {
            player_stats.removeEffect(.{ .id = "proximity_aura_slow" });
        }
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
    delta_seconds: f32,
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

    if (self.tether) |*tether| {
        tether.setActive(damage_per_second > 0);
    }

    if (damage_per_second <= 0.0) return;

    const drain_amount = damage_per_second * delta_seconds;
    player_stats.current.health = @max(config.health_cap, player_stats.current.health - drain_amount);
    caster_stats.current.health = @min(caster_stats.max.health, caster_stats.current.health + drain_amount * config.heal_percentage);
}

fn proximitySlowOnEnable(stats: *Stats) void {
    const effect = stats.getEffect(.{ .id = "proximity_aura_slow" }) orelse return;
    stats.current.movement_speed = @max(10.0, stats.current.movement_speed - effect.value);
}

fn proximitySlowOnDisable(stats: *Stats) void {
    const effect = stats.getEffect(.{ .id = "proximity_aura_slow" }) orelse return;
    stats.current.movement_speed += effect.value;
}

fn updateProximitySlow(self: *Self, player_stats: *Stats, distance_pixels: f32) void {
    const config = self.proximity_slow orelse return;

    if (distance_pixels >= config.threshold_distance_pixels) {
        if (!self.is_player_slow_applied) return;

        player_stats.removeEffect(.{ .id = "proximity_aura_slow" });
        self.is_player_slow_applied = false;
        return;
    }

    if (self.is_player_slow_applied) return;

    player_stats.addEffect(.{
        .id = "proximity_aura_slow",
        .effect_type = .slow,
        .duration = 0.0,
        .value = config.slow_strength,
        .on_enable = proximitySlowOnEnable,
        .on_disable = proximitySlowOnDisable,
    });
    self.is_player_slow_applied = true;
}

pub fn calculateParabolicBonus(
    inner_distance_pixels: f32,
    outer_distance_pixels: f32,
    max_bonus: f32,
    current_distance_pixels: f32,
) f32 {
    if (current_distance_pixels <= inner_distance_pixels) return 0.0;
    if (current_distance_pixels >= outer_distance_pixels) return max_bonus;

    const span_pixels = outer_distance_pixels - inner_distance_pixels;
    if (span_pixels <= 0.001) return max_bonus;

    const normalized_progress = (current_distance_pixels - inner_distance_pixels) / span_pixels;
    return max_bonus * (normalized_progress * normalized_progress);
}

pub fn calculateDrainRate(
    inner_distance_pixels: f32,
    outer_distance_pixels: f32,
    min_rate_per_second: f32,
    max_rate_per_second: f32,
    room_scaling: f32,
    current_distance_pixels: f32,
) f32 {
    if (current_distance_pixels <= inner_distance_pixels) return 0.0;

    const span_pixels = outer_distance_pixels - inner_distance_pixels;
    if (span_pixels <= 0.001) return max_rate_per_second * room_scaling;

    const clamped_distance_pixels = @min(outer_distance_pixels, current_distance_pixels);
    const normalized_progress = (clamped_distance_pixels - inner_distance_pixels) / span_pixels;
    const base_rate = min_rate_per_second + (max_rate_per_second - min_rate_per_second) * normalized_progress;

    return base_rate * room_scaling;
}
