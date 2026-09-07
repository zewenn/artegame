const std = @import("std");
const lm = @import("loom");
const prefabs = @import("../../prefabs/prefabs.zig");
const SpatialAudio = @import("../audio/SpatialAudio.zig");

pub const EnemyType = enum {
    melee,
    ranged,
    elite,

    pub fn cost(self: EnemyType) u32 {
        return switch (self) {
            .melee => 1,
            .ranged => 2,
            .elite => 5,
        };
    }
};

pub const WaveConfig = struct {
    round: u32,
    budget: u32,
    total_enemies: u32,
    melee_count: u32,
    ranged_count: u32,
    elite_count: u32,
};

pub const WaveProgress = struct {
    round: u32 = 0,
    killed: u32 = 0,
    total: u32 = 0,
    active: u32 = 0,
    queued: u32 = 0,
};

pub fn calculateBudget(round: u32) u32 {
    if (round <= 1) return 8;

    const r = round - 1;

    if (round <= 5) {
        return 8 + (r * 6) + (r * r);
    }

    return 48 + (round - 5) * 16;
}

pub fn generateWaveConfig(round: u32) WaveConfig {
    const total_budget = calculateBudget(round);
    var remaining_budget = total_budget;

    var elite_count: u32 = 0;
    if (round >= 3) {
        elite_count = @min(1 + (round - 3) / 2, 4);
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

    const melee_count = remaining_budget;
    const total_enemies = elite_count + ranged_count + melee_count;

    return WaveConfig{
        .round = round,
        .budget = total_budget,
        .total_enemies = total_enemies,
        .melee_count = melee_count,
        .ranged_count = ranged_count,
        .elite_count = elite_count,
    };
}

pub fn populateQueue(list: *lm.List(EnemyType), config: WaveConfig) !void {
    list.clearRetainingCapacity();

    var melee_left = config.melee_count;
    var ranged_left = config.ranged_count;
    var elite_left = config.elite_count;

    const vanguard = @min(melee_left, 3);
    for (0..vanguard) |_| {
        try list.append(.melee);
        melee_left -= 1;
    }

    while (melee_left > 0 or ranged_left > 0 or elite_left > 0) {
        const m_batch = @min(melee_left, 2);
        for (0..m_batch) |_| {
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

    pub fn contains(self: ExclusionZone, pos: lm.Vector2) bool {
        return pos.x >= self.min.x and pos.x <= self.max.x and pos.y >= self.min.y and pos.y <= self.max.y;
    }
};

pub const SpawnAreaConfig = struct {
    min_x: f32 = -1100.0,
    max_x: f32 = 1100.0,
    min_y: f32 = -520.0,
    max_y: f32 = 520.0,
    min_player_dist: f32 = 420.0,
    edge_depth: f32 = 80.0,
    exclusion_zones: []const ExclusionZone = &.{},
};

pub fn pickSpawnPositionWithConfig(player_pos: lm.Vector2, config: SpawnAreaConfig) lm.Vector2 {
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

        const dx = x - player_pos.x;
        const dy = y - player_pos.y;
        const dist = std.math.hypot(dx, dy);
        if (dist >= config.min_player_dist) {
            return lm.Vec2(x, y);
        }
    }

    const fallback_x = if (player_pos.x > 0) config.min_x + 50 else config.max_x - 50;
    const fallback_y = if (player_pos.y > 0) config.min_y + 50 else config.max_y - 50;
    return lm.Vec2(fallback_x, fallback_y);
}

pub fn pickSpawnPosition(player_pos: lm.Vector2) lm.Vector2 {
    return pickSpawnPositionWithConfig(player_pos, .{});
}

const Self = @This();

pub const MAX_CONCURRENT_ENEMIES: usize = 128;

spawn_queue: lm.List(EnemyType),
spawn_cursor: usize = 0,
active_enemies: lm.List(u128),
spawn_area: SpawnAreaConfig = .{},

round: u32 = 0,
total_wave_enemies: u32 = 0,
killed_enemies: u32 = 0,

spawn_timer: f32 = 0,
spawn_interval: f32 = 0.65,
max_active_enemies: u32 = 12,

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

pub fn startWave(self: *Self, round: u32) !void {
    self.round = round;
    const config = generateWaveConfig(round);
    self.total_wave_enemies = config.total_enemies;
    self.killed_enemies = 0;
    self.spawn_cursor = 0;

    try populateQueue(&self.spawn_queue, config);
    self.active_enemies.clearRetainingCapacity();

    self.max_active_enemies = @min(@min(10 + round * 2, 18), MAX_CONCURRENT_ENEMIES);
    self.spawn_interval = @max(0.40, 0.70 - @as(f32, @floatFromInt(round)) * 0.03);
    self.spawn_timer = 0.2;
    self.is_active = true;
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

pub fn update(self: *Self, dt: f32, scene: ?*lm.Scene, player_pos: lm.Vector2) !void {
    _ = scene;
    if (!self.is_active) return;

    if (self.spawn_cursor >= self.spawn_queue.len()) return;

    if (self.active_enemies.len() >= self.max_active_enemies or self.active_enemies.len() >= MAX_CONCURRENT_ENEMIES) return;

    self.spawn_timer -= dt;

    if (self.active_enemies.len() < 3) {
        self.spawn_timer -= dt * 0.5;
    }

    if (self.spawn_timer > 0) return;

    const enemy_type = self.spawn_queue.items()[self.spawn_cursor];
    self.spawn_cursor += 1;
    const pos = pickSpawnPositionWithConfig(player_pos, self.spawn_area);

    const enemy = switch (enemy_type) {
        .melee => try prefabs.enemies.Melee(pos),
        .ranged => try prefabs.enemies.Ranged(pos),
        .elite => try prefabs.enemies.Elite(pos),
    };

    try self.active_enemies.append(enemy.uuid);
    try lm.summoning.entity(enemy);

    SpatialAudio.playSpatialPitched("audio/sfx/punch.mp3", pos, player_pos, 800.0, 0.35, 0.15);

    self.spawn_timer = self.spawn_interval + lm.randFloat(f32, -0.08, 0.08);
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

    for (queue.items()) |enemy_type| {
        switch (enemy_type) {
            .melee => melee_found += 1,
            .ranged => ranged_found += 1,
            .elite => elite_found += 1,
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

test "RoundSpawner enforces MAX_CONCURRENT_ENEMIES <= 128" {
    var spawner = Self.init(std.testing.allocator);
    defer spawner.deinit();

    try spawner.startWave(100);
    try std.testing.expect(spawner.max_active_enemies <= MAX_CONCURRENT_ENEMIES);
    try std.testing.expect(MAX_CONCURRENT_ENEMIES <= 128);
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
        .min_player_dist = 50.0,
        .exclusion_zones = &.{
            .{ .min = .init(200, 200), .max = .init(300, 300) },
        },
    };

    const player_pos = lm.Vec2(0, 0);
    for (0..20) |_| {
        const pos = pickSpawnPositionWithConfig(player_pos, custom_config);
        try std.testing.expect(pos.x >= 50.0 and pos.x <= 550.0);
        try std.testing.expect(pos.y >= 50.0 and pos.y <= 550.0);
        const in_exclusion = pos.x >= 200 and pos.x <= 300 and pos.y >= 200 and pos.y <= 300;
        try std.testing.expect(!in_exclusion);
    }
}
