const std = @import("std");
const lm = @import("loom");
const rl = lm.deps.rl;

pub const EnemyType = enum {
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

    pub const NormalWaveRule = struct {
        unlock_round: u32,
        round_divisor: u32,
        max_count: u32,
    };

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
};

test "EnemyType labels and costs" {
    try std.testing.expectEqualStrings("ALL", EnemyType.label(null));
    try std.testing.expectEqualStrings("RANGED", EnemyType.label(.ranged));
    try std.testing.expectEqualStrings("MELEE", EnemyType.label(.melee));
    try std.testing.expectEqualStrings("KNIGHT", EnemyType.label(.knight));
    try std.testing.expectEqualStrings("BISHOP", EnemyType.label(.bishop));
    try std.testing.expectEqualStrings("KING", EnemyType.label(.king));
    try std.testing.expectEqualStrings("QUEEN", EnemyType.label(.queen));
    try std.testing.expectEqual(@as(u32, 2), EnemyType.ranged.cost());
    try std.testing.expectEqual(@as(u32, 1), EnemyType.melee.cost());
    try std.testing.expectEqual(@as(u32, 20), EnemyType.knight.cost());
    try std.testing.expectEqual(@as(u32, 20), EnemyType.bishop.cost());
    try std.testing.expectEqual(@as(u32, 100), EnemyType.king.cost());
    try std.testing.expectEqual(@as(u32, 100), EnemyType.queen.cost());
}
