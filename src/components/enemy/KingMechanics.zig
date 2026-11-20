const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Attack = @import("Attack.zig");
const EnemyType = @import("EnemyType.zig").EnemyType;
const RoomManager = @import("../../global/RoomManager.zig");
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");

const Self = @This();

const KING_WEAKEN_DURATION_SECONDS: f32 = 4.0;
const KING_WEAKEN_DEFENSE_MULTIPLIER: f32 = 0.5;

pub const KingPhase = enum {
    initial_combat,
    mini_boss_summon,
    mini_boss_weaken,
    normal_minion_summon,
    normal_minion_weaken,
    enraged_combat,
};

phase: KingPhase = .initial_combat,

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
attack: ?*Attack = null,

tracked_minion_uuids: lm.List(u128) = undefined,
is_initialized: bool = false,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
    self.attack = entity.getComponent(Attack);

    self.tracked_minion_uuids = .init(lm.allocators.scene());
    self.is_initialized = true;
}

pub fn Update(self: *Self) !void {
    if (lm.time.paused()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    if (stats.current.health <= 0.0) return;

    const center_position = lm.vec3ToVec2(transform.position);
    const health_fraction = stats.current.health / stats.max.health;

    try self.processPhaseProgression(stats, center_position, health_fraction);
}

pub fn End(self: *Self) void {
    if (self.is_initialized) {
        self.tracked_minion_uuids.deinit();
        self.is_initialized = false;
    }
}

fn processPhaseProgression(self: *Self, stats: *const Stats, center_position: lm.Vector2, health_fraction: f32) !void {
    switch (self.phase) {
        .initial_combat => if (health_fraction <= 0.80) try self.triggerMiniBossSummon(center_position),
        .mini_boss_summon => self.checkTrackedMinionsDefeated(.mini_boss_weaken),
        .mini_boss_weaken => if (!stats.isWeakened() and health_fraction <= 0.60) try self.triggerNormalMinionSummon(center_position),
        .normal_minion_summon => self.checkTrackedMinionsDefeated(.normal_minion_weaken),
        .normal_minion_weaken => if (!stats.isWeakened() and health_fraction <= 0.50) {
            self.phase = .enraged_combat;
        },
        .enraged_combat => {},
    }
}

fn checkTrackedMinionsDefeated(self: *Self, next_phase: KingPhase) void {
    self.cleanDefeatedMinions();

    if (self.tracked_minion_uuids.len() != 0) return;
    if (self.stats) |stats| stats.removeStasis();

    self.phase = next_phase;
    self.startWeaken(KING_WEAKEN_DURATION_SECONDS);
}

fn cleanDefeatedMinions(self: *Self) void {
    self.cleanDefeatedMinionsWithLookup(findSceneEntity);
}

fn findSceneEntity(entity_uuid: u128) ?*lm.Entity {
    return lm.getEntity(.byUUID(entity_uuid));
}

fn cleanDefeatedMinionsWithLookup(
    self: *Self,
    lookup_entity: *const fn (u128) ?*lm.Entity,
) void {
    const minion_count = self.tracked_minion_uuids.len();
    for (1..minion_count + 1) |step| {
        const minion_index = minion_count - step;
        const minion_uuid = self.tracked_minion_uuids.items()[minion_index];

        if (isMinionAliveWithLookup(minion_uuid, lookup_entity)) continue;
        _ = self.tracked_minion_uuids.swapRemove(minion_index);
    }
}

fn isMinionAliveWithLookup(
    minion_uuid: u128,
    lookup_entity: *const fn (u128) ?*lm.Entity,
) bool {
    const entity = lookup_entity(minion_uuid) orelse return false;
    const stats = entity.getComponent(Stats) orelse return false;
    return stats.current.health > 0.0;
}

fn spawnTrackedMinion(self: *Self, minion_entity: *lm.Entity) !void {
    try lm.summoning.entity(minion_entity);
    try self.tracked_minion_uuids.append(minion_entity.uuid);
    RoomManager.registerSummonedEnemy(minion_entity.uuid);
}

fn triggerMiniBossSummon(self: *Self, center_position: lm.Vector2) !void {
    const mini_boss_offsets = [_]lm.Vector2{
        .init(-200.0, 0.0),
        .init(200.0, 0.0),
    };

    self.phase = .mini_boss_summon;
    SpatialAudio.playSpatialPitched(
        "audio/sfx/boom.wav",
        center_position,
        center_position,
        1200.0,
        1.0,
        0.1,
    );

    for (mini_boss_offsets) |offset| {
        const minion = try EnemyType.mini_boss.spawn(center_position.add(offset));
        try self.spawnTrackedMinion(minion);
    }

    if (self.stats) |stats| stats.applyIndefiniteStasis();
    if (self.attack) |attack| attack.cancelCurrentAction();
}

fn triggerNormalMinionSummon(self: *Self, center_position: lm.Vector2) !void {
    self.phase = .normal_minion_summon;
    SpatialAudio.playSpatialPitched(
        "audio/sfx/boom.wav",
        center_position,
        center_position,
        1200.0,
        1.1,
        0.15,
    );

    const rooms_cleared = if (RoomManager.get()) |room_manager| room_manager.rooms_cleared else 0;
    const additional_minions = (rooms_cleared / 15) * 5;
    const total_minions_to_spawn = @min(48, 25 + additional_minions);

    for (0..total_minions_to_spawn) |minion_index| {
        const angle_radians = (@as(f32, @floatFromInt(minion_index)) / @as(f32, @floatFromInt(total_minions_to_spawn))) * std.math.pi * 2.0;
        const radius_pixels: f32 = 220.0 + @as(f32, @floatFromInt(minion_index % 3)) * 80.0;
        const spawn_offset = lm.Vec2(
            std.math.cos(angle_radians) * radius_pixels,
            std.math.sin(angle_radians) * radius_pixels,
        );
        const spawn_position = center_position.add(spawn_offset);

        const minion_type: EnemyType = switch (minion_index % 5) {
            0, 1 => .melee,
            2, 3 => .ranged,
            else => .elite,
        };
        const minion_entity = try minion_type.spawn(spawn_position);
        try self.spawnTrackedMinion(minion_entity);
    }

    if (self.stats) |stats| stats.applyIndefiniteStasis();
    if (self.attack) |attack| attack.cancelCurrentAction();
}

fn kingWeakenOnEnable(stats: *Stats) void {
    const effect = stats.getEffect(.{ .id = "king_weaken" }) orelse return;
    const armour_reduction = stats.base.armour * KING_WEAKEN_DEFENSE_MULTIPLIER;
    const magic_resist_reduction = stats.base.magic_resist * KING_WEAKEN_DEFENSE_MULTIPLIER;

    effect.value = armour_reduction;
    effect.secondary_value = magic_resist_reduction;
    stats.current.armour = @max(0.0, stats.current.armour - armour_reduction);
    stats.current.magic_resist = @max(0.0, stats.current.magic_resist - magic_resist_reduction);
}

fn kingWeakenOnDisable(stats: *Stats) void {
    const effect = stats.getEffect(.{ .id = "king_weaken" }) orelse return;
    stats.current.armour += effect.value;
    stats.current.magic_resist += effect.secondary_value;
}

/// Applies King's weaken effect, halving defenses for the given duration and restoring them on expiration.
pub fn applyWeakenEffect(stats: *Stats, duration_seconds: f32) void {
    stats.addEffect(.{
        .id = "king_weaken",
        .effect_type = .weaken,
        .duration = duration_seconds,
        .on_enable = kingWeakenOnEnable,
        .on_disable = kingWeakenOnDisable,
    });
}

pub fn startWeaken(self: *Self, duration_seconds: f32) void {
    const stats = self.stats orelse return;
    if (stats.isWeakened()) return;

    applyWeakenEffect(stats, duration_seconds);

    if (self.transform) |transform| {
        const position = lm.vec3ToVec2(transform.position);
        SpatialAudio.playSpatialPitched("audio/sfx/boom.wav", position, position, 800.0, 0.5, 0.2);
    }
}

test "KingMechanics startWeaken halves defenses and restores them on expiration" {
    var stats = Stats.initUnstoppable(.enemy, .{
        .armour = 80,
        .magic_resist = 60,
    });
    defer stats.deinit();

    var king_mechanics = Self{
        .stats = &stats,
    };

    king_mechanics.startWeaken(4.0);
    try std.testing.expect(stats.isWeakened());
    try std.testing.expect(!stats.canMove());
    try std.testing.expectEqual(@as(f32, 40.0), stats.current.armour);
    try std.testing.expectEqual(@as(f32, 30.0), stats.current.magic_resist);

    stats.tickEffects(4.0);
    try std.testing.expect(!stats.isWeakened());
    try std.testing.expect(stats.canMove());
    try std.testing.expectEqual(@as(f32, 80.0), stats.current.armour);
    try std.testing.expectEqual(@as(f32, 60.0), stats.current.magic_resist);
}

test "KingMechanics cleanDefeatedMinions removes dead minion while keeping living minion" {
    const TestLookup = struct {
        var living: ?*lm.Entity = null;
        var dead: ?*lm.Entity = null;

        fn find(entity_uuid: u128) ?*lm.Entity {
            if (living) |entity| {
                if (entity.uuid == entity_uuid) return entity;
            }
            if (dead) |entity| {
                if (entity.uuid == entity_uuid) return entity;
            }
            return null;
        }
    };

    var king_mechanics = Self{
        .tracked_minion_uuids = .init(std.testing.allocator),
        .is_initialized = true,
    };
    defer king_mechanics.End();

    var living_entity = lm.Entity.init(std.testing.allocator, "living_minion");
    defer living_entity.deinit();
    var living_stats = Stats.init(.enemy, .{ .health = 100.0 });
    defer living_stats.deinit();
    try living_entity.addComponent(living_stats);
    try living_entity.addPreparedComponents(false);

    var dead_entity = lm.Entity.init(std.testing.allocator, "dead_minion");
    defer dead_entity.deinit();
    var dead_stats = Stats.init(.enemy, .{ .health = 0.0 });
    defer dead_stats.deinit();
    try dead_entity.addComponent(dead_stats);
    try dead_entity.addPreparedComponents(false);

    TestLookup.living = &living_entity;
    TestLookup.dead = &dead_entity;
    defer {
        TestLookup.living = null;
        TestLookup.dead = null;
    }

    try king_mechanics.tracked_minion_uuids.append(living_entity.uuid);
    try king_mechanics.tracked_minion_uuids.append(dead_entity.uuid);
    king_mechanics.cleanDefeatedMinionsWithLookup(TestLookup.find);
    try std.testing.expectEqual(@as(usize, 1), king_mechanics.tracked_minion_uuids.len());
    try std.testing.expectEqual(living_entity.uuid, king_mechanics.tracked_minion_uuids.items()[0]);

    king_mechanics.tracked_minion_uuids.clearRetainingCapacity();
    try king_mechanics.tracked_minion_uuids.append(dead_entity.uuid);
    try king_mechanics.tracked_minion_uuids.append(living_entity.uuid);
    try king_mechanics.tracked_minion_uuids.append(999999);
    king_mechanics.cleanDefeatedMinionsWithLookup(TestLookup.find);
    try std.testing.expectEqual(@as(usize, 1), king_mechanics.tracked_minion_uuids.len());
    try std.testing.expectEqual(living_entity.uuid, king_mechanics.tracked_minion_uuids.items()[0]);
}
