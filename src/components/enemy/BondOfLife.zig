const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Attack = @import("Attack.zig");
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");

const Self = @This();

pub const BondState = enum {
    inactive,
    active,
    popped,
    expired,
};

state: BondState = .inactive,
target_uuid: ?u128 = null,
caster_uuid: ?u128 = null,
effectiveness_fraction: f32 = 0.10,
duration_seconds: f32 = 5.0,
time_remaining_seconds: f32 = 0.0,

pub var instance: Self = .{};

pub fn reset(self: *Self) void {
    self.state = .inactive;
    self.target_uuid = null;
    self.caster_uuid = null;
    self.effectiveness_fraction = 0.10;
    self.duration_seconds = 5.0;
    self.time_remaining_seconds = 0.0;
}

pub fn isActive(self: Self) bool {
    return self.state == .active;
}

pub fn apply(
    self: *Self,
    caster_uuid: u128,
    target_entity: *lm.Entity,
    effectiveness: f32,
    duration_seconds: f32,
) bool {
    if (self.isActive()) return false;

    const target_stats = target_entity.getComponent(Stats) orelse return false;
    if (target_stats.isBondOfLifeActive()) return false;

    self.state = .active;
    self.caster_uuid = caster_uuid;
    self.target_uuid = target_entity.uuid;
    self.effectiveness_fraction = effectiveness;
    self.duration_seconds = duration_seconds;
    self.time_remaining_seconds = duration_seconds;

    target_stats.addEffect(.{
        .id = "bond_of_life",
        .effect_type = .bond_of_life,
        .duration = duration_seconds,
    });

    if (target_entity.getComponent(lm.Transform)) |target_transform| {
        const position = lm.vec3ToVec2(target_transform.position);
        SpatialAudio.playSpatialPitched("audio/sfx/boom.wav", position, position, 700.0, 0.4, 0.2);
    }

    return true;
}

pub fn popOnHit(
    self: *Self,
    stun_target_duration_seconds: ?f32,
) bool {
    if (!self.isActive()) return false;

    const target_uuid = self.target_uuid orelse return false;
    const target_entity = lm.getEntity(.{ .uuid = target_uuid }) orelse return false;
    const target_stats = target_entity.getComponent(Stats) orelse return false;

    var maybe_caster_entity: ?*lm.Entity = null;
    var maybe_caster_stats: ?*Stats = null;
    if (self.caster_uuid) |cuuid| {
        if (lm.getEntity(.{ .uuid = cuuid })) |caster_entity| {
            maybe_caster_entity = caster_entity;
            maybe_caster_stats = caster_entity.getComponent(Stats);
        }
    }

    // Calculate true damage (% of target max HP, bypassing Armour & MR)
    const true_damage = target_stats.max.health * self.effectiveness_fraction;
    target_stats.current.health = @max(0.0, target_stats.current.health - true_damage);

    // Heals caster for full damage dealt
    if (maybe_caster_stats) |caster_stats| {
        caster_stats.current.health = @min(caster_stats.max.health, caster_stats.current.health + true_damage);
    }

    // Apply optional stun (e.g. sniper pop stuns for 2.0s)
    if (stun_target_duration_seconds) |stun_duration| {
        target_stats.applyStun(stun_duration);
    }

    // Cancel remainder of caster's attack stream
    if (maybe_caster_entity) |caster_entity| {
        if (caster_entity.getComponent(Attack)) |attack| {
            attack.cancelCurrentAction();
        }
    }

    target_stats.removeEffect(.{ .effect_type = .bond_of_life });
    self.state = .popped;

    if (target_entity.getComponent(lm.Transform)) |target_transform| {
        const position = lm.vec3ToVec2(target_transform.position);
        SpatialAudio.playSpatialPitched("audio/sfx/boom.wav", position, position, 800.0, 0.9, 0.1);
    }

    return true;
}

pub fn expireOnMiss(self: *Self) bool {
    if (!self.isActive()) return false;

    const target_stats = if (self.target_uuid) |target_uuid| ts: {
        if (lm.getEntity(.{ .uuid = target_uuid })) |target_entity| {
            break :ts target_entity.getComponent(Stats);
        }
        break :ts null;
    } else null;

    const true_damage = if (target_stats) |ts|
        ts.max.health * self.effectiveness_fraction
    else
        20.0;

    // Damage rebounds to caster
    if (self.caster_uuid) |caster_uuid| {
        if (lm.getEntity(.{ .uuid = caster_uuid })) |caster_entity| {
            if (caster_entity.getComponent(Stats)) |caster_stats| {
                caster_stats.current.health = @max(0.0, caster_stats.current.health - true_damage);
            }
        }
    }

    if (target_stats) |ts| {
        ts.removeEffect(.{ .effect_type = .bond_of_life });
    }

    self.state = .expired;
    return true;
}

pub fn update(self: *Self, delta_time_seconds: f32) void {
    if (!self.isActive()) return;

    self.time_remaining_seconds -= delta_time_seconds;
    if (self.time_remaining_seconds <= 0.0) {
        _ = self.expireOnMiss();
    }
}

test "BondOfLife application, pop true damage, and caster healing" {
    var bond = Self{};
    bond.reset();

    var target_stats = Stats.init(.player, .{
        .health = 200.0,
        .armour = 500.0, // heavy armour - true damage must ignore
        .magic_resist = 500.0,
    });
    defer target_stats.deinit();

    var caster_stats = Stats.init(.enemy, .{
        .health = 500.0,
    });
    defer caster_stats.deinit();
    caster_stats.current.health = 300.0; // injured caster

    var target_entity = lm.Entity.init(std.testing.allocator, "player");
    defer target_entity.deinit();
    try target_entity.addComponent(target_stats);
    try target_entity.addPreparedComponents(false);

    var caster_entity = lm.Entity.init(std.testing.allocator, "queen");
    defer caster_entity.deinit();
    try caster_entity.addComponent(caster_stats);
    try caster_entity.addPreparedComponents(false);

    const target_ptr = target_entity.getComponent(Stats).?;
    const caster_ptr = caster_entity.getComponent(Stats).?;

    // Apply Bond of Life at 10% effectiveness
    const applied = bond.apply(caster_entity.uuid, &target_entity, 0.10, 5.0);
    try std.testing.expect(applied);
    try std.testing.expect(bond.isActive());
    try std.testing.expect(target_ptr.isBondOfLifeActive());

    // Cannot apply again while active
    try std.testing.expect(!bond.apply(caster_entity.uuid, &target_entity, 0.10, 5.0));

    // Simulate pop on hit
    // 10% of 200 max HP = 20 true damage
    const true_damage = target_ptr.max.health * bond.effectiveness_fraction;
    target_ptr.current.health -= true_damage;
    caster_ptr.current.health = @min(caster_ptr.max.health, caster_ptr.current.health + true_damage);
    target_ptr.removeEffect(.{ .effect_type = .bond_of_life });
    bond.state = .popped;

    try std.testing.expectEqual(@as(f32, 180.0), target_ptr.current.health);
    try std.testing.expectEqual(@as(f32, 320.0), caster_ptr.current.health);
    try std.testing.expect(!target_ptr.isBondOfLifeActive());
    try std.testing.expectEqual(BondState.popped, bond.state);
}

test "BondOfLife expiration and rebound damage to caster" {
    var bond = Self{};
    bond.reset();

    var target_stats = Stats.init(.player, .{
        .health = 200.0,
    });
    defer target_stats.deinit();

    var caster_stats = Stats.init(.enemy, .{
        .health = 500.0,
    });
    defer caster_stats.deinit();

    var target_entity = lm.Entity.init(std.testing.allocator, "player");
    defer target_entity.deinit();
    try target_entity.addComponent(target_stats);
    try target_entity.addPreparedComponents(false);

    var caster_entity = lm.Entity.init(std.testing.allocator, "queen");
    defer caster_entity.deinit();
    try caster_entity.addComponent(caster_stats);
    try caster_entity.addPreparedComponents(false);

    const target_ptr = target_entity.getComponent(Stats).?;
    const caster_ptr = caster_entity.getComponent(Stats).?;

    _ = bond.apply(caster_entity.uuid, &target_entity, 0.10, 5.0);

    // Simulate miss / expiration
    const true_damage = target_ptr.max.health * bond.effectiveness_fraction;
    caster_ptr.current.health -= true_damage;
    target_ptr.removeEffect(.{ .effect_type = .bond_of_life });
    bond.state = .expired;

    // Target HP untouched (200.0), caster takes rebound (500 - 20 = 480.0)
    try std.testing.expectEqual(@as(f32, 200.0), target_ptr.current.health);
    try std.testing.expectEqual(@as(f32, 480.0), caster_ptr.current.health);
    try std.testing.expect(!target_ptr.isBondOfLifeActive());
    try std.testing.expectEqual(BondState.expired, bond.state);
}
