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
    mini_boss,
    boss,

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
            .mini_boss => 20,
            .boss => 100,
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
            .mini_boss => "Mini-Boss",
            .boss => "Boss",
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
            .mini_boss => "MINI-BOSS",
            .boss => "BOSS",
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
            .mini_boss => rl.Color{ .r = 245, .g = 170, .b = 30, .a = 60 },
            .boss => rl.Color{ .r = 180, .g = 20, .b = 50, .a = 60 },
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
            .mini_boss => rl.Color{ .r = 255, .g = 200, .b = 70, .a = 220 },
            .boss => rl.Color{ .r = 230, .g = 50, .b = 80, .a = 220 },
        };
    }
};

test "EnemyType labels and costs" {
    try std.testing.expectEqualStrings("ALL", EnemyType.label(null));
    try std.testing.expectEqualStrings("RANGED", EnemyType.label(.ranged));
    try std.testing.expectEqualStrings("MELEE", EnemyType.label(.melee));
    try std.testing.expectEqual(@as(u32, 2), EnemyType.ranged.cost());
    try std.testing.expectEqual(@as(u32, 1), EnemyType.melee.cost());
}
