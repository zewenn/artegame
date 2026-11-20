const std = @import("std");
const lm = @import("loom");
const SpatialAudio = @import("../audio/SpatialAudio.zig");
const MapTypes = @import("../map/MapTypes.zig");
const Stats = @import("../../components/Stats.zig");
const RoomType = @import("../RoomType.zig").RoomType;

pub const EnemyType = @import("../../components/enemy/EnemyType.zig").EnemyType;

pub const MAX_CONCURRENT_ENEMIES = 64;
const NORMAL_ROUND_SCALING = struct {
    pub const LOG_BASE = 1.025;
    pub const ADJUSTMENT = 10;
    pub const MAX_WAVE_BUDGET = 256;

    pub const FIRST_CAP_ROUND: comptime_int = lm.tou32(@ceil(std.math.pow(f32, NORMAL_ROUND_SCALING.LOG_BASE, NORMAL_ROUND_SCALING.MAX_WAVE_BUDGET + NORMAL_ROUND_SCALING.ADJUSTMENT)));
};

pub const WaveConfig = struct {
    round: u32,
    profile: RoomType = .normal,
    total_enemies: u32,
    counts: std.EnumArray(EnemyType, u32) = .initFill(0),
};

pub const WaveProgress = struct {
    round: u32 = 0,
    killed: u32 = 0,
    total: u32 = 0,
};

pub const EnemyComposition = struct {
    counts: std.EnumArray(EnemyType, u32) = .initFill(0),

    pub fn total(self: EnemyComposition) u32 {
        var sum: u32 = 0;
        for (std.enums.values(EnemyType)) |enemy_type| {
            sum += self.counts.get(enemy_type);
        }
        return sum;
    }

    pub fn addCount(self: *EnemyComposition, enemy_type: EnemyType, count: u32) void {
        self.counts.set(enemy_type, self.counts.get(enemy_type) + count);
    }
};

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
    edge_depth_pixels: f32 = 80.0,
    exclusion_zones: []const ExclusionZone = &.{},
};

const Self = @This();

spawn_queue: lm.List(EnemyType),
spawn_cursor: usize = 0,
active_enemies: lm.List(u128),
spawn_area: SpawnAreaConfig = .{},
spawn_zones: []const MapTypes.SpawnZoneRecord = &.{},

round: u32 = 0,
profile: RoomType = .normal,
total_wave_enemies: u32 = 0,
killed_enemies: u32 = 0,

spawn_timer_seconds: f32 = 0,
spawn_interval_seconds: f32 = 5.0,
max_active_enemies: u32 = 64,

is_active: bool = false,

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
}

pub fn setSpawnZones(self: *Self, zones: []const MapTypes.SpawnZoneRecord) void {
    self.spawn_zones = zones;
}

pub fn setMapBounds(self: *Self, min_bounds: lm.Vector2, max_bounds: lm.Vector2) void {
    const margin_pixels: f32 = 80.0;
    self.spawn_area.min_x = min_bounds.x + margin_pixels;
    self.spawn_area.max_x = max_bounds.x - margin_pixels;
    self.spawn_area.min_y = min_bounds.y + margin_pixels;
    self.spawn_area.max_y = max_bounds.y - margin_pixels;
}

pub fn startWaveForRoom(self: *Self, round: u32, profile: RoomType) !void {
    self.round = round;
    self.profile = profile;
    self.killed_enemies = 0;
    self.spawn_cursor = 0;

    const config = generateWaveConfigForProfileAndZones(round, profile, self.spawn_zones);
    self.total_wave_enemies = config.total_enemies;

    try populateQueue(&self.spawn_queue, config);
    self.active_enemies.clearRetainingCapacity();

    const room_metadata = profile.metadata();
    self.max_active_enemies = room_metadata.max_active_enemies;
    self.spawn_interval_seconds = room_metadata.spawn_interval_seconds;

    self.spawn_timer_seconds = 0.15;
    self.is_active = true;
}

pub fn startWave(self: *Self, round: u32) !void {
    try self.startWaveForRoom(round, .normal);
}

pub fn update(self: *Self, delta_seconds: f32, player_position: lm.Vector2) !void {
    if (!self.is_active) return;
    if (self.spawn_cursor >= self.spawn_queue.len()) return;
    if (self.isAtActiveEnemyCapacity()) return;

    self.spawn_timer_seconds -= delta_seconds;
    if (self.spawn_timer_seconds > 0) return;

    const spawn_batch_count = self.calculateSpawnBatchCount();
    if (spawn_batch_count == 0) return;

    for (0..spawn_batch_count) |_| {
        if (self.spawn_cursor >= self.spawn_queue.len()) break;
        if (self.isAtActiveEnemyCapacity()) break;

        try self.spawnNextQueuedEnemy(player_position);
    }

    self.spawn_timer_seconds = self.spawn_interval_seconds;
}

fn isAtActiveEnemyCapacity(self: *const Self) bool {
    const active_count = self.active_enemies.len();
    return active_count >= self.max_active_enemies or active_count >= MAX_CONCURRENT_ENEMIES;
}

fn calculateSpawnBatchCount(self: *const Self) usize {
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

    return @min(target_batch_size, @min(@as(usize, active_capacity), remaining_in_queue));
}

fn spawnNextQueuedEnemy(self: *Self, player_position: lm.Vector2) !void {
    const enemy_type = self.spawn_queue.items()[self.spawn_cursor];
    self.spawn_cursor += 1;

    const spawn_position = self.pickSpawnPositionForEnemy(player_position, enemy_type) orelse {
        if (self.total_wave_enemies > 0) self.total_wave_enemies -= 1;
        return;
    };

    const enemy = try enemy_type.spawn(spawn_position);
    applyDynamicStatScaling(enemy, enemy_type, self.round);

    try self.active_enemies.append(enemy.uuid);
    try lm.summoning.entity(enemy);

    SpatialAudio.playSpatialPitched("audio/sfx/punch.mp3", spawn_position, player_position, 800.0, 0.35, 0.15);
}

pub fn removeDefeatedEnemy(self: *Self, uuid: u128) void {
    if (!self.is_active) return;

    for (self.active_enemies.items(), 0..) |enemy_uuid, index| {
        if (uuid != enemy_uuid) continue;

        _ = self.active_enemies.swapRemove(index);
        self.killed_enemies += 1;
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

pub fn isWaveFinished(self: *const Self) bool {
    if (!self.is_active) return false;
    return self.spawn_cursor >= self.spawn_queue.len() and self.active_enemies.len() == 0;
}

pub fn finishWave(self: *Self) void {
    self.is_active = false;
}

pub fn getProgress(self: *const Self) WaveProgress {
    return WaveProgress{
        .round = self.round,
        .killed = self.killed_enemies,
        .total = self.total_wave_enemies,
    };
}

pub fn calculateBudgetForProfile(round: u32, profile: RoomType) u32 {
    return switch (profile) {
        .tutorial => 0,
        .mini_boss => 20,
        .boss => 100,
        .normal => @max(
            8,
            @min(
                NORMAL_ROUND_SCALING.MAX_WAVE_BUDGET,
                lm.tou32(@ceil(std.math.log(f32, NORMAL_ROUND_SCALING.LOG_BASE, lm.tof32(round)) - NORMAL_ROUND_SCALING.ADJUSTMENT)),
            ),
        ),
    };
}

pub fn hasDesignatedZone(zones: []const MapTypes.SpawnZoneRecord, enemy_type: EnemyType) bool {
    if (zones.len == 0) return true;
    for (zones) |zone| {
        if (zone.enemy_type == null) return true;
        if (zone.enemy_type.? == enemy_type) return true;
    }
    return false;
}

pub fn calculateNormalEnemyCompositionWithZones(
    round: u32,
    zones: []const MapTypes.SpawnZoneRecord,
) EnemyComposition {
    const total_budget = calculateBudgetForProfile(round, .normal);
    var remaining_budget = total_budget;
    var composition = EnemyComposition{};

    allocateSpecialistEnemies(round, zones, &remaining_budget, &composition);
    allocateFillerEnemies(round, zones, &remaining_budget, &composition);
    handleRestrictedZoneFallbacks(zones, &remaining_budget, &composition);

    return composition;
}

pub fn generateWaveConfigForProfile(round: u32, profile: RoomType) WaveConfig {
    return generateWaveConfigForProfileAndZones(round, profile, &.{});
}

pub fn generateWaveConfigForProfileAndZones(
    round: u32,
    profile: RoomType,
    zones: []const MapTypes.SpawnZoneRecord,
) WaveConfig {
    var composition: EnemyComposition = .{};
    switch (profile) {
        .tutorial => {},
        .mini_boss => composition.addCount(determineEnemiesForZonesFromCategory(zones, EnemyType.mini_boss_enemies, .mini_boss), 1),
        .boss => composition.addCount(determineEnemiesForZonesFromCategory(zones, EnemyType.boss_enemies, .boss), 1),
        .normal => composition = calculateNormalEnemyCompositionWithZones(round, zones),
    }

    return WaveConfig{
        .round = round,
        .profile = profile,
        .counts = composition.counts,
        .total_enemies = composition.total(),
    };
}

pub fn populateQueue(list: *lm.List(EnemyType), config: WaveConfig) !void {
    list.clearRetainingCapacity();

    for (std.enums.values(EnemyType)) |enemy_type| {
        const count = config.counts.get(enemy_type);
        for (0..count) |_| {
            try list.append(enemy_type);
        }
    }

    if (config.profile != .normal) return;

    lm.random.shuffle(EnemyType, list.items());
}

pub fn pickSpawnPositionWithConfig(player_position: lm.Vector2, config: SpawnAreaConfig) lm.Vector2 {
    var attempt_index: usize = 0;
    while (attempt_index < 10) : (attempt_index += 1) {
        const candidate_position = sampleEdgePosition(config);
        if (isInsideExclusionZone(candidate_position, config.exclusion_zones)) continue;

        const distance_to_player_pixels = std.math.hypot(
            candidate_position.x - player_position.x,
            candidate_position.y - player_position.y,
        );
        if (distance_to_player_pixels >= config.min_player_distance_pixels) {
            return candidate_position;
        }
    }

    const fallback_x = if (player_position.x > 0) config.min_x + 50 else config.max_x - 50;
    const fallback_y = if (player_position.y > 0) config.min_y + 50 else config.max_y - 50;
    return lm.Vec2(fallback_x, fallback_y);
}

pub fn pickSpawnPosition(player_position: lm.Vector2) lm.Vector2 {
    return pickSpawnPositionWithConfig(player_position, .{});
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

pub fn applyDynamicStatScalingToStats(stats: *Stats, _: EnemyType, round: u32) void {
    if (round <= 1) return;

    const round_offset: f32 = @floatFromInt(round - 1);
    const health_multiplier: f32 = 1.0 + round_offset * 0.08;
    const damage_multiplier: f32 = 1.0 + round_offset * 0.04;
    const speed_multiplier: f32 = @min(1.25, 1.0 + round_offset * 0.015);

    applyStatMultipliers(stats, health_multiplier, damage_multiplier, speed_multiplier);

    const first_cap_round = NORMAL_ROUND_SCALING.FIRST_CAP_ROUND;
    if (round <= first_cap_round) return;

    const post_cap_offset_float: f32 = @floatFromInt(round - first_cap_round);
    const bonus_health_multiplier: f32 = 1.0 + post_cap_offset_float * 0.10;
    const bonus_damage_multiplier: f32 = 1.0 + post_cap_offset_float * 0.05;
    applyStatMultipliers(stats, bonus_health_multiplier, bonus_damage_multiplier, 1.0);

    const bonus_defense: f32 = post_cap_offset_float * 2.5;
    stats.current.armour += bonus_defense;
    stats.base.armour += bonus_defense;
    stats.max.armour += bonus_defense;

    stats.current.magic_resist += bonus_defense;
    stats.base.magic_resist += bonus_defense;
    stats.max.magic_resist += bonus_defense;
}

pub fn applyDynamicStatScaling(enemy: *lm.Entity, enemy_type: EnemyType, round: u32) void {
    const stats = enemy.getComponent(Stats) orelse (enemy.getComponentUnsafe(Stats).result orelse return);
    applyDynamicStatScalingToStats(stats, enemy_type, round);
}

fn applyStatMultipliers(
    stats: *Stats,
    health_multiplier: f32,
    damage_multiplier: f32,
    speed_multiplier: f32,
) void {
    stats.max.health *= health_multiplier;
    stats.current.health = stats.max.health;
    stats.base.health = stats.max.health;

    stats.current.physical_damage *= damage_multiplier;
    stats.base.physical_damage *= damage_multiplier;
    stats.current.magic_damage *= damage_multiplier;
    stats.base.magic_damage *= damage_multiplier;

    stats.current.movement_speed *= speed_multiplier;
    stats.base.movement_speed *= speed_multiplier;
}

fn sampleEdgePosition(config: SpawnAreaConfig) lm.Vector2 {
    const edge = lm.random.intRangeAtMost(u32, 0, 3);
    return switch (edge) {
        0 => lm.Vec2(config.min_x + lm.randFloat(f32, 0, config.edge_depth_pixels), lm.randFloat(f32, config.min_y, config.max_y)),
        1 => lm.Vec2(config.max_x - lm.randFloat(f32, 0, config.edge_depth_pixels), lm.randFloat(f32, config.min_y, config.max_y)),
        2 => lm.Vec2(lm.randFloat(f32, config.min_x, config.max_x), config.min_y + lm.randFloat(f32, 0, config.edge_depth_pixels)),
        else => lm.Vec2(lm.randFloat(f32, config.min_x, config.max_x), config.max_y - lm.randFloat(f32, 0, config.edge_depth_pixels)),
    };
}

fn isInsideExclusionZone(candidate_position: lm.Vector2, exclusion_zones: []const ExclusionZone) bool {
    for (exclusion_zones) |zone| {
        if (zone.contains(candidate_position)) return true;
    }
    return false;
}

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

fn determineEnemiesForZonesFromCategory(zones: []const MapTypes.SpawnZoneRecord, category: []const EnemyType, fallback: EnemyType) EnemyType {
    if (zones.len == 0) return fallback;

    for (category) |enemy_type| {
        if (!hasDesignatedZone(zones, enemy_type)) continue;
        return enemy_type;
    }

    return fallback;
}

fn countDesignatedSpecialistTypes(zones: []const MapTypes.SpawnZoneRecord) u32 {
    var count: u32 = 0;
    for (EnemyType.normal_specialist_enemies) |enemy_type| {
        if (hasDesignatedZone(zones, enemy_type)) {
            count += 1;
        }
    }
    return count;
}

fn allocateRemainingBudgetToDesignatedZones(
    zones: []const MapTypes.SpawnZoneRecord,
    remaining_budget: *u32,
    composition: *EnemyComposition,
) void {
    if (remaining_budget.* == 0) return;
    const designated_type_count = countDesignatedSpecialistTypes(zones);
    if (designated_type_count == 0) return;

    const budget_slice = remaining_budget.* / designated_type_count;

    for (EnemyType.normal_specialist_enemies) |enemy_type| {
        if (!hasDesignatedZone(zones, enemy_type)) continue;

        const type_budget = if (designated_type_count > 1) budget_slice else remaining_budget.*;
        const additional_count = type_budget / enemy_type.cost();
        composition.addCount(enemy_type, additional_count);
        const cost_spent = additional_count * enemy_type.cost();
        if (remaining_budget.* >= cost_spent) {
            remaining_budget.* -= cost_spent;
        }
    }
}

fn fallbackSpawnPermittedEnemies(
    zones: []const MapTypes.SpawnZoneRecord,
    remaining_budget: *u32,
    composition: *EnemyComposition,
) void {
    for (EnemyType.normal_specialist_enemies) |enemy_type| {
        if (!hasDesignatedZone(zones, enemy_type)) continue;

        const count = @max(1, remaining_budget.* / enemy_type.cost());
        composition.addCount(enemy_type, count);
        const cost_spent = count * enemy_type.cost();
        if (remaining_budget.* >= cost_spent) {
            remaining_budget.* -= cost_spent;
        } else {
            remaining_budget.* = 0;
        }
        return;
    }
}

fn allocateSpecialistEnemies(
    round: u32,
    zones: []const MapTypes.SpawnZoneRecord,
    remaining_budget: *u32,
    composition: *EnemyComposition,
) void {
    inline for (EnemyType.normal_specialist_enemies) |enemy_type| {
        const rule = comptime enemy_type.normalWaveRule().?;
        const count = calculateScaledEnemyCount(round, remaining_budget, zones, enemy_type, rule);
        composition.addCount(enemy_type, count);
    }
}

fn hasSubsequentPermittedFiller(
    round: u32,
    zones: []const MapTypes.SpawnZoneRecord,
    current_index: usize,
) bool {
    const filler_types = EnemyType.normal_filler_enemies;
    for (filler_types[current_index + 1 ..]) |filler_type| {
        const rule = filler_type.normalFillerRule() orelse continue;
        if (round < rule.unlock_round) continue;
        if (hasDesignatedZone(zones, filler_type)) return true;
    }
    return false;
}

fn allocateFillerEnemies(
    round: u32,
    zones: []const MapTypes.SpawnZoneRecord,
    remaining_budget: *u32,
    composition: *EnemyComposition,
) void {
    if (remaining_budget.* == 0) return;

    for (EnemyType.normal_filler_enemies, 0..) |enemy_type, filler_index| {
        if (remaining_budget.* == 0) break;

        const rule = enemy_type.normalFillerRule() orelse continue;
        if (round < rule.unlock_round) continue;
        if (!hasDesignatedZone(zones, enemy_type)) continue;

        const has_subsequent_filler = hasSubsequentPermittedFiller(round, zones, filler_index);
        const enemy_budget = if (has_subsequent_filler)
            (remaining_budget.* * rule.budget_share_percentage) / 100
        else
            remaining_budget.*;

        const count = enemy_budget / enemy_type.cost();
        composition.addCount(enemy_type, count);
        remaining_budget.* -= count * enemy_type.cost();
    }
}

fn hasAnyDesignatedFillerZone(zones: []const MapTypes.SpawnZoneRecord) bool {
    for (EnemyType.normal_filler_enemies) |filler_type| {
        if (hasDesignatedZone(zones, filler_type)) return true;
    }
    return false;
}

fn handleRestrictedZoneFallbacks(
    zones: []const MapTypes.SpawnZoneRecord,
    remaining_budget: *u32,
    composition: *EnemyComposition,
) void {
    if (zones.len == 0) return;

    if (composition.total() == 0) {
        fallbackSpawnPermittedEnemies(zones, remaining_budget, composition);
        return;
    }

    if (remaining_budget.* > 0 and !hasAnyDesignatedFillerZone(zones)) {
        allocateRemainingBudgetToDesignatedZones(zones, remaining_budget, composition);
    }
}

fn zoneMatchesEnemyType(zone_enemy_type: ?EnemyType, target_enemy_type: ?EnemyType) bool {
    const target = target_enemy_type orelse return zone_enemy_type == null;
    const zone_type = zone_enemy_type orelse return false;

    if (zone_type == target) return true;

    const target_rank = target.bossRank() orelse return false;
    return switch (target_rank) {
        .mini_boss => zone_type == .mini_boss,
        .boss => zone_type == .boss,
    };
}

fn findMatchingZoneAtOffset(
    zones: []const MapTypes.SpawnZoneRecord,
    target_enemy_type: ?EnemyType,
    target_match_index: usize,
) ?MapTypes.SpawnZoneRecord {
    var current_match_index: usize = 0;
    for (zones) |zone| {
        if (!zoneMatchesEnemyType(zone.enemy_type, target_enemy_type)) continue;
        if (current_match_index == target_match_index) return zone;
        current_match_index += 1;
    }
    return null;
}

fn pickSpawnPositionFromMatchingOrAnyZone(
    zones: []const MapTypes.SpawnZoneRecord,
    target_enemy_type: ?EnemyType,
    player_position: lm.Vector2,
) ?lm.Vector2 {
    var match_count: usize = 0;
    for (zones) |zone| {
        if (zoneMatchesEnemyType(zone.enemy_type, target_enemy_type)) {
            match_count += 1;
        }
    }
    if (match_count == 0) return null;

    var attempt_count: usize = 0;
    while (attempt_count < 10) : (attempt_count += 1) {
        const selected_match_index = lm.random.intRangeLessThan(usize, 0, match_count);
        const zone = findMatchingZoneAtOffset(zones, target_enemy_type, selected_match_index) orelse continue;

        const half_width_pixels = zone.width_pixels / 2.0;
        const half_height_pixels = zone.height_pixels / 2.0;
        const spawn_position = lm.Vec2(
            zone.center_x_pixels + lm.randFloat(f32, -half_width_pixels, half_width_pixels),
            zone.center_y_pixels + lm.randFloat(f32, -half_height_pixels, half_height_pixels),
        );

        const distance_to_player_pixels = std.math.hypot(spawn_position.x - player_position.x, spawn_position.y - player_position.y);
        if (distance_to_player_pixels >= 200.0 or attempt_count >= 8) {
            return spawn_position;
        }
    }

    return null;
}

test "pickSpawnPosition stays in bounds and away from player" {
    const player_position = lm.Vec2(0, 0);

    for (0..20) |_| {
        const spawn_position = pickSpawnPosition(player_position);
        try std.testing.expect(spawn_position.x >= -1150 and spawn_position.x <= 1150);
        try std.testing.expect(spawn_position.y >= -550 and spawn_position.y <= 550);

        const distance_pixels = std.math.hypot(spawn_position.x, spawn_position.y);
        try std.testing.expect(distance_pixels >= 400.0);
    }
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

    try spawner.registerSummonedEnemy(99901);
    try std.testing.expectEqual(@as(u32, 3), spawner.total_wave_enemies);
    try std.testing.expectEqual(@as(usize, 2), spawner.active_enemies.len());

    spawner.removeDefeatedEnemy(99901);
    spawner.removeDefeatedEnemy(99902);
    try std.testing.expectEqual(@as(usize, 0), spawner.active_enemies.len());
    try std.testing.expectEqual(@as(u32, 2), spawner.killed_enemies);
}

test "RoundSpawner budget caps at MAX_WAVE_BUDGET after FIRST_CAP_ROUND" {
    const first_cap_round = NORMAL_ROUND_SCALING.FIRST_CAP_ROUND;
    try std.testing.expect(first_cap_round > 1);

    try std.testing.expect(calculateBudgetForProfile(first_cap_round - 1, .normal) <= NORMAL_ROUND_SCALING.MAX_WAVE_BUDGET);
    try std.testing.expectEqual(@as(u32, NORMAL_ROUND_SCALING.MAX_WAVE_BUDGET), calculateBudgetForProfile(first_cap_round, .normal));
    try std.testing.expectEqual(@as(u32, NORMAL_ROUND_SCALING.MAX_WAVE_BUDGET), calculateBudgetForProfile(first_cap_round + 3, .normal));
}

test "applyDynamicStatScalingToStats grants bonus armour, magic resist, health, and damage in post-cap rounds" {
    const first_cap_round = NORMAL_ROUND_SCALING.FIRST_CAP_ROUND;
    var base_stats = Stats.init(.enemy, .{
        .health = 100,
        .physical_damage = 20,
        .magic_damage = 10,
        .armour = 10,
        .magic_resist = 5,
    });
    defer base_stats.deinit();

    applyDynamicStatScalingToStats(&base_stats, .melee, first_cap_round);
    try std.testing.expectEqual(@as(f32, 10.0), base_stats.current.armour);
    try std.testing.expectEqual(@as(f32, 5.0), base_stats.current.magic_resist);

    var post_cap_stats = Stats.init(.enemy, .{
        .health = 100,
        .physical_damage = 20,
        .magic_damage = 10,
        .armour = 10,
        .magic_resist = 5,
    });
    defer post_cap_stats.deinit();

    applyDynamicStatScalingToStats(&post_cap_stats, .melee, first_cap_round + 5);
    try std.testing.expectEqual(@as(f32, 22.5), post_cap_stats.current.armour);
    try std.testing.expectEqual(@as(f32, 17.5), post_cap_stats.current.magic_resist);
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
            .enemy_type = null,
        },
    };
    spawner.setSpawnZones(&zones);

    const player_position = lm.Vec2(0, 0);

    const ranged_spawn = spawner.pickSpawnPositionForEnemy(player_position, .ranged).?;
    try std.testing.expect(ranged_spawn.x >= 480.0 and ranged_spawn.x <= 520.0);
    try std.testing.expect(ranged_spawn.y >= 480.0 and ranged_spawn.y <= 520.0);

    const melee_spawn = spawner.pickSpawnPositionForEnemy(player_position, .melee).?;
    try std.testing.expect(melee_spawn.x >= -520.0 and melee_spawn.x <= -480.0);
    try std.testing.expect(melee_spawn.y >= -520.0 and melee_spawn.y <= -480.0);

    const tank_spawn = spawner.pickSpawnPositionForEnemy(player_position, .tank).?;
    try std.testing.expect(tank_spawn.x >= -20.0 and tank_spawn.x <= 20.0);
    try std.testing.expect(tank_spawn.y >= 480.0 and tank_spawn.y <= 520.0);
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

    try std.testing.expect(spawner.pickSpawnPositionForEnemy(player_position, .tank) != null);
    try std.testing.expect(spawner.pickSpawnPositionForEnemy(player_position, .melee) != null);

    try std.testing.expectEqual(@as(?lm.Vector2, null), spawner.pickSpawnPositionForEnemy(player_position, .angler));
    try std.testing.expectEqual(@as(?lm.Vector2, null), spawner.pickSpawnPositionForEnemy(player_position, .ranged));
    try std.testing.expectEqual(@as(?lm.Vector2, null), spawner.pickSpawnPositionForEnemy(player_position, .elite));
}
