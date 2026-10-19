const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");

const Self = @This();

const TETHER_BUILD_TIME: comptime_float = 0.15;

const Textures = struct {
    drain_right: ?*lm.Texture,
    drain_middle: ?*lm.Texture,
    drain_left: ?*lm.Texture,

    pub fn load() Textures {
        return Textures{
            .drain_right = lm.assets.texture.get("effects/drain/right.png", &.{ 64, 64 }),
            .drain_middle = lm.assets.texture.get("effects/drain/middle.png", &.{ 64, 64 }),
            .drain_left = lm.assets.texture.get("effects/drain/left.png", &.{ 64, 64 }),
        };
    }

    pub fn unload(self: Textures) void {
        if (self.drain_right) |drain_right| lm.assets.texture.releasePtr(drain_right);
        if (self.drain_middle) |drain_middle| lm.assets.texture.releasePtr(drain_middle);
        if (self.drain_left) |drain_left| lm.assets.texture.releasePtr(drain_left);
    }
};

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

is_active: bool = true,
parabolic_defense: ?ParabolicDefenseConfig = null,
distance_drain: ?DistanceDrainConfig = null,
proximity_slow: ?ProximitySlowConfig = null,

applied_defense_bonus: f32 = 0.0,
is_player_slow_applied: bool = false,

stats: ?*Stats = null,
transform: ?*lm.Transform = null,

textures: ?Textures = null,
is_draining: bool = false,
tether_anim_start: f32 = 0,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
    self.textures = .load();
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

    self.renderDrainTether(caster_position, player_position, distance_pixels) catch {
        std.log.err("failed to render drain tether", .{});
    };
}

pub fn End(self: *Self) void {
    if (self.textures) |textures| textures.unload();

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

    const previous_state = self.is_draining;
    self.is_draining = damage_per_second > 0;

    if (previous_state != self.is_draining) {
        self.tether_anim_start = lm.time.gameTime();
    }

    if (damage_per_second <= 0.0) return;

    const drain_amount = damage_per_second * delta_time_seconds;
    player_stats.current.health = @max(config.health_cap, player_stats.current.health - drain_amount);
    caster_stats.current.health = @min(caster_stats.max.health, caster_stats.current.health + drain_amount * config.heal_percentage);
}

fn updateProximitySlow(self: *Self, player_stats: *Stats, distance_pixels: f32) void {
    const config = self.proximity_slow orelse return;

    if (distance_pixels >= config.threshold_distance_pixels) if (self.is_player_slow_applied) {
        player_stats.removeEffect(.{ .id = "proximity_aura_slow" });
        self.is_player_slow_applied = false;
        return;
    };

    if (self.is_player_slow_applied) return;

    player_stats.addEffect(.{
        .id = "proximity_aura_slow",
        .effect_type = .slow,
        .duration = 0.0,
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

fn renderDrainTether(self: *Self, start: lm.Vector2, end: lm.Vector2, distance: f32) !void {
    const textures = self.textures orelse return;
    const anim_percent = @min(1, (lm.time.gameTime() - self.tether_anim_start) / TETHER_BUILD_TIME);

    if (anim_percent == 1 and !self.is_draining) return;

    const start_vector = if (self.is_draining) start else start.lerp(end, anim_percent);
    const end_vector = if (self.is_draining) start.lerp(end, anim_percent) else end;

    const current_distance = if (self.is_draining) distance * anim_percent else distance * (1.0 - anim_percent);

    const base_vector = lm.Vec2(1, 0);
    const delta_vector = end.subtract(start);
    const angle = std.math.radiansToDegrees(base_vector.angle(delta_vector));

    const middle_point = start_vector.lerp(end_vector, 0.5);
    const middle_width = @max(0.0, current_distance - 64.0);

    if (textures.drain_left) |drain_left|
        try lm.display.add(.{
            .texture = drain_left.*,
            .transform = .{
                .position = .init(start_vector.x, start_vector.y, -100),
                .rotation = angle,
            },
            .display = .{
                .fill_color = null,
                .img_path = "",
                .tint = lm.Color.white,
            },
        });

    if (textures.drain_right) |drain_right|
        try lm.display.add(.{
            .texture = drain_right.*,
            .transform = .{
                .position = .init(end_vector.x, end_vector.y, -100),
                .rotation = angle,
            },
            .display = .{
                .fill_color = null,
                .img_path = "",
                .tint = lm.Color.white,
            },
        });

    if (textures.drain_middle) |drain_middle|
        try lm.display.add(.{
            .texture = drain_middle.*,
            .transform = .{
                .position = .init(middle_point.x, middle_point.y, -100),
                .rotation = angle,
                .scale = .init(middle_width, 64),
            },
            .display = .{
                .fill_color = null,
                .img_path = "",
                .tint = lm.Color.white,
            },
        });
}
