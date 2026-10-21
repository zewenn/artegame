const std = @import("std");
const lm = @import("loom");
const SpatialAudio = @import("../audio/SpatialAudio.zig");
const MapTypes = @import("../map/MapTypes.zig");
const Stats = @import("../../components/Stats.zig");
const BossBar = @import("../ui/BossBar.zig");

pub const EnemyType = @import("../../components/enemy/EnemyType.zig").EnemyType;

pub const MAX_CONCURRENT_ENEMIES = 64;
const NORMAL_ROUND_SCALING = struct {
    pub const LOG_BASE = 1.025;
    pub const ADJUSTMENT = 10;
    pub const MAX_WAVE_BUDGET = 256;

    pub const FIRST_CAP_ROUND: comptime_int = lm.tou32(@ceil(std.math.pow(f32, NORMAL_ROUND_SCALING.LOG_BASE, NORMAL_ROUND_SCALING.MAX_WAVE_BUDGET + NORMAL_ROUND_SCALING.ADJUSTMENT)));
};

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
    counts: WaveSpawnCounts = .{},
    is_cap_reached: bool = false,
    post_cap_round_offset: u32 = 0,

    pub fn getCount(self: WaveConfig, enemy_type: EnemyType) u32 {
        switch (enemy_type) {
            inline else => |tag| {
                return @field(self.counts, @tagName(tag) ++ "_count");
            },
        }
    }
};

pub const WaveProgress = struct {
    round: u32 = 0,
    killed: u32 = 0,
    total: u32 = 0,
    active: u32 = 0,
    queued: u32 = 0,
};

const WaveSpawnCounts = make_struct: {
    const enemy_fields = std.meta.fields(EnemyType);
    var names: [enemy_fields.len][:0]const u8 = undefined;
    var types: [enemy_fields.len]type = undefined;
    var attributes: [enemy_fields.len]std.builtin.Type.StructField.Attributes = undefined;
    const default_count: u32 = 0;

    for (enemy_fields, 0..) |field, index| {
        names[index] = field.name ++ "_count";
        types[index] = u32;
        attributes[index] = .{
            .default_value_ptr = &default_count,
        };
    }

    break :make_struct @Struct(.auto, null, &names, &types, &attributes);
};

pub const EnemyComposition = struct {
    counts: WaveSpawnCounts = .{},

    pub fn total(self: EnemyComposition) u32 {
        var sum: u32 = 0;
        inline for (comptime std.meta.fieldNames(WaveSpawnCounts)) |field_name| {
            sum += @field(self.counts, field_name);
        }

        return sum;
    }

    pub fn addCount(self: *EnemyComposition, enemy_type: EnemyType, count: u32) void {
        switch (enemy_type) {
            inline else => |tag| {
                @field(self.counts, @tagName(tag) ++ "_count") += count;
            },
        }
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
    edge_depth: f32 = 80.0,
    exclusion_zones: []const ExclusionZone = &.{},
};

const Self = @This();

pub fn calculateBudgetForProfile(round: u32, profile: SpawnProfile) u32 {
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

pub fn hasDesignatedZone(zones: []const MapTypes.SpawnZoneRecord, enemy_type: EnemyType) bool {
    if (zones.len == 0) return true;
    for (zones) |zone| {
        if (zone.enemy_type == null) return true;
        if (zone.enemy_type.? == enemy_type) return true;
    }
    return false;
}

fn determineEnemiesForZonesFromCategory(zones: []const MapTypes.SpawnZoneRecord, category: []const EnemyType, fallback: EnemyType) EnemyType {
    if (zones.len == 0) return fallback;

    for (category) |enemy_type| {
        if (!hasDesignatedZone(zones, enemy_type)) continue;
        return enemy_type;
    }

    return fallback;
}

pub fn determineMiniBossTypeForZones(zones: []const MapTypes.SpawnZoneRecord) EnemyType {
    return determineEnemiesForZonesFromCategory(zones, EnemyType.mini_boss_enemies, .mini_boss);
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

pub fn generateWaveConfigForProfile(round: u32, profile: SpawnProfile) WaveConfig {
    return generateWaveConfigForProfileAndZones(round, profile, &.{});
}

pub fn generateWaveConfigForProfileAndZones(
    round: u32,
    profile: SpawnProfile,
    zones: []const MapTypes.SpawnZoneRecord,
) WaveConfig {
    var composition: EnemyComposition = .{};
    switch (profile) {
        .tutorial => composition.addCount(.dummy, 1),
        .mini_boss => composition.addCount(determineEnemiesForZonesFromCategory(zones, EnemyType.mini_boss_enemies, .mini_boss), 1),
        .boss => composition.addCount(determineEnemiesForZonesFromCategory(zones, EnemyType.boss_enemies, .boss), 1),
        .normal => composition = calculateNormalEnemyCompositionWithZones(round, zones),
    }
    const budget = calculateBudgetForProfile(round, profile);

    const first_cap_round = NORMAL_ROUND_SCALING.FIRST_CAP_ROUND;
    const post_cap_round_offset: u32 = if (round > first_cap_round) round - first_cap_round else 0;

    return WaveConfig{
        .round = round,
        .profile = profile,
        .budget = budget,
        .counts = composition.counts,
        .total_enemies = composition.total(),
        .post_cap_round_offset = post_cap_round_offset,
        .is_cap_reached = profile == .normal and round >= first_cap_round,
    };
}

pub fn generateWaveConfig(round: u32) WaveConfig {
    return generateWaveConfigForProfile(round, .normal);
}

pub fn populateQueue(list: *lm.List(EnemyType), config: WaveConfig) !void {
    list.clearRetainingCapacity();

    inline for (comptime std.meta.fieldNames(EnemyType)) |field_name| {
        const count = @field(config.counts, field_name ++ "_count");
        for (0..count) |_| try list.append(@field(EnemyType, field_name));
    }

    if (config.profile != .normal)
        return;

    lm.random.shuffle(EnemyType, list.items());
}

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

fn zoneMatchesEnemyType(zone_enemy_type: ?EnemyType, target_enemy_type: ?EnemyType) bool {
    const target = target_enemy_type orelse return zone_enemy_type == null;
    const zone_type = zone_enemy_type orelse return false;

    if (zone_type == target) return true;
    if ((target == .knight or target == .bishop) and zone_type == .mini_boss) return true;
    if ((target == .king or target == .queen) and zone_type == .boss) return true;

    return false;
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
        var current_match_index: usize = 0;
        var selected_zone: ?MapTypes.SpawnZoneRecord = null;

        for (zones) |zone| {
            if (!zoneMatchesEnemyType(zone.enemy_type, target_enemy_type)) continue;

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
            self.max_active_enemies = 64;
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

    const first_cap_round = NORMAL_ROUND_SCALING.FIRST_CAP_ROUND;
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

        const enemy = try enemy_type.spawn(spawn_position);

        applyDynamicStatScaling(enemy, enemy_type, self.round);
        enemy_type.tryBindBossBar(enemy);

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

test "RoundSpawner enforces MAX_CONCURRENT_ENEMIES" {
    var spawner = Self.init(std.testing.allocator);
    defer spawner.deinit();

    try spawner.startWave(100);
    try std.testing.expect(spawner.max_active_enemies <= MAX_CONCURRENT_ENEMIES);
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

test "RoundSpawner identifies first cap round and calculates post cap offsets" {
    const first_cap_round = NORMAL_ROUND_SCALING.FIRST_CAP_ROUND;
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
    const first_cap_round = NORMAL_ROUND_SCALING.FIRST_CAP_ROUND;
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
