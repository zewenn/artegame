const std = @import("std");
const lm = @import("loom");
const prefabs = @import("../../prefabs/prefabs.zig");
const SpatialAudio = @import("../audio/SpatialAudio.zig");
const MapTypes = @import("../map/MapTypes.zig");
const Stats = @import("../../components/Stats.zig");

pub const EnemyType = enum {
    dummy,
    melee,
    ranged,
    elite,
    mini_boss,
    boss,

    pub fn cost(self: EnemyType) u32 {
        return switch (self) {
            .dummy => 0,
            .melee => 1,
            .ranged => 2,
            .elite => 5,
            .mini_boss => 20,
            .boss => 100,
        };
    }
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
    dummy_count: u32 = 0,
    melee_count: u32 = 0,
    ranged_count: u32 = 0,
    elite_count: u32 = 0,
    mini_boss_count: u32 = 0,
    boss_count: u32 = 0,
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

pub fn generateWaveConfigForProfile(round: u32, profile: SpawnProfile) WaveConfig {
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
            var remaining_budget = total_budget;

            var elite_count: u32 = 0;
            if (round >= 3) {
                elite_count = @min(1 + (round - 3) / 2, 16);
                const elite_cost = elite_count * EnemyType.elite.cost();
                if (remaining_budget > elite_cost) {
                    remaining_budget -= elite_cost;
                } else {
                    elite_count = remaining_budget / EnemyType.elite.cost();
                    remaining_budget -= elite_count * EnemyType.elite.cost();
                }
            }

            var ranged_count: u32 = 0;
            if (round >= 2 and remaining_budget > 0) {
                const ranged_budget = (remaining_budget * 35) / 100;
                ranged_count = ranged_budget / EnemyType.ranged.cost();
                remaining_budget -= ranged_count * EnemyType.ranged.cost();
            }

            var melee_count = remaining_budget;
            var total_enemies = elite_count + ranged_count + melee_count;

            if (total_enemies > MAX_CONCURRENT_ENEMIES) {
                const excess = total_enemies - @as(u32, @intCast(MAX_CONCURRENT_ENEMIES));
                if (melee_count >= excess) {
                    melee_count -= excess;
                } else {
                    melee_count = 0;
                }
                total_enemies = elite_count + ranged_count + melee_count;
            }

            return WaveConfig{
                .round = round,
                .profile = .normal,
                .budget = total_budget,
                .total_enemies = total_enemies,
                .melee_count = melee_count,
                .ranged_count = ranged_count,
                .elite_count = elite_count,
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
    var elite_left = config.elite_count;

    const vanguard = @min(melee_left, 3);
    for (0..vanguard) |_| {
        try list.append(.melee);
        melee_left -= 1;
    }

    while (melee_left > 0 or ranged_left > 0 or elite_left > 0) {
        const melee_batch = @min(melee_left, 2);
        for (0..melee_batch) |_| {
            try list.append(.melee);
            melee_left -= 1;
        }

        if (ranged_left > 0) {
            try list.append(.ranged);
            ranged_left -= 1;
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

pub const MAX_CONCURRENT_ENEMIES: usize = 256;

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
spawn_interval_seconds: f32 = 0.65,
max_active_enemies: u32 = 12,

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

pub fn pickSpawnPositionFromZonesOrConfig(self: *Self, player_position: lm.Vector2) lm.Vector2 {
    if (self.spawn_zones.len > 0) {
        var attempt: usize = 0;
        while (attempt < 10) : (attempt += 1) {
            const random_zone_index = lm.random.intRangeLessThan(usize, 0, self.spawn_zones.len);
            const selected_zone = self.spawn_zones[random_zone_index];
            const half_width = selected_zone.width_pixels / 2.0;
            const half_height = selected_zone.height_pixels / 2.0;

            const spawn_x = selected_zone.center_x_pixels + lm.randFloat(f32, -half_width, half_width);
            const spawn_y = selected_zone.center_y_pixels + lm.randFloat(f32, -half_height, half_height);
            const spawn_position = lm.Vec2(spawn_x, spawn_y);

            const distance_to_player = std.math.hypot(spawn_x - player_position.x, spawn_y - player_position.y);
            if (distance_to_player >= 200.0 or attempt >= 8) {
                return spawn_position;
            }
        }
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
}

pub fn startWaveForRoom(self: *Self, round: u32, profile: SpawnProfile) !void {
    self.round = round;
    self.profile = profile;
    const config = generateWaveConfigForProfile(round, profile);
    self.total_wave_enemies = config.total_enemies;
    self.killed_enemies = 0;
    self.spawn_cursor = 0;

    try populateQueue(&self.spawn_queue, config);
    self.active_enemies.clearRetainingCapacity();

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
            self.max_active_enemies = @min(@max(12, 10 + round * 6), @as(u32, @intCast(MAX_CONCURRENT_ENEMIES)));
            self.spawn_interval_seconds = @max(0.18, 0.65 - @as(f32, @floatFromInt(round)) * 0.02);
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
    const len = self.active_enemies.len();
    for (0..len) |index| {
        if (self.active_enemies.items()[index] == uuid) {
            _ = self.active_enemies.swapRemove(index);
            self.killed_enemies += 1;
            return;
        }
    }
}

pub fn registerSummonedEnemy(self: *Self, uuid: u128) !void {
    if (!self.is_active) return;
    self.total_wave_enemies += 1;
    try self.active_enemies.append(uuid);
}

pub fn applyDynamicStatScaling(enemy: *lm.Entity, enemy_type: EnemyType, round: u32) void {
    if (enemy_type == .dummy) return;
    const stats = enemy.getComponent(Stats) orelse return;

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
}

pub fn update(self: *Self, delta_seconds: f32, scene: ?*lm.Scene, player_position: lm.Vector2) !void {
    _ = scene;
    if (!self.is_active) return;

    if (self.spawn_cursor >= self.spawn_queue.len()) return;

    if (self.active_enemies.len() >= self.max_active_enemies or self.active_enemies.len() >= MAX_CONCURRENT_ENEMIES) return;

    self.spawn_timer_seconds -= delta_seconds;

    if (self.active_enemies.len() < 3) {
        self.spawn_timer_seconds -= delta_seconds * 0.5;
    }

    if (self.spawn_timer_seconds > 0) return;

    var spawn_batch_limit: usize = 1;
    if (self.active_enemies.len() < self.max_active_enemies / 3 and self.max_active_enemies > 16) {
        const headroom = self.max_active_enemies - @as(u32, @intCast(self.active_enemies.len()));
        spawn_batch_limit = @min(4, @min(headroom, @as(u32, @intCast(self.spawn_queue.len() - self.spawn_cursor))));
    }

    for (0..spawn_batch_limit) |_| {
        if (self.spawn_cursor >= self.spawn_queue.len()) break;
        if (self.active_enemies.len() >= self.max_active_enemies or self.active_enemies.len() >= MAX_CONCURRENT_ENEMIES) break;

        const enemy_type = self.spawn_queue.items()[self.spawn_cursor];
        self.spawn_cursor += 1;
        const spawn_position = self.pickSpawnPositionFromZonesOrConfig(player_position);

        const enemy = switch (enemy_type) {
            .dummy => try prefabs.enemies.Dummy(spawn_position),
            .melee => try prefabs.enemies.Melee(spawn_position),
            .ranged => try prefabs.enemies.Ranged(spawn_position),
            .elite => try prefabs.enemies.Elite(spawn_position),
            .mini_boss => try prefabs.enemies.MiniBoss(spawn_position),
            .boss => try prefabs.enemies.Boss(spawn_position),
        };

        applyDynamicStatScaling(enemy, enemy_type, self.round);

        try self.active_enemies.append(enemy.uuid);
        try lm.summoning.entity(enemy);

        SpatialAudio.playSpatialPitched("audio/sfx/punch.mp3", spawn_position, player_position, 800.0, 0.35, 0.15);
    }

    self.spawn_timer_seconds = self.spawn_interval_seconds + lm.randFloat(f32, -0.05, 0.05);
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

// --------------------------------------------------------------------------------------------------
// Unit Tests
// --------------------------------------------------------------------------------------------------

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

    for (queue.items()) |enemy_type| {
        switch (enemy_type) {
            .melee => melee_found += 1,
            .ranged => ranged_found += 1,
            .elite => elite_found += 1,
            else => {},
        }
    }

    try std.testing.expectEqual(config.melee_count, melee_found);
    try std.testing.expectEqual(config.ranged_count, ranged_found);
    try std.testing.expectEqual(config.elite_count, elite_found);
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

test "RoundSpawner enforces MAX_CONCURRENT_ENEMIES <= 256" {
    var spawner = Self.init(std.testing.allocator);
    defer spawner.deinit();

    try spawner.startWave(100);
    try std.testing.expect(spawner.max_active_enemies <= MAX_CONCURRENT_ENEMIES);
    try std.testing.expect(MAX_CONCURRENT_ENEMIES <= 256);
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

    spawner.removeDefeatedEnemy(99901);
    spawner.removeDefeatedEnemy(99902);
    try std.testing.expectEqual(@as(usize, 0), spawner.active_enemies.len());
    try std.testing.expectEqual(@as(u32, 2), spawner.killed_enemies);
}

test "RoundSpawner normal wave caps total enemies at 256" {
    const high_round_config = generateWaveConfigForProfile(50, .normal);
    try std.testing.expect(high_round_config.total_enemies <= MAX_CONCURRENT_ENEMIES);
    try std.testing.expectEqual(@as(u32, 256), high_round_config.total_enemies);
}

