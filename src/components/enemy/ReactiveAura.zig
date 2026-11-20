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

reactive_effect_texture: ?*lm.Texture = null,

apply_effect_on_hit: ?ReactiveEffect = null,
on_death_retaliation: ?OnDeathRetaliation = null,

transform: ?*lm.Transform = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.transform = try entity.pullComponent(lm.Transform);

    if (self.apply_effect_on_hit != null) {
        self.reactive_effect_texture = lm.assets.texture.get("effects/reactive_root.png", &.{ 64, 64 });
    }
}

pub fn Update(self: *Self) !void {
    if (lm.time.paused()) return;

    const delta_seconds = lm.time.deltaTime();
    self.updateShieldTimer(delta_seconds);

    if (!self.is_active or self.apply_effect_on_hit == null) return;

    const transform = self.transform orelse return;
    const texture = self.reactive_effect_texture orelse return;
    const vertical_offset_pixels = (transform.scale.y - 64) / 2 + 8;

    try lm.display.addRenderer(.{
        .renderer = .{ .texture = .{
            .texture = texture.*,
            .transform = .{
                .position = lm.Vec3(
                    transform.position.x,
                    transform.position.y - vertical_offset_pixels,
                    10,
                ),
            },
            .tint = .white,
            .fill_color = null,
        } },
        .index = 10,
    });
}

pub fn End(self: *Self) void {
    if (self.reactive_effect_texture) |texture| {
        lm.assets.texture.releasePtr(texture);
        self.reactive_effect_texture = null;
    }
}

fn updateShieldTimer(self: *Self, delta_seconds: f32) void {
    if (!self.is_active or self.active_duration_seconds <= 0.0) return;

    self.active_timer_seconds -= delta_seconds;
    if (self.active_timer_seconds <= 0.0) {
        self.is_active = false;
        self.active_timer_seconds = 0.0;
    }
}

pub fn activateShield(self: *Self, duration_seconds: f32) void {
    self.is_active = true;
    self.active_duration_seconds = duration_seconds;
    self.active_timer_seconds = duration_seconds;
}

pub fn onHitByAttacker(
    self: *Self,
    defender_entity: *lm.Entity,
    attacker_entity: *lm.Entity,
) void {
    if (!self.is_active) return;

    const reactive_effect = self.apply_effect_on_hit orelse return;
    const attacker_stats = attacker_entity.getComponent(Stats) orelse return;

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

    playReactiveHitSound(defender_entity, attacker_entity);
}

fn playReactiveHitSound(defender_entity: *lm.Entity, attacker_entity: *lm.Entity) void {
    const defender_transform = defender_entity.getComponent(lm.Transform) orelse return;
    const defender_position = lm.vec3ToVec2(defender_transform.position);
    const listener_position = if (attacker_entity.getComponent(lm.Transform)) |attacker_transform|
        lm.vec3ToVec2(attacker_transform.position)
    else
        defender_position;

    SpatialAudio.playSpatialPitched("audio/sfx/boom.wav", defender_position, listener_position, 700.0, 0.6, 0.1);
}

fn deathRetaliationOnEnable(stats: *Stats) void {
    const effect = stats.getEffect(.{ .id = "even_in_death_buff" }) orelse return;
    const physical_delta = stats.current.physical_damage * effect.value;
    const magic_delta = stats.current.magic_damage * effect.secondary_value;

    effect.value = physical_delta;
    effect.secondary_value = magic_delta;
    stats.current.physical_damage += physical_delta;
    stats.current.magic_damage += magic_delta;
}

fn deathRetaliationOnDisable(stats: *Stats) void {
    const effect = stats.getEffect(.{ .id = "even_in_death_buff" }) orelse return;
    stats.current.physical_damage = @max(0.0, stats.current.physical_damage - effect.value);
    stats.current.magic_damage = @max(0.0, stats.current.magic_damage - effect.secondary_value);
}

fn applyDeathRetaliationBuffToAlly(enemy_stats: *Stats, retaliation: OnDeathRetaliation) void {
    enemy_stats.addEffect(.{
        .id = "even_in_death_buff",
        .effect_type = .custom,
        .duration = retaliation.buff_duration_seconds,
        .value = retaliation.ally_physical_damage_buff_percent,
        .secondary_value = retaliation.ally_magic_damage_buff_percent,
        .on_enable = deathRetaliationOnEnable,
        .on_disable = deathRetaliationOnDisable,
    });
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
        applyDeathRetaliationBuffToAlly(enemy_stats, retaliation);
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

    aura.onHitByAttacker(&defender_entity, &attacker_entity);
    try std.testing.expect(attacker_stats.isRooted());

    aura.apply_effect_on_hit = .{
        .effect_type = .stun,
        .duration_seconds = 2.0,
    };

    try std.testing.expect(!attacker_stats.isStunned());

    aura.onHitByAttacker(&defender_entity, &attacker_entity);
    try std.testing.expect(attacker_stats.isStunned());
}

test "ReactiveAura death retaliation honors configured percentages and restores exact deltas" {
    var physical_ally = Stats.init(.enemy, .{
        .physical_damage = 100.0,
        .magic_damage = 0.0,
    });
    defer physical_ally.deinit();

    var hybrid_ally = Stats.init(.enemy, .{
        .physical_damage = 40.0,
        .magic_damage = 50.0,
    });
    defer hybrid_ally.deinit();

    const retaliation = OnDeathRetaliation{
        .ally_physical_damage_buff_percent = 0.25,
        .ally_magic_damage_buff_percent = 0.20,
        .buff_duration_seconds = 10.0,
    };

    applyDeathRetaliationBuffToAlly(&physical_ally, retaliation);
    try std.testing.expectApproxEqAbs(@as(f32, 125.0), physical_ally.current.physical_damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), physical_ally.current.magic_damage, 0.001);

    physical_ally.tickEffects(10.0);
    try std.testing.expectApproxEqAbs(@as(f32, 100.0), physical_ally.current.physical_damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), physical_ally.current.magic_damage, 0.001);

    applyDeathRetaliationBuffToAlly(&hybrid_ally, retaliation);
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), hybrid_ally.current.physical_damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 60.0), hybrid_ally.current.magic_damage, 0.001);

    hybrid_ally.tickEffects(10.0);
    try std.testing.expectApproxEqAbs(@as(f32, 40.0), hybrid_ally.current.physical_damage, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), hybrid_ally.current.magic_damage, 0.001);
}
