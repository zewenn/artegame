const std = @import("std");
const lm = @import("loom");
const rl = lm.deps.rl;
const prefabs = @import("../../prefabs/prefabs.zig");
const BossBar = @import("BossBar.zig");

/// Enumerates all spawnable enemy archetypes and category wildcards.
pub const EnemyType = enum {
    pub const NormalWaveRule = struct {
        unlock_round: u32,
        round_divisor: u32,
        max_count: u32,
    };

    pub const NormalFillerRule = struct {
        unlock_round: u32,
        budget_share_percentage: u32,
    };

    pub const OrbDropRange = struct {
        min_count: u8,
        max_count: u8,
    };

    const SpawnFn = *const fn (lm.Vector2) anyerror!*lm.Entity;

    const EnemySpec = struct {
        spawn_fn: ?SpawnFn = null,
        boss_rank: ?BossBar.BossRank = null,
        cost: u32,
        normal_wave_rule: ?NormalWaveRule = null,
        normal_filler_rule: ?NormalFillerRule = null,
        orb_drop_range: OrbDropRange,
        base_editor_color: [3]u8,
        display_name_override: ?[]const u8 = null,
    };

    pub const normal_enemies = makeListByBossRank(null);
    pub const mini_boss_enemies = makeListByBossRank(.mini_boss);
    pub const boss_enemies = makeListByBossRank(.boss);

    pub const normal_filler_enemies = [_]EnemyType{ .ranged, .melee };
    pub const normal_specialist_enemies = getSpecialistEnemies();

    melee,
    ranged,
    elite,
    shaman,
    magician,
    lifeliner,
    angler,
    tank,
    knight,
    bishop,
    mini_boss,
    boss,
    king,
    queen,

    const specs = std.EnumArray(EnemyType, EnemySpec).init(.{
        .melee = .{
            .spawn_fn = prefabs.enemies.Melee,
            .cost = 1,
            .normal_filler_rule = .{ .unlock_round = 1, .budget_share_percentage = 100 },
            .orb_drop_range = .{ .min_count = 1, .max_count = 3 },
            .base_editor_color = .{ 220, 50, 50 },
        },
        .ranged = .{
            .spawn_fn = prefabs.enemies.Ranged,
            .cost = 2,
            .normal_filler_rule = .{ .unlock_round = 2, .budget_share_percentage = 35 },
            .orb_drop_range = .{ .min_count = 1, .max_count = 3 },
            .base_editor_color = .{ 225, 175, 40 },
        },
        .elite = .{
            .spawn_fn = prefabs.enemies.Elite,
            .cost = 5,
            .normal_wave_rule = .{ .unlock_round = 3, .round_divisor = 2, .max_count = 16 },
            .orb_drop_range = .{ .min_count = 3, .max_count = 6 },
            .base_editor_color = .{ 165, 65, 225 },
        },
        .shaman = .{
            .spawn_fn = prefabs.enemies.Shaman,
            .cost = 3,
            .normal_wave_rule = .{ .unlock_round = 3, .round_divisor = 4, .max_count = 4 },
            .orb_drop_range = .{ .min_count = 2, .max_count = 4 },
            .base_editor_color = .{ 45, 200, 105 },
        },
        .magician = .{
            .spawn_fn = prefabs.enemies.Magician,
            .cost = 3,
            .normal_wave_rule = .{ .unlock_round = 4, .round_divisor = 4, .max_count = 4 },
            .orb_drop_range = .{ .min_count = 2, .max_count = 4 },
            .base_editor_color = .{ 55, 125, 235 },
        },
        .lifeliner = .{
            .spawn_fn = prefabs.enemies.Lifeliner,
            .cost = 4,
            .normal_wave_rule = .{ .unlock_round = 4, .round_divisor = 5, .max_count = 3 },
            .orb_drop_range = .{ .min_count = 2, .max_count = 4 },
            .base_editor_color = .{ 225, 95, 150 },
        },
        .angler = .{
            .spawn_fn = prefabs.enemies.Angler,
            .cost = 2,
            .normal_wave_rule = .{ .unlock_round = 2, .round_divisor = 2, .max_count = 8 },
            .orb_drop_range = .{ .min_count = 1, .max_count = 3 },
            .base_editor_color = .{ 35, 205, 205 },
        },
        .tank = .{
            .spawn_fn = prefabs.enemies.Tank,
            .cost = 4,
            .normal_wave_rule = .{ .unlock_round = 3, .round_divisor = 3, .max_count = 6 },
            .orb_drop_range = .{ .min_count = 2, .max_count = 4 },
            .base_editor_color = .{ 135, 145, 165 },
        },
        .knight = .{
            .spawn_fn = prefabs.enemies.Knight,
            .boss_rank = .mini_boss,
            .cost = 20,
            .orb_drop_range = .{ .min_count = 8, .max_count = 12 },
            .base_editor_color = .{ 210, 160, 30 },
        },
        .bishop = .{
            .spawn_fn = prefabs.enemies.Bishop,
            .boss_rank = .mini_boss,
            .cost = 20,
            .orb_drop_range = .{ .min_count = 8, .max_count = 12 },
            .base_editor_color = .{ 160, 70, 215 },
        },
        .mini_boss = .{
            .boss_rank = .mini_boss,
            .cost = 20,
            .orb_drop_range = .{ .min_count = 8, .max_count = 12 },
            .base_editor_color = .{ 230, 165, 35 },
        },
        .boss = .{
            .boss_rank = .boss,
            .cost = 100,
            .orb_drop_range = .{ .min_count = 25, .max_count = 35 },
            .base_editor_color = .{ 190, 20, 50 },
        },
        .king = .{
            .spawn_fn = prefabs.enemies.King,
            .boss_rank = .boss,
            .cost = 100,
            .orb_drop_range = .{ .min_count = 25, .max_count = 35 },
            .base_editor_color = .{ 230, 175, 25 },
            .display_name_override = "The King",
        },
        .queen = .{
            .spawn_fn = prefabs.enemies.Queen,
            .boss_rank = .boss,
            .cost = 100,
            .orb_drop_range = .{ .min_count = 25, .max_count = 35 },
            .base_editor_color = .{ 215, 50, 195 },
            .display_name_override = "The Queen",
        },
    });

    /// Spawns an enemy entity at the given world position, resolving category wildcards uniformly.
    pub fn spawn(self: EnemyType, position: lm.Vector2) !*lm.Entity {
        const resolved_type = switch (self) {
            .mini_boss => self.takeFromCategoryNotSelf(mini_boss_enemies),
            .boss => self.takeFromCategoryNotSelf(boss_enemies),
            else => self,
        };
        const spawn_fn = specs.get(resolved_type).spawn_fn orelse return error.MissingSpawnFunction;
        return try spawn_fn(position);
    }

    /// Returns the boss rank for mini-boss and boss archetypes, or null for normal enemies.
    pub inline fn bossRank(self: EnemyType) ?BossBar.BossRank {
        return specs.get(self).boss_rank;
    }

    /// Returns the wave budget cost of this enemy type.
    pub fn cost(self: EnemyType) u32 {
        return specs.get(self).cost;
    }

    /// Returns the specialist wave scaling rule, if this enemy is a normal-wave specialist.
    pub fn normalWaveRule(self: EnemyType) ?NormalWaveRule {
        return specs.get(self).normal_wave_rule;
    }

    /// Returns the filler wave rule, if this enemy is a normal-wave filler.
    pub fn normalFillerRule(self: EnemyType) ?NormalFillerRule {
        return specs.get(self).normal_filler_rule;
    }

    /// Returns the inclusive experience orb drop count range on defeat.
    pub fn orbDropRange(self: EnemyType) OrbDropRange {
        return specs.get(self).orb_drop_range;
    }

    /// Returns the human-readable display name for this enemy type.
    pub fn displayName(self: EnemyType) []const u8 {
        return switch (self) {
            inline else => |enemy_tag| comptime comptimeDisplayName(enemy_tag),
        };
    }

    /// Returns the uppercase null-terminated editor label for an optional enemy type.
    pub fn label(self: ?EnemyType) [:0]const u8 {
        const enemy_type = self orelse return "ALL";
        return switch (enemy_type) {
            inline else => |enemy_tag| comptime comptimeLabel(enemy_tag),
        };
    }

    /// Returns the translucent editor fill color derived from the archetype base color.
    pub fn editorFillColor(self: ?EnemyType) rl.Color {
        const enemy_type = self orelse return rl.Color{ .r = 230, .g = 40, .b = 40, .a = 60 };
        const base = specs.get(enemy_type).base_editor_color;
        return rl.Color{ .r = base[0], .g = base[1], .b = base[2], .a = 60 };
    }

    /// Returns the brighter editor outline color derived from the archetype base color.
    pub fn editorOutlineColor(self: ?EnemyType) rl.Color {
        const enemy_type = self orelse return rl.Color{ .r = 255, .g = 80, .b = 80, .a = 220 };
        const base = specs.get(enemy_type).base_editor_color;
        return rl.Color{
            .r = @min(255, @as(u16, base[0]) + 35),
            .g = @min(255, @as(u16, base[1]) + 35),
            .b = @min(255, @as(u16, base[2]) + 35),
            .a = 220,
        };
    }

    fn comptimeLabel(comptime enemy_type: EnemyType) [:0]const u8 {
        const raw_name = @tagName(enemy_type);
        comptime var buffer: [raw_name.len:0]u8 = undefined;
        inline for (raw_name, 0..) |character, character_index| {
            buffer[character_index] = if (character == '_') '-' else std.ascii.toUpper(character);
        }
        buffer[raw_name.len] = 0;
        const result = buffer;
        return &result;
    }

    fn comptimeDisplayName(comptime enemy_type: EnemyType) []const u8 {
        if (specs.get(enemy_type).display_name_override) |override_name| {
            return override_name;
        }
        const raw_name = @tagName(enemy_type);
        comptime var buffer: [raw_name.len]u8 = undefined;
        comptime var capitalize_next = true;
        inline for (raw_name, 0..) |character, character_index| {
            if (character == '_') {
                buffer[character_index] = '-';
                capitalize_next = true;
            } else {
                buffer[character_index] = if (capitalize_next) std.ascii.toUpper(character) else character;
                capitalize_next = false;
            }
        }
        const result = buffer;
        return &result;
    }

    fn takeFromCategoryNotSelf(self: EnemyType, category: []const EnemyType) EnemyType {
        var candidate_count: usize = 0;
        for (category) |enemy_type| {
            if (enemy_type != self) candidate_count += 1;
        }
        if (candidate_count == 0) return self;

        var selected_offset = lm.random.intRangeLessThan(usize, 0, candidate_count);
        for (category) |enemy_type| {
            if (enemy_type == self) continue;
            if (selected_offset == 0) return enemy_type;
            selected_offset -= 1;
        }
        return self;
    }

    fn makeListByBossRank(comptime for_rank: ?BossBar.BossRank) []const EnemyType {
        comptime var list: []const EnemyType = &.{};

        for (std.enums.values(EnemyType)) |value| {
            const boss_rank = value.bossRank();
            if (boss_rank != for_rank) continue;

            const add: []const EnemyType = &.{value};
            list = list ++ add;
        }

        return list;
    }

    fn getSpecialistEnemies() []const EnemyType {
        comptime var list: []const EnemyType = &.{};
        for (normal_enemies) |normal_enemy_type| {
            if (isFillerEnemy(normal_enemy_type)) continue;

            const add: []const EnemyType = &.{normal_enemy_type};
            list = list ++ add;
        }

        return list;
    }

    fn isFillerEnemy(comptime enemy_type: EnemyType) bool {
        for (normal_filler_enemies) |filler| {
            if (enemy_type == filler) return true;
        }
        return false;
    }
};

comptime {
    if (!std.mem.containsAtLeast(EnemyType, EnemyType.mini_boss_enemies, 1, &.{.knight})) {
        @compileError("mini_boss_enemies missing .knight");
    }
    if (!std.mem.containsAtLeast(EnemyType, EnemyType.mini_boss_enemies, 1, &.{.bishop})) {
        @compileError("mini_boss_enemies missing .bishop");
    }
    if (!std.mem.containsAtLeast(EnemyType, EnemyType.boss_enemies, 1, &.{.king})) {
        @compileError("boss_enemies missing .king");
    }
    if (!std.mem.containsAtLeast(EnemyType, EnemyType.boss_enemies, 1, &.{.queen})) {
        @compileError("boss_enemies missing .queen");
    }
}

test "EnemyType metadata, labels, display names, and orb drop ranges" {
    for (EnemyType.normal_specialist_enemies) |enemy_type| {
        try std.testing.expect(enemy_type.normalWaveRule() != null);
        try std.testing.expectEqual(@as(?EnemyType.NormalFillerRule, null), enemy_type.normalFillerRule());
    }

    for (EnemyType.normal_filler_enemies) |enemy_type| {
        try std.testing.expect(enemy_type.normalFillerRule() != null);
        try std.testing.expectEqual(@as(?EnemyType.NormalWaveRule, null), enemy_type.normalWaveRule());
    }

    try std.testing.expectEqualStrings("ALL", EnemyType.label(null));
    try std.testing.expectEqualStrings("MINI-BOSS", EnemyType.label(.mini_boss));
    try std.testing.expectEqualStrings("The King", EnemyType.king.displayName());
    try std.testing.expectEqualStrings("The Queen", EnemyType.queen.displayName());
    try std.testing.expectEqualStrings("Mini-Boss", EnemyType.mini_boss.displayName());
    try std.testing.expectEqual(@as(u8, 25), EnemyType.queen.orbDropRange().min_count);
    try std.testing.expectEqual(@as(u8, 35), EnemyType.queen.orbDropRange().max_count);
}

test "EnemyType takeFromCategoryNotSelf samples uniformly across all non-self entries" {
    var saw_knight = false;
    var saw_bishop = false;
    for (0..64) |_| {
        const picked = EnemyType.mini_boss.takeFromCategoryNotSelf(EnemyType.mini_boss_enemies);
        try std.testing.expect(picked != .mini_boss);
        if (picked == .knight) saw_knight = true;
        if (picked == .bishop) saw_bishop = true;
    }
    try std.testing.expect(saw_knight and saw_bishop);
}
