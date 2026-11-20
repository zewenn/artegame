const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Attack = @import("Attack.zig");
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");
const Tether = @import("Tether.zig");

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

caster: ?*lm.Entity = null,
target_transform: ?*lm.Transform = null,
caster_transform: ?*lm.Transform = null,

effectiveness_fraction: f32 = 0.10,
time_remaining_seconds: f32 = 0.0,

tether: ?Tether = null,

pub var instance: Self = .{};

pub fn reset(self: *Self) void {
    self.state = .inactive;

    self.target_uuid = null;
    self.caster_uuid = null;
    self.caster = null;
    self.target_transform = null;
    self.caster_transform = null;

    self.effectiveness_fraction = 0.10;
    self.time_remaining_seconds = 0.0;
}

/// Releases loaded tether textures and resets bond state.
pub fn deinit(self: *Self) void {
    if (self.tether) |*tether| {
        tether.deinit();
        self.tether = null;
    }
    self.reset();
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

    self.caster = lm.getEntity(.byUUID(caster_uuid));
    if (self.caster) |caster| {
        self.caster_transform = caster.getComponent(lm.Transform);
    }

    self.target_transform = target_entity.getComponent(lm.Transform);

    self.effectiveness_fraction = effectiveness;
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

    const maybe_caster_entity = if (self.caster_uuid) |caster_uuid|
        lm.getEntity(.{ .uuid = caster_uuid })
    else
        null;

    const true_damage = target_stats.max.health * self.effectiveness_fraction;
    target_stats.current.health = @max(0.0, target_stats.current.health - true_damage);

    if (maybe_caster_entity) |caster_entity| {
        if (caster_entity.getComponent(Stats)) |caster_stats| {
            caster_stats.current.health = @min(caster_stats.max.health, caster_stats.current.health + true_damage);
        }
        if (caster_entity.getComponent(Attack)) |attack| {
            attack.cancelCurrentAction();
        }
    }

    if (stun_target_duration_seconds) |stun_duration_seconds| {
        target_stats.applyStun(stun_duration_seconds);
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

    const maybe_target_stats = self.getTargetStats();
    const true_damage = if (maybe_target_stats) |target_stats|
        target_stats.max.health * self.effectiveness_fraction
    else
        20.0;

    self.applyCasterRecoil(true_damage);

    if (maybe_target_stats) |target_stats| {
        target_stats.removeEffect(.{ .effect_type = .bond_of_life });
    }

    self.state = .expired;
    return true;
}

fn getTargetStats(self: *const Self) ?*Stats {
    const target_uuid = self.target_uuid orelse return null;
    const target_entity = lm.getEntity(.{ .uuid = target_uuid }) orelse return null;
    return target_entity.getComponent(Stats);
}

fn applyCasterRecoil(self: *const Self, true_damage: f32) void {
    const caster_uuid = self.caster_uuid orelse return;
    const caster_entity = lm.getEntity(.{ .uuid = caster_uuid }) orelse return;
    const caster_stats = caster_entity.getComponent(Stats) orelse return;
    caster_stats.current.health = @max(0.0, caster_stats.current.health - true_damage);
}

pub fn update(self: *Self, delta_seconds: f32) !void {
    if (self.tether == null) {
        self.tether = .init(
            try .load(
                "effects/bond_of_life/right.png",
                "effects/bond_of_life/left.png",
                &.{
                    "effects/bond_of_life/middle_1.png",
                    "effects/bond_of_life/middle_2.png",
                    "effects/bond_of_life/middle_3.png",
                    "effects/bond_of_life/middle_4.png",
                },
            ),
            .{},
        );
    }

    try self.renderTetherIfLinked();

    if (!self.isActive()) return;

    self.time_remaining_seconds -= delta_seconds;
    if (self.time_remaining_seconds <= 0.0) {
        _ = self.expireOnMiss();
    }
}

fn renderTetherIfLinked(self: *Self) !void {
    const tether = &(self.tether orelse return);
    const caster_uuid = self.caster_uuid orelse return;
    const target_uuid = self.target_uuid orelse return;
    const scene = lm.activeScene() orelse return;

    if (!scene.isEntityAliveUuid(target_uuid) or !scene.isEntityAliveUuid(caster_uuid)) return;

    const caster_transform = self.caster_transform orelse return;
    const target_transform = self.target_transform orelse return;

    const caster_position = lm.vec3ToVec2(caster_transform.position);
    const target_position = lm.vec3ToVec2(target_transform.position);
    const distance_pixels = caster_position.distance(target_position);

    tether.setActive(self.isActive());
    try tether.render(caster_position, target_position, distance_pixels);
}

test "BondOfLife apply activates the bond and rejects a second application" {
    var bond = Self{};
    bond.reset();

    var target_stats = Stats.init(.player, .{
        .health = 200.0,
        .armour = 500.0,
        .magic_resist = 500.0,
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

    const applied = bond.apply(caster_entity.uuid, &target_entity, 0.10, 5.0);
    try std.testing.expect(applied);
    try std.testing.expect(bond.isActive());
    try std.testing.expect(target_ptr.isBondOfLifeActive());

    try std.testing.expect(!bond.apply(caster_entity.uuid, &target_entity, 0.10, 5.0));
}
