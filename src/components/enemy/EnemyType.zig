const std = @import("std");
const lm = @import("loom");
const rl = lm.deps.rl;
const prefabs = @import("../../prefabs/prefabs.zig");
const BossBar = @import("../../global/ui/BossBar.zig");

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

    pub const NormalWaveRole = union(enum) {
        specialist: NormalWaveRule,
        filler: NormalFillerRule,
    };

    pub const normal_enemies = makeListByBossRank(null);
    pub const mini_boss_enemies = makeListByBossRank(.mini_boss);
    pub const boss_enemies = makeListByBossRank(.boss);

    pub const normal_filler_enemies = [_]EnemyType{ .ranged, .melee };
    pub const excluded_normal_enemies = [_]EnemyType{.dummy};
    pub const normal_specialist_enemies = getSpecialistEnemies();

    dummy,
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

    pub fn spawn(self: @This(), position: lm.Vector2) !*lm.Entity {
        return switch (self) {
            .dummy => try prefabs.enemies.Dummy(position),
            .melee => try prefabs.enemies.Melee(position),
            .ranged => try prefabs.enemies.Ranged(position),
            .elite => try prefabs.enemies.Elite(position),
            .shaman => try prefabs.enemies.Shaman(position),
            .magician => try prefabs.enemies.Magician(position),
            .lifeliner => try prefabs.enemies.Lifeliner(position),
            .angler => try prefabs.enemies.Angler(position),
            .tank => try prefabs.enemies.Tank(position),
            .knight => try prefabs.enemies.Knight(position),
            .bishop => try prefabs.enemies.Bishop(position),
            .mini_boss => try spawn(self.takeFromCategoryNotSelf(mini_boss_enemies), position),
            .boss => try spawn(self.takeFromCategoryNotSelf(boss_enemies), position),
            .king => try prefabs.enemies.King(position),
            .queen => try prefabs.enemies.Queen(position),
        };
    }

    pub inline fn bossRank(self: EnemyType) ?BossBar.BossRank {
        return switch (self) {
            .knight, .bishop, .mini_boss => .mini_boss,
            .king, .queen, .boss => .boss,
            else => null,
        };
    }

    pub fn cost(self: EnemyType) u32 {
        return switch (self) {
            .dummy => 0,
            .melee => 1,
            .ranged => 2,
            .angler => 2,
            .shaman => 3,
            .magician => 3,
            .lifeliner => 4,
            .tank => 4,
            .elite => 5,
            .knight => 20,
            .bishop => 20,
            .mini_boss => 20,
            .boss, .king, .queen => 100,
        };
    }

    pub fn normalWaveRule(self: EnemyType) ?NormalWaveRule {
        return switch (self) {
            .elite => .{ .unlock_round = 3, .round_divisor = 2, .max_count = 16 },
            .tank => .{ .unlock_round = 3, .round_divisor = 3, .max_count = 6 },
            .shaman => .{ .unlock_round = 3, .round_divisor = 4, .max_count = 4 },
            .magician => .{ .unlock_round = 4, .round_divisor = 4, .max_count = 4 },
            .lifeliner => .{ .unlock_round = 4, .round_divisor = 5, .max_count = 3 },
            .angler => .{ .unlock_round = 2, .round_divisor = 2, .max_count = 8 },
            else => null,
        };
    }

    pub fn normalFillerRule(self: EnemyType) ?NormalFillerRule {
        return switch (self) {
            .ranged => .{ .unlock_round = 2, .budget_share_percentage = 35 },
            .melee => .{ .unlock_round = 1, .budget_share_percentage = 100 },
            else => null,
        };
    }

    pub fn normalWaveRole(self: EnemyType) ?NormalWaveRole {
        if (self.normalWaveRule()) |rule| {
            return .{ .specialist = rule };
        }
        if (self.normalFillerRule()) |rule| {
            return .{ .filler = rule };
        }
        return null;
    }

    pub fn displayName(self: EnemyType) []const u8 {
        return switch (self) {
            .dummy => "Dummy",
            .melee => "Melee",
            .ranged => "Ranged",
            .elite => "Elite",
            .shaman => "Shaman",
            .magician => "Magician",
            .lifeliner => "Lifeliner",
            .angler => "Angler",
            .tank => "Tank",
            .knight => "Knight",
            .bishop => "Bishop",
            .mini_boss => "Mini-Boss",
            .boss => "Boss",
            .king => "The King",
            .queen => "The Queen",
        };
    }

    pub inline fn canBindBossBar(self: EnemyType) bool {
        return self.bossRank() != null;
    }

    pub fn tryBindBossBar(self: EnemyType, entity: *lm.Entity) void {
        if (!self.canBindBossBar()) return;
        const boss_rank = self.bossRank() orelse return;

        BossBar.bind(entity, self.displayName(), boss_rank);
    }

    pub fn label(self: ?EnemyType) [:0]const u8 {
        const enemy_type = self orelse return "ALL";
        return switch (enemy_type) {
            .dummy => "DUMMY",
            .melee => "MELEE",
            .ranged => "RANGED",
            .elite => "ELITE",
            .shaman => "SHAMAN",
            .magician => "MAGICIAN",
            .lifeliner => "LIFELINER",
            .angler => "ANGLER",
            .tank => "TANK",
            .knight => "KNIGHT",
            .bishop => "BISHOP",
            .mini_boss => "MINI-BOSS",
            .boss => "BOSS",
            .king => "KING",
            .queen => "QUEEN",
        };
    }

    pub fn editorFillColor(self: ?EnemyType) rl.Color {
        const enemy_type = self orelse return rl.Color{ .r = 230, .g = 40, .b = 40, .a = 60 };
        return switch (enemy_type) {
            .dummy => rl.Color{ .r = 150, .g = 150, .b = 150, .a = 60 },
            .melee => rl.Color{ .r = 220, .g = 50, .b = 50, .a = 60 },
            .ranged => rl.Color{ .r = 240, .g = 185, .b = 40, .a = 60 },
            .elite => rl.Color{ .r = 170, .g = 60, .b = 230, .a = 60 },
            .shaman => rl.Color{ .r = 40, .g = 200, .b = 100, .a = 60 },
            .magician => rl.Color{ .r = 50, .g = 120, .b = 240, .a = 60 },
            .lifeliner => rl.Color{ .r = 235, .g = 90, .b = 150, .a = 60 },
            .angler => rl.Color{ .r = 30, .g = 210, .b = 210, .a = 60 },
            .tank => rl.Color{ .r = 130, .g = 140, .b = 160, .a = 60 },
            .knight => rl.Color{ .r = 215, .g = 165, .b = 35, .a = 60 },
            .bishop => rl.Color{ .r = 155, .g = 70, .b = 220, .a = 60 },
            .mini_boss => rl.Color{ .r = 245, .g = 170, .b = 30, .a = 60 },
            .boss => rl.Color{ .r = 180, .g = 20, .b = 50, .a = 60 },
            .king => rl.Color{ .r = 240, .g = 180, .b = 30, .a = 60 },
            .queen => rl.Color{ .r = 210, .g = 50, .b = 190, .a = 60 },
        };
    }

    pub fn editorOutlineColor(self: ?EnemyType) rl.Color {
        const enemy_type = self orelse return rl.Color{ .r = 255, .g = 80, .b = 80, .a = 220 };
        return switch (enemy_type) {
            .dummy => rl.Color{ .r = 200, .g = 200, .b = 200, .a = 220 },
            .melee => rl.Color{ .r = 255, .g = 90, .b = 90, .a = 220 },
            .ranged => rl.Color{ .r = 255, .g = 210, .b = 80, .a = 220 },
            .elite => rl.Color{ .r = 200, .g = 100, .b = 255, .a = 220 },
            .shaman => rl.Color{ .r = 80, .g = 240, .b = 140, .a = 220 },
            .magician => rl.Color{ .r = 90, .g = 160, .b = 255, .a = 220 },
            .lifeliner => rl.Color{ .r = 255, .g = 130, .b = 180, .a = 220 },
            .angler => rl.Color{ .r = 70, .g = 240, .b = 240, .a = 220 },
            .tank => rl.Color{ .r = 170, .g = 180, .b = 200, .a = 220 },
            .knight => rl.Color{ .r = 245, .g = 195, .b = 60, .a = 220 },
            .bishop => rl.Color{ .r = 195, .g = 105, .b = 250, .a = 220 },
            .mini_boss => rl.Color{ .r = 255, .g = 200, .b = 70, .a = 220 },
            .boss => rl.Color{ .r = 230, .g = 50, .b = 80, .a = 220 },
            .king => rl.Color{ .r = 255, .g = 210, .b = 50, .a = 220 },
            .queen => rl.Color{ .r = 255, .g = 80, .b = 230, .a = 220 },
        };
    }

    fn takeFromCategoryNotSelf(self: EnemyType, category: []const EnemyType) EnemyType {
        for (category, 0..) |enemy_type, index| {
            if (enemy_type != self) continue;

            return category[if (index > 0) index - 1 else index + 1];
        }
        return category[lm.random.intRangeAtMost(usize, 0, category.len - 1)];
    }

    fn makeListByBossRank(comptime for_rank: ?BossBar.BossRank) []const EnemyType {
        comptime var list: []const EnemyType = &.{};

        const enemy_fields = std.meta.fields(EnemyType);
        for (0..enemy_fields.len) |index| {
            const value = lm.coerceTo(EnemyType, index) orelse .dummy;
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
            var found = false;
            for (normal_filler_enemies) |filler| {
                if (normal_enemy_type != filler) continue;
                found = true;
                break;
            }
            for (excluded_normal_enemies) |excluded| {
                if (normal_enemy_type != excluded) continue;
                found = true;
                break;
            }

            if (found) continue;

            const add: []const EnemyType = &.{normal_enemy_type};
            list = list ++ add;
        }

        return list;
    }
};

test "makeListByBossRank categories are created correctly" {
    try std.testing.expect(std.mem.containsAtLeast(EnemyType, EnemyType.mini_boss_enemies, 1, &.{.knight}));
    try std.testing.expect(std.mem.containsAtLeast(EnemyType, EnemyType.mini_boss_enemies, 1, &.{.bishop}));
    try std.testing.expect(std.mem.containsAtLeast(EnemyType, EnemyType.mini_boss_enemies, 1, &.{.mini_boss}));

    try std.testing.expect(std.mem.containsAtLeast(EnemyType, EnemyType.boss_enemies, 1, &.{.king}));
    try std.testing.expect(std.mem.containsAtLeast(EnemyType, EnemyType.boss_enemies, 1, &.{.queen}));
    try std.testing.expect(std.mem.containsAtLeast(EnemyType, EnemyType.boss_enemies, 1, &.{.boss}));
}

test "normal wave roles and categorization" {
    for (EnemyType.normal_specialist_enemies) |enemy_type| {
        try std.testing.expect(enemy_type.normalWaveRule() != null);
        const role = enemy_type.normalWaveRole().?;
        try std.testing.expect(role == .specialist);
    }

    for (EnemyType.normal_filler_enemies) |enemy_type| {
        try std.testing.expect(enemy_type.normalFillerRule() != null);
        const role = enemy_type.normalWaveRole().?;
        try std.testing.expect(role == .filler);
    }

    try std.testing.expectEqual(@as(?EnemyType.NormalWaveRole, null), EnemyType.dummy.normalWaveRole());
    try std.testing.expectEqual(@as(?EnemyType.NormalWaveRole, null), EnemyType.knight.normalWaveRole());
    try std.testing.expectEqual(@as(?EnemyType.NormalWaveRole, null), EnemyType.king.normalWaveRole());
}
