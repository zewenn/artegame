const std = @import("std");
const lm = @import("loom");
const prefabs = @import("../../prefabs/prefabs.zig");
const SpatialAudio = @import("../audio/SpatialAudio.zig");
const MapTypes = @import("../map/MapTypes.zig");
const Stats = @import("../../components/Stats.zig");
const BossBar = @import("../ui/BossBar.zig");

pub const EnemyType = @import("../../components/enemy/EnemyType.zig").EnemyType;

pub const SpawnProfile = enum {
    tutorial,
    normal,
    mini_boss,
    boss,
};

pub const WaveConfig = struct {
    round: u32,
    profile: SpawnProfile = .normal,
    budget: u32,
    total_enemies: u32,
    dummy_count: u32 = 0,
    melee_count: u32 = 0,
    ranged_count: u32 = 0,
    elite_count: u32 = 0,
    shaman_count: u32 = 0,
    magician_count: u32 = 0,
    lifeliner_count: u32 = 0,
    angler_count: u32 = 0,
    tank_count: u32 = 0,
    mini_boss_count: u32 = 0,
    boss_count: u32 = 0,
    is_cap_reached: bool = false,
    post_cap_round_offset: u32 = 0,
};

pub const WaveProgress = struct {
    round: u32 = 0,
    killed: u32 = 0,
    total: u32 = 0,
    active: u32 = 0,
    queued: u32 = 0,
};

pub fn calculateBudgetForProfile(round: u32, profile: SpawnProfile) u32 {
    return switch (profile) {
        .tutorial => 0,
        .mini_boss => 20,
        .boss => 100,
        .normal => {
            if (round <= 1) return 8;

            const round_offset = round - 1;

            if (round <= 5) {
                return 8 + (round_offset * 6) + (round_offset * round_offset);
            }

            return 48 + (round - 5) * 16;
        },
    };
}

pub fn calculateBudget(round: u32) u32 {
    return calculateBudgetForProfile(round, .normal);
}

pub const EnemyComposition = struct {
    melee_count: u32 = 0,
    ranged_count: u32 = 0,
    elite_count: u32 = 0,
    shaman_count: u32 = 0,
    magician_count: u32 = 0,
    lifeliner_count: u32 = 0,
    angler_count: u32 = 0,
    tank_count: u32 = 0,

    pub fn total(self: EnemyComposition) u32 {
        return self.melee_count + self.ranged_count + self.elite_count + self.shaman_count + self.magician_count + self.lifeliner_count + self.angler_count + self.tank_count;
    }
};

fn calculateScaledEnemyCount(
    round: u32,
    remaining_budget: *u32,
    zones: []const MapTypes.SpawnZoneRecord,
    enemy_type: EnemyType,
    rule: EnemyType.NormalWaveRule,
) u32 {
    const is_unlocked = round >= rule.unlock_round;
    const has_budget = remaining_budget.* >= enemy_type.cost();
    const is_permitted = hasDesignatedZone(zones, enemy_type);

    if (!is_unlocked or !has_budget or !is_permitted) return 0;

    const round_offset = round - rule.unlock_round;
    var count = @min(1 + round_offset / rule.round_divisor, rule.max_count);
    const total_cost = count * enemy_type.cost();

    if (remaining_budget.* > total_cost) {
        remaining_budget.* -= total_cost;
        return count;
    }

    count = remaining_budget.* / enemy_type.cost();
    remaining_budget.* -= count * enemy_type.cost();
    return count;
}

/// Checks whether a map's spawn zones include a designated zone for an enemy archetype.
/// If no spawn zones are defined on the map (empty collection), all enemy types are considered permitted.
/// An untyped zone (enemy_type == null) represents an "All (Any Enemy)" zone and accepts any archetype.
pub fn hasDesignatedZone(zones: []const MapTypes.SpawnZoneRecord, enemy_type: EnemyType) bool {
    if (zones.len == 0) return true;
    for (zones) |zone| {
        if (zone.enemy_type == null) return true;
        if (zone.enemy_type.? == enemy_type) return true;
    }
    return false;
}

pub fn calculateNormalEnemyComposition(round: u32) EnemyComposition {
    return calculateNormalEnemyCompositionWithZones(round, &.{});
}

pub fn calculateNormalEnemyCompositionWithZones(
    round: u32,
    zones: []const MapTypes.SpawnZoneRecord,
) EnemyComposition {
    const total_budget = calculateBudgetForProfile(round, .normal);
    var remaining_budget = total_budget;
    var composition = EnemyComposition{};

    inline for (std.meta.fields(EnemyType)) |field| {
        const enemy_type: EnemyType = @field(EnemyType, field.name);
        const maybe_rule = comptime enemy_type.normalWaveRule();
        if (maybe_rule) |rule| {
            const count = calculateScaledEnemyCount(round, &remaining_budget, zones, enemy_type, rule);
            @field(composition, field.name ++ "_count") = count;
        }
    }

    var ranged_count: u32 = 0;
    if (round >= 2 and remaining_budget > 0 and hasDesignatedZone(zones, .ranged)) {
        const can_spawn_melee = hasDesignatedZone(zones, .melee);
        const ranged_budget = if (can_spawn_melee) (remaining_budget * 35) / 100 else remaining_budget;
        ranged_count = ranged_budget / EnemyType.ranged.cost();
        remaining_budget -= ranged_count * EnemyType.ranged.cost();
    }
    composition.ranged_count = ranged_count;

    composition.melee_count = if (hasDesignatedZone(zones, .melee)) remaining_budget else 0;

    return composition;
}

pub fn getFirstCapRound() u32 {
    var check_round: u32 = 1;
    while (check_round < 100) : (check_round += 1) {
        const composition = calculateNormalEnemyComposition(check_round);
        if (composition.total() >= MAX_CONCURRENT_ENEMIES) {
            return check_round;
        }
    }
    return 10;
}

pub fn generateWaveConfigForProfile(round: u32, profile: SpawnProfile) WaveConfig {
    return generateWaveConfigForProfileAndZones(round, profile, &.{});
}

pub fn generateWaveConfigForProfileAndZones(
    round: u32,
    profile: SpawnProfile,
    zones: []const MapTypes.SpawnZoneRecord,
) WaveConfig {
    switch (profile) {
        .tutorial => {
            return WaveConfig{
                .round = round,
                .profile = .tutorial,
                .budget = 0,
                .total_enemies = 1,
                .dummy_count = 1,
            };
        },
        .mini_boss => {
            return WaveConfig{
                .round = round,
                .profile = .mini_boss,
                .budget = 20,
                .total_enemies = 1,
                .mini_boss_count = 1,
            };
        },
        .boss => {
            return WaveConfig{
                .round = round,
                .profile = .boss,
                .budget = 100,
                .total_enemies = 1,
                .boss_count = 1,
            };
        },
        .normal => {
            const total_budget = calculateBudgetForProfile(round, .normal);
            var composition = calculateNormalEnemyCompositionWithZones(round, zones);
            const unconstrained_enemies = composition.total();

            const is_cap_reached = unconstrained_enemies >= MAX_CONCURRENT_ENEMIES;
            const first_cap_round = getFirstCapRound();
            const post_cap_round_offset: u32 = if (round > first_cap_round) round - first_cap_round else 0;

            if (unconstrained_enemies > MAX_CONCURRENT_ENEMIES) {
                var excess = unconstrained_enemies - @as(u32, @intCast(MAX_CONCURRENT_ENEMIES));
                if (composition.melee_count >= excess) {
                    composition.melee_count -= excess;
                    excess = 0;
                } else {
                    excess -= composition.melee_count;
                    composition.melee_count = 0;
                }

                if (excess > 0) {
                    if (composition.ranged_count >= excess) {
                        composition.ranged_count -= excess;
                        excess = 0;
                    } else {
                        excess -= composition.ranged_count;
                        composition.ranged_count = 0;
                    }
                }

                if (excess > 0) {
                    if (composition.angler_count >= excess) {
                        composition.angler_count -= excess;
                        excess = 0;
                    } else {
                        excess -= composition.angler_count;
                        composition.angler_count = 0;
                    }
                }
            }

            return WaveConfig{
                .round = round,
                .profile = .normal,
                .budget = total_budget,
                .total_enemies = composition.total(),
                .melee_count = composition.melee_count,
                .ranged_count = composition.ranged_count,
                .elite_count = composition.elite_count,
                .shaman_count = composition.shaman_count,
                .magician_count = composition.magician_count,
                .lifeliner_count = composition.lifeliner_count,
                .angler_count = composition.angler_count,
                .tank_count = composition.tank_count,
                .is_cap_reached = is_cap_reached,
                .post_cap_round_offset = post_cap_round_offset,
            };
        },
    }
}

pub fn generateWaveConfig(round: u32) WaveConfig {
    return generateWaveConfigForProfile(round, .normal);
}

pub fn populateQueue(list: *lm.List(EnemyType), config: WaveConfig) !void {
    list.clearRetainingCapacity();

    if (config.dummy_count > 0) {
        for (0..config.dummy_count) |_| {
            try list.append(.dummy);
        }
        return;
    }

    if (config.mini_boss_count > 0) {
        for (0..config.mini_boss_count) |_| {
            try list.append(.mini_boss);
        }
        return;
    }

    if (config.boss_count > 0) {
        for (0..config.boss_count) |_| {
            try list.append(.boss);
        }
        return;
    }

    var melee_left = config.melee_count;
    var ranged_left = config.ranged_count;
    var angler_left = config.angler_count;
    var tank_left = config.tank_count;
    var shaman_left = config.shaman_count;
    var magician_left = config.magician_count;
    var lifeliner_left = config.lifeliner_count;
    var elite_left = config.elite_count;

    const vanguard = @min(melee_left, 3);
    for (0..vanguard) |_| {
        try list.append(.melee);
        melee_left -= 1;
    }

    while (melee_left > 0 or ranged_left > 0 or angler_left > 0 or tank_left > 0 or shaman_left > 0 or magician_left > 0 or lifeliner_left > 0 or elite_left > 0) {
        const melee_batch = @min(melee_left, 2);
        for (0..melee_batch) |_| {
            try list.append(.melee);
            melee_left -= 1;
        }

        if (ranged_left > 0) {
            try list.append(.ranged);
            ranged_left -= 1;
        }

        if (angler_left > 0) {
            try list.append(.angler);
            angler_left -= 1;
        }

        if (tank_left > 0) {
            try list.append(.tank);
            tank_left -= 1;
        }

        if (shaman_left > 0) {
            try list.append(.shaman);
            shaman_left -= 1;
        }

        if (magician_left > 0) {
            try list.append(.magician);
            magician_left -= 1;
        }

        if (lifeliner_left > 0) {
            try list.append(.lifeliner);
            lifeliner_left -= 1;
        }

        if (elite_left > 0 and (melee_left <= config.melee_count / 2 or (melee_left == 0 and ranged_left == 0))) {
            try list.append(.elite);
            elite_left -= 1;
        }
    }
}

pub const ExclusionZone = struct {
    min: lm.Vector2,
    max: lm.Vector2,

    pub fn contains(self: ExclusionZone, position: lm.Vector2) bool {
        return position.x >= self.min.x and position.x <= self.max.x and position.y >= self.min.y and position.y <= self.max.y;
    }
};

pub const SpawnAreaConfig = struct {
    min_x: f32 = -1100.0,
    max_x: f32 = 1100.0,
    min_y: f32 = -520.0,
    max_y: f32 = 520.0,
    min_player_distance_pixels: f32 = 420.0,
    edge_depth: f32 = 80.0,
    exclusion_zones: []const ExclusionZone = &.{},
};

pub fn pickSpawnPositionWithConfig(player_position: lm.Vector2, config: SpawnAreaConfig) lm.Vector2 {
    var attempt: usize = 0;
    while (attempt < 10) : (attempt += 1) {
        const edge = lm.random.intRangeAtMost(u32, 0, 3);
        var x: f32 = 0;
        var y: f32 = 0;

        switch (edge) {
            0 => {
                x = config.min_x + lm.randFloat(f32, 0, config.edge_depth);
                y = lm.randFloat(f32, config.min_y, config.max_y);
            },
            1 => {
                x = config.max_x - lm.randFloat(f32, 0, config.edge_depth);
                y = lm.randFloat(f32, config.min_y, config.max_y);
            },
            2 => {
                x = lm.randFloat(f32, config.min_x, config.max_x);
                y = config.min_y + lm.randFloat(f32, 0, config.edge_depth);
            },
            else => {
                x = lm.randFloat(f32, config.min_x, config.max_x);
                y = config.max_y - lm.randFloat(f32, 0, config.edge_depth);
            },
        }

        var in_exclusion = false;
        for (config.exclusion_zones) |zone| {
            if (zone.contains(.init(x, y))) {
                in_exclusion = true;
                break;
            }
        }
        if (in_exclusion) continue;

        const delta_x = x - player_position.x;
        const delta_y = y - player_position.y;
        const distance_to_player = std.math.hypot(delta_x, delta_y);
        if (distance_to_player >= config.min_player_distance_pixels) {
            return lm.Vec2(x, y);
        }
    }

    const fallback_x = if (player_position.x > 0) config.min_x + 50 else config.max_x - 50;
    const fallback_y = if (player_position.y > 0) config.min_y + 50 else config.max_y - 50;
    return lm.Vec2(fallback_x, fallback_y);
}

pub fn pickSpawnPosition(player_position: lm.Vector2) lm.Vector2 {
    return pickSpawnPositionWithConfig(player_position, .{});
}

const Self = @This();

pub const MAX_CONCURRENT_ENEMIES: usize = 64;

spawn_queue: lm.List(EnemyType),
spawn_cursor: usize = 0,
active_enemies: lm.List(u128),
spawn_area: SpawnAreaConfig = .{},
spawn_zones: []const MapTypes.SpawnZoneRecord = &.{},

round: u32 = 0,
profile: SpawnProfile = .normal,
total_wave_enemies: u32 = 0,
killed_enemies: u32 = 0,

spawn_timer_seconds: f32 = 0,
spawn_interval_seconds: f32 = 5.0,
max_active_enemies: u32 = 64,

is_active: bool = false,

pub fn setSpawnZones(self: *Self, zones: []const MapTypes.SpawnZoneRecord) void {
    self.spawn_zones = zones;
}

pub fn setMapBounds(self: *Self, min: lm.Vector2, max: lm.Vector2) void {
    const margin_pixels: f32 = 80.0;
    self.spawn_area.min_x = min.x + margin_pixels;
    self.spawn_area.max_x = max.x - margin_pixels;
    self.spawn_area.min_y = min.y + margin_pixels;
    self.spawn_area.max_y = max.y - margin_pixels;
}

fn pickSpawnPositionFromMatchingOrAnyZone(
    zones: []const MapTypes.SpawnZoneRecord,
    target_enemy_type: ?EnemyType,
    player_position: lm.Vector2,
) ?lm.Vector2 {
    var match_count: usize = 0;
    for (zones) |zone| {
        const is_match = if (target_enemy_type) |enemy_type|
            (zone.enemy_type != null and zone.enemy_type.? == enemy_type)
        else
            (zone.enemy_type == null);

        if (is_match) {
            match_count += 1;
        }
    }

    if (match_count == 0) return null;

    var attempt_count: usize = 0;
    while (attempt_count < 10) : (attempt_count += 1) {
        const selected_match_index = lm.random.intRangeLessThan(usize, 0, match_count);
        var current_match_index: usize = 0;
        var selected_zone: ?MapTypes.SpawnZoneRecord = null;

        for (zones) |zone| {
            const is_match = if (target_enemy_type) |enemy_type|
                (zone.enemy_type != null and zone.enemy_type.? == enemy_type)
            else
                (zone.enemy_type == null);

            if (!is_match) continue;

            if (current_match_index == selected_match_index) {
                selected_zone = zone;
                break;
            }
            current_match_index += 1;
        }

        const zone = selected_zone orelse continue;
        const half_width_pixels = zone.width_pixels / 2.0;
        const half_height_pixels = zone.height_pixels / 2.0;

        const spawn_x = zone.center_x_pixels + lm.randFloat(f32, -half_width_pixels, half_width_pixels);
        const spawn_y = zone.center_y_pixels + lm.randFloat(f32, -half_height_pixels, half_height_pixels);
        const spawn_position = lm.Vec2(spawn_x, spawn_y);

        const distance_to_player_pixels = std.math.hypot(spawn_x - player_position.x, spawn_y - player_position.y);
        if (distance_to_player_pixels >= 200.0 or attempt_count >= 8) {
            return spawn_position;
        }
    }

    return null;
}

pub fn pickSpawnPositionForEnemy(self: *Self, player_position: lm.Vector2, enemy_type: EnemyType) ?lm.Vector2 {
    if (self.spawn_zones.len > 0) {
        if (pickSpawnPositionFromMatchingOrAnyZone(self.spawn_zones, enemy_type, player_position)) |spawn_position| {
            return spawn_position;
        }

        if (pickSpawnPositionFromMatchingOrAnyZone(self.spawn_zones, null, player_position)) |spawn_position| {
            return spawn_position;
        }

        return null;
    }

    return pickSpawnPositionWithConfig(player_position, self.spawn_area);
}

pub fn pickSpawnPositionFromZonesOrConfig(self: *Self, player_position: lm.Vector2) lm.Vector2 {
    if (self.pickSpawnPositionForEnemy(player_position, .melee)) |spawn_position| {
        return spawn_position;
    }
    return pickSpawnPositionWithConfig(player_position, self.spawn_area);
}

pub fn init(allocator: std.mem.Allocator) Self {
    return Self{
        .spawn_queue = .init(allocator),
        .spawn_cursor = 0,
        .active_enemies = .init(allocator),
    };
}

pub fn deinit(self: *Self) void {
    self.spawn_queue.deinit();
    self.spawn_cursor = 0;
    self.active_enemies.deinit();
    self.is_active = false;
    BossBar.unbind();
}

pub fn startWaveForRoom(self: *Self, round: u32, profile: SpawnProfile) !void {
    self.round = round;
    self.profile = profile;
    self.killed_enemies = 0;
    self.spawn_cursor = 0;

    const config = generateWaveConfigForProfileAndZones(round, profile, self.spawn_zones);
    self.total_wave_enemies = config.total_enemies;

    try populateQueue(&self.spawn_queue, config);
    self.active_enemies.clearRetainingCapacity();

    if (profile != .mini_boss and profile != .boss) {
        BossBar.unbind();
    }

    switch (profile) {
        .tutorial => {
            self.max_active_enemies = 2;
            self.spawn_interval_seconds = 0.1;
        },
        .mini_boss => {
            self.max_active_enemies = 1;
            self.spawn_interval_seconds = 0.1;
        },
        .boss => {
            self.max_active_enemies = 16;
            self.spawn_interval_seconds = 0.1;
        },
        .normal => {
            self.max_active_enemies = @as(u32, @intCast(MAX_CONCURRENT_ENEMIES));
            self.spawn_interval_seconds = 5.0;
        },
    }

    self.spawn_timer_seconds = 0.15;
    self.is_active = true;
}

pub fn startWave(self: *Self, round: u32) !void {
    try self.startWaveForRoom(round, .normal);
}

pub fn removeDefeatedEnemy(self: *Self, uuid: u128) void {
    if (!self.is_active) return;

    for (self.active_enemies.items(), 0..) |enemy_uuid, index| {
        if (uuid != enemy_uuid) continue;

        _ = self.active_enemies.swapRemove(index);
        self.killed_enemies += 1;
        BossBar.onBossDefeated(uuid);

        break;
    }
}

pub fn registerSummonedEnemy(self: *Self, uuid: u128) !void {
    if (!self.is_active) return;

    for (self.active_enemies.items()) |active_uuid| {
        if (active_uuid == uuid) return;
    }

    self.total_wave_enemies += 1;
    try self.active_enemies.append(uuid);
}

pub fn applyDynamicStatScalingToStats(stats: *Stats, enemy_type: EnemyType, round: u32) void {
    if (enemy_type == .dummy) return;
    if (round <= 1) return;

    const round_offset: f32 = @floatFromInt(round - 1);

    const health_multiplier: f32 = 1.0 + round_offset * 0.08;
    const damage_multiplier: f32 = 1.0 + round_offset * 0.04;
    const speed_multiplier: f32 = @min(1.25, 1.0 + round_offset * 0.015);

    stats.max.health *= health_multiplier;
    stats.current.health = stats.max.health;
    stats.base.health = stats.max.health;

    stats.current.physical_damage *= damage_multiplier;
    stats.base.physical_damage *= damage_multiplier;
    stats.current.magic_damage *= damage_multiplier;
    stats.base.magic_damage *= damage_multiplier;

    stats.current.movement_speed *= speed_multiplier;
    stats.base.movement_speed *= speed_multiplier;

    const first_cap_round = getFirstCapRound();
    if (round > first_cap_round) {
        const post_cap_round_offset: u32 = round - first_cap_round;
        const post_cap_offset_float: f32 = @floatFromInt(post_cap_round_offset);

        const bonus_health_multiplier: f32 = 1.0 + post_cap_offset_float * 0.10;
        stats.max.health *= bonus_health_multiplier;
        stats.current.health = stats.max.health;
        stats.base.health = stats.max.health;

        const bonus_damage_multiplier: f32 = 1.0 + post_cap_offset_float * 0.05;
        stats.current.physical_damage *= bonus_damage_multiplier;
        stats.base.physical_damage *= bonus_damage_multiplier;
        stats.current.magic_damage *= bonus_damage_multiplier;
        stats.base.magic_damage *= bonus_damage_multiplier;

        const bonus_armour: f32 = post_cap_offset_float * 2.5;
        stats.current.armour += bonus_armour;
        stats.base.armour += bonus_armour;
        stats.max.armour += bonus_armour;

        const bonus_magic_resist: f32 = post_cap_offset_float * 2.5;
        stats.current.magic_resist += bonus_magic_resist;
        stats.base.magic_resist += bonus_magic_resist;
        stats.max.magic_resist += bonus_magic_resist;
    }
}

pub fn applyDynamicStatScaling(enemy: *lm.Entity, enemy_type: EnemyType, round: u32) void {
    if (enemy_type == .dummy) return;
    const stats = enemy.getComponent(Stats) orelse (enemy.getComponentUnsafe(Stats).result orelse return);
    applyDynamicStatScalingToStats(stats, enemy_type, round);
}

pub fn update(self: *Self, delta_seconds: f32, scene: ?*lm.Scene, player_position: lm.Vector2) !void {
    _ = scene;
    if (!self.is_active) return;

    if (self.spawn_cursor >= self.spawn_queue.len()) return;

    if (self.active_enemies.len() >= self.max_active_enemies or self.active_enemies.len() >= MAX_CONCURRENT_ENEMIES) return;

    self.spawn_timer_seconds -= delta_seconds;

    if (self.spawn_timer_seconds > 0) return;

    const remaining_in_queue = self.spawn_queue.len() - self.spawn_cursor;
    const active_count = self.active_enemies.len();
    const active_capacity = if (active_count < self.max_active_enemies)
        self.max_active_enemies - @as(u32, @intCast(active_count))
    else
        0;

    const target_batch_size: usize = if (self.profile == .normal)
        lm.random.intRangeAtMost(usize, 5, 6)
    else
        1;

    const spawn_batch_count = @min(target_batch_size, @min(@as(usize, active_capacity), remaining_in_queue));
    if (spawn_batch_count == 0) return;

    for (0..spawn_batch_count) |_| {
        if (self.spawn_cursor >= self.spawn_queue.len()) break;
        if (self.active_enemies.len() >= self.max_active_enemies or self.active_enemies.len() >= MAX_CONCURRENT_ENEMIES) break;

        const enemy_type = self.spawn_queue.items()[self.spawn_cursor];
        self.spawn_cursor += 1;
        const spawn_position = self.pickSpawnPositionForEnemy(player_position, enemy_type) orelse {
            if (self.total_wave_enemies > 0) self.total_wave_enemies -= 1;
            continue;
        };

        const enemy = switch (enemy_type) {
            .dummy => try prefabs.enemies.Dummy(spawn_position),
            .melee => try prefabs.enemies.Melee(spawn_position),
            .ranged => try prefabs.enemies.Ranged(spawn_position),
            .elite => try prefabs.enemies.Elite(spawn_position),
            .shaman => try prefabs.enemies.Shaman(spawn_position),
            .magician => try prefabs.enemies.Magician(spawn_position),
            .lifeliner => try prefabs.enemies.Lifeliner(spawn_position),
            .angler => try prefabs.enemies.Angler(spawn_position),
            .tank => try prefabs.enemies.Tank(spawn_position),
            .mini_boss => try prefabs.enemies.MiniBoss(spawn_position),
            .boss => try prefabs.enemies.Boss(spawn_position),
        };

        applyDynamicStatScaling(enemy, enemy_type, self.round);

        if (enemy_type == .mini_boss) {
            BossBar.bind(enemy, "Corrupted Guardian", .mini_boss);
        } else if (enemy_type == .boss) {
            BossBar.bind(enemy, "Abyssal Behemoth", .boss);
        }

        try self.active_enemies.append(enemy.uuid);
        try lm.summoning.entity(enemy);

        SpatialAudio.playSpatialPitched("audio/sfx/punch.mp3", spawn_position, player_position, 800.0, 0.35, 0.15);
    }

    self.spawn_timer_seconds = self.spawn_interval_seconds;
}

pub fn isWaveFinished(self: *const Self) bool {
    if (!self.is_active) return false;
    return self.spawn_cursor >= self.spawn_queue.len() and self.active_enemies.len() == 0;
}

pub fn finishWave(self: *Self) void {
    self.is_active = false;
}

pub fn getProgress(self: *const Self) WaveProgress {
    const queued_count = if (self.spawn_queue.len() > self.spawn_cursor)
        self.spawn_queue.len() - self.spawn_cursor
    else
        0;

    return WaveProgress{
        .round = self.round,
        .killed = self.killed_enemies,
        .total = self.total_wave_enemies,
        .active = @intCast(self.active_enemies.len()),
        .queued = @intCast(queued_count),
    };
}

test "calculateBudget scaling across rounds" {
    try std.testing.expectEqual(@as(u32, 8), calculateBudget(1));
    try std.testing.expectEqual(@as(u32, 15), calculateBudget(2));
    try std.testing.expectEqual(@as(u32, 24), calculateBudget(3));
    try std.testing.expectEqual(@as(u32, 35), calculateBudget(4));
    try std.testing.expectEqual(@as(u32, 48), calculateBudget(5));
    try std.testing.expectEqual(@as(u32, 64), calculateBudget(6));
}

test "generateWaveConfig enemy composition and unlocks" {
    const r1 = generateWaveConfig(1);
    try std.testing.expectEqual(@as(u32, 8), r1.budget);
    try std.testing.expectEqual(@as(u32, 0), r1.elite_count);
    try std.testing.expectEqual(@as(u32, 0), r1.ranged_count);
    try std.testing.expectEqual(@as(u32, 8), r1.melee_count);
    try std.testing.expectEqual(@as(u32, 8), r1.total_enemies);

    const r2 = generateWaveConfig(2);
    try std.testing.expectEqual(@as(u32, 15), r2.budget);
    try std.testing.expectEqual(@as(u32, 0), r2.elite_count);
    try std.testing.expect(r2.ranged_count > 0);
    try std.testing.expect(r2.melee_count > 0);

    const r3 = generateWaveConfig(3);
    try std.testing.expectEqual(@as(u32, 24), r3.budget);
    try std.testing.expectEqual(@as(u32, 1), r3.elite_count);
    try std.testing.expect(r3.ranged_count > 0);
    try std.testing.expect(r3.melee_count > 0);

    const r5 = generateWaveConfig(5);
    try std.testing.expectEqual(@as(u32, 2), r5.elite_count);
}

test "populateQueue matches config enemy counts" {
    const config = generateWaveConfig(3);
    var queue = lm.List(EnemyType).init(std.testing.allocator);
    defer queue.deinit();

    try populateQueue(&queue, config);

    try std.testing.expectEqual(config.total_enemies, @as(u32, @intCast(queue.len())));

    var melee_found: u32 = 0;
    var ranged_found: u32 = 0;
    var elite_found: u32 = 0;
    var angler_found: u32 = 0;
    var tank_found: u32 = 0;
    var shaman_found: u32 = 0;
    var magician_found: u32 = 0;
    var lifeliner_found: u32 = 0;

    for (queue.items()) |enemy_type| {
        switch (enemy_type) {
            .melee => melee_found += 1,
            .ranged => ranged_found += 1,
            .elite => elite_found += 1,
            .angler => angler_found += 1,
            .tank => tank_found += 1,
            .shaman => shaman_found += 1,
            .magician => magician_found += 1,
            .lifeliner => lifeliner_found += 1,
            else => {},
        }
    }

    try std.testing.expectEqual(config.melee_count, melee_found);
    try std.testing.expectEqual(config.ranged_count, ranged_found);
    try std.testing.expectEqual(config.elite_count, elite_found);
    try std.testing.expectEqual(config.angler_count, angler_found);
    try std.testing.expectEqual(config.tank_count, tank_found);
    try std.testing.expectEqual(config.shaman_count, shaman_found);
    try std.testing.expectEqual(config.magician_count, magician_found);
    try std.testing.expectEqual(config.lifeliner_count, lifeliner_found);
}

test "pickSpawnPosition stays in bounds and away from player" {
    const player_pos = lm.Vec2(0, 0);

    for (0..20) |_| {
        const pos = pickSpawnPosition(player_pos);
        try std.testing.expect(pos.x >= -1150 and pos.x <= 1150);
        try std.testing.expect(pos.y >= -550 and pos.y <= 550);

        const dist = std.math.hypot(pos.x, pos.y);
        try std.testing.expect(dist >= 400.0);
    }
}

test "RoundSpawner enforces MAX_CONCURRENT_ENEMIES <= 64" {
    var spawner = Self.init(std.testing.allocator);
    defer spawner.deinit();

    try spawner.startWave(100);
    try std.testing.expect(spawner.max_active_enemies <= MAX_CONCURRENT_ENEMIES);
    try std.testing.expectEqual(@as(usize, 64), MAX_CONCURRENT_ENEMIES);
}

test "RoundSpawner room profiles" {
    var spawner = Self.init(std.testing.allocator);
    defer spawner.deinit();

    try spawner.startWaveForRoom(0, .tutorial);
    try std.testing.expectEqual(@as(u32, 1), spawner.total_wave_enemies);
    try std.testing.expectEqual(EnemyType.dummy, spawner.spawn_queue.items()[0]);

    try spawner.startWaveForRoom(5, .mini_boss);
    try std.testing.expectEqual(@as(u32, 1), spawner.total_wave_enemies);
    try std.testing.expectEqual(EnemyType.mini_boss, spawner.spawn_queue.items()[0]);

    try spawner.startWaveForRoom(15, .boss);
    try std.testing.expectEqual(@as(u32, 1), spawner.total_wave_enemies);
    try std.testing.expectEqual(EnemyType.boss, spawner.spawn_queue.items()[0]);
}

test "RoundSpawner onEnemyDefeated updates active and killed count in O(1)" {
    var spawner = Self.init(std.testing.allocator);
    defer spawner.deinit();

    try spawner.startWave(1);
    try spawner.active_enemies.append(12345);
    try spawner.active_enemies.append(67890);
    try std.testing.expectEqual(@as(usize, 2), spawner.active_enemies.len());
    try std.testing.expectEqual(@as(u32, 0), spawner.killed_enemies);

    spawner.removeDefeatedEnemy(12345);
    try std.testing.expectEqual(@as(usize, 1), spawner.active_enemies.len());
    try std.testing.expectEqual(@as(u32, 1), spawner.killed_enemies);
    try std.testing.expectEqual(@as(u128, 67890), spawner.active_enemies.items()[0]);
}

test "RoundSpawner queue cursor progression" {
    var spawner = Self.init(std.testing.allocator);
    defer spawner.deinit();

    try spawner.startWave(1);
    const initial_queued = spawner.getProgress().queued;
    try std.testing.expect(initial_queued > 0);
    try std.testing.expectEqual(@as(usize, 0), spawner.spawn_cursor);

    spawner.spawn_cursor += 1;
    try std.testing.expectEqual(initial_queued - 1, spawner.getProgress().queued);
}

test "pickSpawnPositionWithConfig obeys custom boundaries and exclusion zones" {
    const custom_config = SpawnAreaConfig{
        .min_x = 100.0,
        .max_x = 500.0,
        .min_y = 100.0,
        .max_y = 500.0,
        .min_player_distance_pixels = 50.0,
        .exclusion_zones = &.{
            .{ .min = .init(200, 200), .max = .init(300, 300) },
        },
    };

    const player_position = lm.Vec2(0, 0);
    for (0..20) |_| {
        const spawn_position = pickSpawnPositionWithConfig(player_position, custom_config);
        try std.testing.expect(spawn_position.x >= 50.0 and spawn_position.x <= 550.0);
        try std.testing.expect(spawn_position.y >= 50.0 and spawn_position.y <= 550.0);
        const in_exclusion = spawn_position.x >= 200 and spawn_position.x <= 300 and spawn_position.y >= 200 and spawn_position.y <= 300;
        try std.testing.expect(!in_exclusion);
    }
}

test "RoundSpawner setMapBounds configures spawn area margins" {
    var spawner = Self.init(std.testing.allocator);
    defer spawner.deinit();

    spawner.setMapBounds(lm.Vec2(-800, -600), lm.Vec2(800, 600));
    try std.testing.expectEqual(@as(f32, -720.0), spawner.spawn_area.min_x);
    try std.testing.expectEqual(@as(f32, 720.0), spawner.spawn_area.max_x);
    try std.testing.expectEqual(@as(f32, -520.0), spawner.spawn_area.min_y);
    try std.testing.expectEqual(@as(f32, 520.0), spawner.spawn_area.max_y);
}

test "RoundSpawner registerSummonedEnemy dynamically tracks reinforcement adds" {
    var spawner = Self.init(std.testing.allocator);
    defer spawner.deinit();

    try spawner.startWaveForRoom(15, .boss);
    try std.testing.expectEqual(@as(u32, 1), spawner.total_wave_enemies);
    try std.testing.expectEqual(@as(usize, 0), spawner.active_enemies.len());

    try spawner.registerSummonedEnemy(99901);
    try spawner.registerSummonedEnemy(99902);
    try std.testing.expectEqual(@as(u32, 3), spawner.total_wave_enemies);
    try std.testing.expectEqual(@as(usize, 2), spawner.active_enemies.len());
    try std.testing.expect(!spawner.isWaveFinished());

    // Verify duplicate registration is idempotent
    try spawner.registerSummonedEnemy(99901);
    try std.testing.expectEqual(@as(u32, 3), spawner.total_wave_enemies);
    try std.testing.expectEqual(@as(usize, 2), spawner.active_enemies.len());

    spawner.removeDefeatedEnemy(99901);
    spawner.removeDefeatedEnemy(99902);
    try std.testing.expectEqual(@as(usize, 0), spawner.active_enemies.len());
    try std.testing.expectEqual(@as(u32, 2), spawner.killed_enemies);
}


test "RoundSpawner normal wave caps total enemies at 64" {
    const high_round_config = generateWaveConfigForProfile(50, .normal);
    try std.testing.expect(high_round_config.total_enemies <= MAX_CONCURRENT_ENEMIES);
    try std.testing.expectEqual(@as(u32, 64), high_round_config.total_enemies);
    try std.testing.expect(high_round_config.is_cap_reached);
    try std.testing.expect(high_round_config.post_cap_round_offset > 0);
}

test "RoundSpawner identifies first cap round and calculates post cap offsets" {
    const first_cap_round = getFirstCapRound();
    try std.testing.expect(first_cap_round > 1);

    const before_cap_config = generateWaveConfigForProfile(first_cap_round - 1, .normal);
    try std.testing.expect(!before_cap_config.is_cap_reached);
    try std.testing.expectEqual(@as(u32, 0), before_cap_config.post_cap_round_offset);

    const at_cap_config = generateWaveConfigForProfile(first_cap_round, .normal);
    try std.testing.expect(at_cap_config.is_cap_reached);
    try std.testing.expectEqual(@as(u32, 0), at_cap_config.post_cap_round_offset);

    const after_cap_config = generateWaveConfigForProfile(first_cap_round + 3, .normal);
    try std.testing.expect(after_cap_config.is_cap_reached);
    try std.testing.expectEqual(@as(u32, 3), after_cap_config.post_cap_round_offset);
}

test "RoundSpawner normal profile uses 5 second spawn interval and 64 max active enemies" {
    var spawner = Self.init(std.testing.allocator);
    defer spawner.deinit();

    try spawner.startWave(5);
    try std.testing.expectEqual(@as(f32, 5.0), spawner.spawn_interval_seconds);
    try std.testing.expectEqual(@as(u32, 64), spawner.max_active_enemies);
}

test "applyDynamicStatScalingToStats grants bonus armour, magic resist, health, and damage in post-cap rounds" {
    const first_cap_round = getFirstCapRound();
    var base_stats = Stats.init(.enemy, .{
        .health = 100,
        .physical_damage = 20,
        .magic_damage = 10,
        .armour = 10,
        .magic_resist = 5,
    });
    defer base_stats.deinit();

    // Round at cap (standard scaling only, no post-cap bonus yet)
    applyDynamicStatScalingToStats(&base_stats, .melee, first_cap_round);
    try std.testing.expectEqual(@as(f32, 10.0), base_stats.current.armour);
    try std.testing.expectEqual(@as(f32, 5.0), base_stats.current.magic_resist);

    // Post-cap round (+5 rounds beyond cap)
    var post_cap_stats = Stats.init(.enemy, .{
        .health = 100,
        .physical_damage = 20,
        .magic_damage = 10,
        .armour = 10,
        .magic_resist = 5,
    });
    defer post_cap_stats.deinit();

    applyDynamicStatScalingToStats(&post_cap_stats, .melee, first_cap_round + 5);
    // Expected bonus armour: 5 * 2.5 = 12.5 -> total 22.5
    try std.testing.expectEqual(@as(f32, 22.5), post_cap_stats.current.armour);
    // Expected bonus magic resist: 5 * 2.5 = 12.5 -> total 17.5
    try std.testing.expectEqual(@as(f32, 17.5), post_cap_stats.current.magic_resist);
    // Health and damage should be higher than standard scaling
    try std.testing.expect(post_cap_stats.current.health > base_stats.current.health);
    try std.testing.expect(post_cap_stats.current.physical_damage > base_stats.current.physical_damage);
}

test "pickSpawnPositionForEnemy routes to dedicated zone and falls back to all zone" {
    var spawner = Self.init(std.testing.allocator);
    defer spawner.deinit();

    const zones = [_]MapTypes.SpawnZoneRecord{
        .{
            .center_x_pixels = 500.0,
            .center_y_pixels = 500.0,
            .width_pixels = 20.0,
            .height_pixels = 20.0,
            .enemy_type = .ranged,
        },
        .{
            .center_x_pixels = -500.0,
            .center_y_pixels = -500.0,
            .width_pixels = 20.0,
            .height_pixels = 20.0,
            .enemy_type = .melee,
        },
        .{
            .center_x_pixels = 0.0,
            .center_y_pixels = 500.0,
            .width_pixels = 20.0,
            .height_pixels = 20.0,
            .enemy_type = null, // "All" zone
        },
    };
    spawner.setSpawnZones(&zones);

    const player_position = lm.Vec2(0, 0);

    // Ranged enemy should pick the ranged zone near (500, 500)
    const ranged_spawn = spawner.pickSpawnPositionForEnemy(player_position, .ranged).?;
    try std.testing.expect(ranged_spawn.x >= 480.0 and ranged_spawn.x <= 520.0);
    try std.testing.expect(ranged_spawn.y >= 480.0 and ranged_spawn.y <= 520.0);

    // Melee enemy should pick the melee zone near (-500, -500)
    const melee_spawn = spawner.pickSpawnPositionForEnemy(player_position, .melee).?;
    try std.testing.expect(melee_spawn.x >= -520.0 and melee_spawn.x <= -480.0);
    try std.testing.expect(melee_spawn.y >= -520.0 and melee_spawn.y <= -480.0);

    // Tank enemy has no dedicated zone, should fall back to the "All" zone near (0, 500)
    const tank_spawn = spawner.pickSpawnPositionForEnemy(player_position, .tank).?;
    try std.testing.expect(tank_spawn.x >= -20.0 and tank_spawn.x <= 20.0);
    try std.testing.expect(tank_spawn.y >= 480.0 and tank_spawn.y <= 520.0);
}

test "generateWaveConfigForProfileAndZones omits enemy types without designated spawn zones" {
    const zones = [_]MapTypes.SpawnZoneRecord{
        .{
            .center_x_pixels = 100.0,
            .center_y_pixels = 100.0,
            .width_pixels = 64.0,
            .height_pixels = 64.0,
            .enemy_type = .tank,
        },
        .{
            .center_x_pixels = 200.0,
            .center_y_pixels = 200.0,
            .width_pixels = 64.0,
            .height_pixels = 64.0,
            .enemy_type = .ranged,
        },
    };

    // Round 4 normally unlocks elite, tank, shaman, magician, lifeliner, angler, ranged, melee
    const config = generateWaveConfigForProfileAndZones(4, .normal, &zones);
    try std.testing.expect(config.tank_count > 0);
    try std.testing.expect(config.ranged_count > 0);
    try std.testing.expectEqual(@as(u32, 0), config.angler_count);
    try std.testing.expectEqual(@as(u32, 0), config.melee_count);
    try std.testing.expectEqual(@as(u32, 0), config.shaman_count);
    try std.testing.expectEqual(@as(u32, 0), config.magician_count);
    try std.testing.expectEqual(@as(u32, 0), config.lifeliner_count);
    try std.testing.expectEqual(@as(u32, 0), config.elite_count);
    try std.testing.expectEqual(config.tank_count + config.ranged_count, config.total_enemies);
}

test "pickSpawnPositionForEnemy returns null when map has zones but none for enemy type and no all zone" {
    var spawner = Self.init(std.testing.allocator);
    defer spawner.deinit();

    const zones = [_]MapTypes.SpawnZoneRecord{
        .{
            .center_x_pixels = 300.0,
            .center_y_pixels = 300.0,
            .width_pixels = 50.0,
            .height_pixels = 50.0,
            .enemy_type = .tank,
        },
        .{
            .center_x_pixels = -300.0,
            .center_y_pixels = -300.0,
            .width_pixels = 50.0,
            .height_pixels = 50.0,
            .enemy_type = .melee,
        },
    };
    spawner.setSpawnZones(&zones);

    const player_position = lm.Vec2(0, 0);

    // Tank and Melee have designated zones and should return valid positions
    try std.testing.expect(spawner.pickSpawnPositionForEnemy(player_position, .tank) != null);
    try std.testing.expect(spawner.pickSpawnPositionForEnemy(player_position, .melee) != null);

    // Angler and Ranged do not have designated zones and map has no 'All' zone -> must return null
    try std.testing.expectEqual(@as(?lm.Vector2, null), spawner.pickSpawnPositionForEnemy(player_position, .angler));
    try std.testing.expectEqual(@as(?lm.Vector2, null), spawner.pickSpawnPositionForEnemy(player_position, .ranged));
    try std.testing.expectEqual(@as(?lm.Vector2, null), spawner.pickSpawnPositionForEnemy(player_position, .elite));
}
