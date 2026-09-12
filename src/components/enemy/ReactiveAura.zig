const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const RoomManager = @import("../../global/RoomManager.zig");
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");

const Self = @This();

pub const ReactiveEffect = struct {
    effect_type: Stats.EffectType = .root,
    duration_seconds: f32 = 1.0,
    strength: f32 = 0.0,
};

pub const OnDeathRetaliation = struct {
    player_max_health_damage_percent: f32 = 0.20,
    ally_physical_damage_buff_percent: f32 = 0.15,
    ally_magic_damage_buff_percent: f32 = 0.10,
    buff_duration_seconds: f32 = 15.0,
};

is_active: bool = false,
active_duration_seconds: f32 = 0.0,
active_timer_seconds: f32 = 0.0,
cooldown_seconds: f32 = 0.0,
cooldown_remaining_seconds: f32 = 0.0,

apply_effect_on_hit: ?ReactiveEffect = null,
reflect_damage_percent: f32 = 0.0,
on_death_retaliation: ?OnDeathRetaliation = null,

stats: ?*Stats = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
}

pub fn Update(self: *Self) void {
    if (lm.time.paused()) return;

    const delta_time_seconds = lm.time.deltaTime();

    if (self.is_active and self.active_duration_seconds > 0.0) {
        self.active_timer_seconds -= delta_time_seconds;
        if (self.active_timer_seconds <= 0.0) {
            self.is_active = false;
            self.active_timer_seconds = 0.0;
            self.cooldown_remaining_seconds = self.cooldown_seconds;
        }
    } else if (!self.is_active and self.cooldown_remaining_seconds > 0.0) {
        self.cooldown_remaining_seconds -= delta_time_seconds;
        if (self.cooldown_remaining_seconds < 0.0) {
            self.cooldown_remaining_seconds = 0.0;
        }
    }
}

pub fn activateShield(self: *Self, duration_seconds: f32) void {
    self.is_active = true;
    self.active_duration_seconds = duration_seconds;
    self.active_timer_seconds = duration_seconds;
}

pub fn deactivateShield(self: *Self) void {
    self.is_active = false;
    self.active_timer_seconds = 0.0;
    self.cooldown_remaining_seconds = self.cooldown_seconds;
}

pub fn onHitByAttacker(
    self: *Self,
    defender_entity: *lm.Entity,
    attacker_entity: *lm.Entity,
    damage_dealt: f32,
) void {
    if (!self.is_active) return;

    const attacker_stats = attacker_entity.getComponent(Stats) orelse return;

    if (self.apply_effect_on_hit) |reactive_effect| {
        switch (reactive_effect.effect_type) {
            .root => attacker_stats.applyRoot(reactive_effect.duration_seconds),
            .slow => attacker_stats.applySlow(reactive_effect.strength, reactive_effect.duration_seconds),
            .stun => attacker_stats.applyStun(reactive_effect.duration_seconds),
            .stasis => attacker_stats.applyStasis(reactive_effect.duration_seconds),
            else => attacker_stats.addEffect(.{
                .id = "reactive_effect",
                .effect_type = reactive_effect.effect_type,
                .duration = reactive_effect.duration_seconds,
                .value = reactive_effect.strength,
            }),
        }

        if (defender_entity.getComponent(lm.Transform)) |defender_transform| {
            const defender_position = lm.vec3ToVec2(defender_transform.position);
            var listener_position = defender_position;
            if (attacker_entity.getComponent(lm.Transform)) |attacker_transform| {
                listener_position = lm.vec3ToVec2(attacker_transform.position);
            }
            SpatialAudio.playSpatialPitched("audio/sfx/boom.wav", defender_position, listener_position, 700.0, 0.6, 0.1);
        }
    }

    if (self.reflect_damage_percent > 0.0 and damage_dealt > 0.0) {
        const reflected_damage = damage_dealt * self.reflect_damage_percent;
        attacker_stats.current.health = @max(0.0, attacker_stats.current.health - reflected_damage);
    }
}

pub fn executeDeathRetaliation(self: *Self) void {
    const retaliation = self.on_death_retaliation orelse return;

    const player = lm.getEntity(.{ .id = "player" }) orelse return;
    if (player.getComponent(Stats)) |player_stats| {
        const retaliation_damage = player_stats.max.health * retaliation.player_max_health_damage_percent;
        player_stats.current.health = @max(1.0, player_stats.current.health - retaliation_damage);
    }

    const room_manager = RoomManager.get() orelse return;
    for (room_manager.spawner.active_enemies.items()) |enemy_uuid| {
        const enemy_entity = lm.getEntity(.{ .uuid = enemy_uuid }) orelse continue;
        const enemy_stats = enemy_entity.getComponent(Stats) orelse continue;

        const CustomBuff = struct {
            pub fn onEnable(stats: *Stats) void {
                stats.current.physical_damage *= 1.15;
                stats.current.magic_damage = if (stats.current.magic_damage > 0)
                    stats.current.magic_damage * 1.10
                else
                    10.0;
            }
            pub fn onDisable(stats: *Stats) void {
                stats.current.physical_damage /= 1.15;
                stats.current.magic_damage /= 1.10;
            }
        };

        enemy_stats.addEffect(.{
            .id = "even_in_death_buff",
            .effect_type = .custom,
            .duration = retaliation.buff_duration_seconds,
            .on_enable = CustomBuff.onEnable,
            .on_disable = CustomBuff.onDisable,
        });
    }
}

test "ReactiveAura apply_effect_on_hit with root and stun" {
    var defender_entity = lm.Entity.init(std.testing.allocator, "defender");
    defer defender_entity.deinit();

    var attacker_entity = lm.Entity.init(std.testing.allocator, "attacker");
    defer attacker_entity.deinit();

    try attacker_entity.addComponent(Stats.init(.player, .{}));
    try attacker_entity.addPreparedComponents(false);

    const attacker_stats = attacker_entity.getComponent(Stats).?;

    var aura = Self{
        .is_active = true,
        .apply_effect_on_hit = .{
            .effect_type = .root,
            .duration_seconds = 1.0,
        },
    };

    try std.testing.expect(!attacker_stats.isRooted());

    aura.onHitByAttacker(&defender_entity, &attacker_entity, 20.0);

    try std.testing.expect(attacker_stats.isRooted());

    // Switch reactive effect to stun
    aura.apply_effect_on_hit = .{
        .effect_type = .stun,
        .duration_seconds = 2.0,
    };

    try std.testing.expect(!attacker_stats.isStunned());

    aura.onHitByAttacker(&defender_entity, &attacker_entity, 20.0);

    try std.testing.expect(attacker_stats.isStunned());
}

test "ReactiveAura damage reflection" {
    var defender_entity = lm.Entity.init(std.testing.allocator, "defender");
    defer defender_entity.deinit();

    var attacker_entity = lm.Entity.init(std.testing.allocator, "attacker");
    defer attacker_entity.deinit();

    try attacker_entity.addComponent(Stats.init(.player, .{ .health = 100.0 }));
    try attacker_entity.addPreparedComponents(false);

    const attacker_stats = attacker_entity.getComponent(Stats).?;

    var aura = Self{
        .is_active = true,
        .reflect_damage_percent = 0.50, // 50% damage reflection
    };

    aura.onHitByAttacker(&defender_entity, &attacker_entity, 40.0);

    // 100 - (40 * 0.50) = 80
    try std.testing.expectEqual(@as(f32, 80.0), attacker_stats.current.health);
}
