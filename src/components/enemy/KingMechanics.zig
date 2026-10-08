const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Attack = @import("Attack.zig");
const Movement = @import("Movement.zig");
const RoomManager = @import("../../global/RoomManager.zig");
const SpatialAudio = @import("../../global/audio/SpatialAudio.zig");
const KnightPrefab = @import("../../prefabs/enemies/Knight.zig").KnightEnemy;
const BishopPrefab = @import("../../prefabs/enemies/Bishop.zig").BishopEnemy;
const MeleePrefab = @import("../../prefabs/enemies/Melee.zig").MeleeEnemy;
const RangedPrefab = @import("../../prefabs/enemies/Ranged.zig").RangedEnemy;
const ElitePrefab = @import("../../prefabs/enemies/Elite.zig").EliteEnemy;
const TankPrefab = @import("../../prefabs/enemies/Tank.zig").TankEnemy;

const Self = @This();

pub const KingPhase = enum {
    initial_combat,
    mini_boss_summon,
    mini_boss_weaken,
    normal_minion_summon,
    normal_minion_weaken,
    enraged_combat,
};

pub const WeakenState = enum {
    ready,
    weakened,
};

phase: KingPhase = .initial_combat,
weaken_state: WeakenState = .ready,
weaken_timer_seconds: f32 = 0.0,
weaken_prior_armour: f32 = 0.0,
weaken_prior_magic_resist: f32 = 0.0,

stats: ?*Stats = null,
transform: ?*lm.Transform = null,
attack: ?*Attack = null,
movement: ?*Movement = null,

tracked_minion_uuids: lm.List(u128) = undefined,
is_initialized: bool = false,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.stats = try entity.pullComponent(Stats);
    self.transform = try entity.pullComponent(lm.Transform);
    self.attack = entity.getComponent(Attack);
    self.movement = entity.getComponent(Movement);

    self.tracked_minion_uuids = .init(lm.allocators.scene());
    self.is_initialized = true;
}

pub fn Update(self: *Self) !void {
    if (lm.time.paused()) return;

    const stats: *Stats = try lm.ensureComponent(self.stats);
    const transform: *lm.Transform = try lm.ensureComponent(self.transform);
    if (stats.current.health <= 0.0) return;

    const delta_seconds = lm.time.deltaTime();
    self.updateWeakenTimer(delta_seconds);

    const center_position = lm.vec3ToVec2(transform.position);
    const health_fraction = stats.current.health / stats.max.health;

    try self.processPhaseProgression(center_position, health_fraction);
}

pub fn End(self: *Self) void {
    if (self.is_initialized) {
        self.tracked_minion_uuids.deinit();
        self.is_initialized = false;
    }
}

fn updateWeakenTimer(self: *Self, delta_seconds: f32) void {
    if (self.weaken_state != .weakened) return;

    self.weaken_timer_seconds -= delta_seconds;
    if (self.weaken_timer_seconds <= 0.0) {
        self.endWeaken();
    }
}

fn processPhaseProgression(self: *Self, center_position: lm.Vector2, health_fraction: f32) !void {
    switch (self.phase) {
        .initial_combat => {
            if (health_fraction <= 0.80) {
                try self.triggerMiniBossSummon(center_position);
            }
        },
        .mini_boss_summon => {
            self.checkTrackedMinionsDefeated(.mini_boss_weaken);
        },
        .mini_boss_weaken => {
            if (self.weaken_state == .ready and health_fraction <= 0.60) {
                try self.triggerNormalMinionSummon(center_position);
            }
        },
        .normal_minion_summon => {
            self.checkTrackedMinionsDefeated(.normal_minion_weaken);
        },
        .normal_minion_weaken => {
            if (self.weaken_state == .ready and health_fraction <= 0.50) {
                self.phase = .enraged_combat;
            }
        },
        .enraged_combat => {},
    }
}

fn checkTrackedMinionsDefeated(self: *Self, next_phase: KingPhase) void {
    self.cleanDefeatedMinions();

    if (self.tracked_minion_uuids.len() != 0) return;
    if (self.stats) |stats| stats.removeStasis();

    self.phase = next_phase;
    self.startWeaken(4.0);
}

fn cleanDefeatedMinions(self: *Self) void {
    const len = self.tracked_minion_uuids.len();
    for (1..len + 1) |j| {
        const minion_index = len - j;
        const minion_uuid = self.tracked_minion_uuids.items()[minion_index];
        const minion_entity = lm.getEntity(.byUUID(minion_uuid));

        const is_alive = check_alive: {
            const entity = minion_entity orelse break :check_alive false;
            const stats = entity.getComponent(Stats) orelse break :check_alive false;

            break :check_alive stats.current.health > 0.0;
        };

        if (is_alive) return;
        _ = self.tracked_minion_uuids.swapRemove(minion_index);
    }
}

fn spawnTrackedMinion(self: *Self, minion_entity: *lm.Entity) !void {
    try lm.summoning.entity(minion_entity);
    try self.tracked_minion_uuids.append(minion_entity.uuid);
    RoomManager.registerSummonedEnemy(minion_entity.uuid);
}

fn triggerMiniBossSummon(self: *Self, center_position: lm.Vector2) !void {
    const MINIBOSS_SPAWN_COUNT: comptime_int = 2;

    self.phase = .mini_boss_summon;
    SpatialAudio.playSpatialPitched(
        "audio/sfx/boom.wav",
        center_position,
        center_position,
        1200.0,
        1.0,
        0.1,
    );

    for (0..MINIBOSS_SPAWN_COUNT) |_| {
        const is_knight = lm.random.boolean();
        const first_minion_position = center_position.add(lm.Vec2(-200, 0));
        const first_minion = if (is_knight)
            try KnightPrefab(first_minion_position)
        else
            try BishopPrefab(first_minion_position);

        try self.spawnTrackedMinion(first_minion);
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
        const angle = (@as(f32, @floatFromInt(minion_index)) / @as(f32, @floatFromInt(total_minions_to_spawn))) * std.math.pi * 2.0;
        const radius_pixels: f32 = 220.0 + @as(f32, @floatFromInt(minion_index % 3)) * 80.0;
        const spawn_offset = lm.Vec2(
            std.math.cos(angle) * radius_pixels,
            std.math.sin(angle) * radius_pixels,
        );
        const spawn_position = center_position.add(spawn_offset);

        const minion_choice = minion_index % 5;
        const minion_entity = switch (minion_choice) {
            0, 1 => try MeleePrefab(spawn_position),
            2, 3 => try RangedPrefab(spawn_position),
            else => try ElitePrefab(spawn_position),
        };
        try self.spawnTrackedMinion(minion_entity);
    }

    if (self.stats) |stats| stats.applyIndefiniteStasis();
    if (self.attack) |attack| attack.cancelCurrentAction();
}

pub fn startWeaken(self: *Self, duration_seconds: f32) void {
    if (self.weaken_state == .weakened) return;
    const stats = self.stats orelse return;

    self.weaken_timer_seconds = duration_seconds;
    self.weaken_prior_armour = stats.base.armour;
    self.weaken_prior_magic_resist = stats.base.magic_resist;

    stats.current.armour = self.weaken_prior_armour * 0.5;
    stats.current.magic_resist = self.weaken_prior_magic_resist * 0.5;
    stats.applySelfImposedStun(duration_seconds);

    if (self.transform) |transform| {
        const position = lm.vec3ToVec2(transform.position);
        SpatialAudio.playSpatialPitched("audio/sfx/boom.wav", position, position, 800.0, 0.5, 0.2);
    }
}

pub fn endWeaken(self: *Self) void {
    self.weaken_state = .ready;
    self.weaken_timer_seconds = 0.0;

    const stats = self.stats orelse return;
    stats.current.armour = self.weaken_prior_armour;
    stats.current.magic_resist = self.weaken_prior_magic_resist;

    if (self.transform) |transform| {
        const position = lm.vec3ToVec2(transform.position);
        SpatialAudio.playSpatialPitched("audio/sfx/pickup.mp3", position, position, 700.0, 0.9, 0.1);
    }
}

test "KingMechanics startWeaken halves defenses and endWeaken restores them" {
    var stats = Stats.initUnstoppable(.enemy, .{
        .armour = 80,
        .magic_resist = 60,
    });
    var king_mechanics = Self{
        .stats = &stats,
    };

    king_mechanics.startWeaken(4.0);
    try std.testing.expectEqual(WeakenState.weakened, king_mechanics.weaken_state);
    try std.testing.expectEqual(@as(f32, 40.0), stats.current.armour);
    try std.testing.expectEqual(@as(f32, 30.0), stats.current.magic_resist);
    try std.testing.expect(stats.isStunned());

    king_mechanics.endWeaken();
    try std.testing.expectEqual(WeakenState.ready, king_mechanics.weaken_state);
    try std.testing.expectEqual(@as(f32, 80.0), stats.current.armour);
    try std.testing.expectEqual(@as(f32, 60.0), stats.current.magic_resist);
}
