const std = @import("std");
const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");

const Self = @This();

pub const BoonType = enum {
    spell,
    stat,
    weapon,

    pub fn toString(self: BoonType) []const u8 {
        return switch (self) {
            .spell => "Spell",
            .stat => "Stat",
            .weapon => "Weapon",
        };
    }
};

pub const Rarity = enum {
    normal,
    rare,
    epic,
    legendary,
    mythic,
    cosmic,

    pub fn cost(self: Rarity) usize {
        return switch (self) {
            .normal => 10,
            .rare => 25,
            .epic => 50,
            .legendary => 100,
            .mythic => 250,
            .cosmic => 500,
        };
    }

    pub fn toString(self: Rarity) []const u8 {
        return switch (self) {
            .normal => "Normal",
            .rare => "Rare",
            .epic => "Epic",
            .legendary => "Legendary",
            .mythic => "Mythic",
            .cosmic => "Cosmic",
        };
    }
};

name: []const u8,
description: []const u8,
icon: []const u8,
rarity: Rarity,
boon_type: BoonType,

callback: *const fn (stats: *Stats, attack: ?*Attack) void,
condition: ?*const fn (stats: Stats, attack: Attack) bool = null,

pub fn applyTo(self: Self, to_stats: *Stats, to_attack: ?*Attack) void {
    @call(.auto, self.callback, .{ to_stats, to_attack });
}

pub fn isAvailable(self: Self, stats: Stats, attack: Attack) bool {
    if (self.condition) |cond| {
        return cond(stats, attack);
    }
    return true;
}

pub fn cost(self: Self) usize {
    return self.rarity.cost();
}

pub fn eql(self: Self, other: Self) bool {
    return self.rarity == other.rarity and
        self.boon_type == other.boon_type and
        std.mem.eql(u8, self.name, other.name) and
        std.mem.eql(u8, self.description, other.description);
}
