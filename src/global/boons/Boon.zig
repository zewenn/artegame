const std = @import("std");
const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");

const Self = @This();

fn capitalizeTagName(comptime tag_name: []const u8) []const u8 {
    const capitalized = comptime capitalized_block: {
        var buffer: [tag_name.len]u8 = tag_name[0..tag_name.len].*;
        if (buffer.len > 0) {
            buffer[0] = std.ascii.toUpper(buffer[0]);
        }
        break :capitalized_block buffer;
    };
    return &capitalized;
}

/// High-level category of upgrade granted by a boon.
pub const BoonType = enum {
    spell,
    stat,
    weapon,

    /// Returns the capitalized display label for this boon type.
    pub fn toString(self: BoonType) []const u8 {
        return switch (self) {
            inline else => |tag| capitalizeTagName(@tagName(tag)),
        };
    }
};

/// Rarity tier controlling boon cost and visual styling.
pub const Rarity = enum {
    normal,
    rare,
    epic,
    legendary,
    mythic,
    cosmic,

    /// Returns the experience cost required to purchase a boon of this rarity.
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

    /// Returns the capitalized display label for this rarity tier.
    pub fn toString(self: Rarity) []const u8 {
        return switch (self) {
            inline else => |tag| capitalizeTagName(@tagName(tag)),
        };
    }

    /// Returns the HUD sprite asset path corresponding to this rarity tier.
    pub fn spritePath(self: Rarity) []const u8 {
        return switch (self) {
            inline else => |tag| "ui/hud/boon_tiers/" ++ @tagName(tag) ++ ".png",
        };
    }
};

id: []const u8,
name: []const u8,
description: []const u8,
icon: []const u8,
rarity: Rarity,
boon_type: BoonType,

callback: *const fn (stats: *Stats, attack: ?*Attack) void,
condition: ?*const fn (stats: *const Stats, attack: *const Attack) bool = null,

/// Applies this boon's upgrade effect to the given player stats and attack components.
pub fn applyTo(self: Self, to_stats: *Stats, to_attack: ?*Attack) void {
    @call(.auto, self.callback, .{ to_stats, to_attack });
}

/// Returns whether this boon is eligible to be offered for the given player state.
pub fn isAvailable(self: Self, stats: *const Stats, attack: *const Attack) bool {
    if (self.condition) |availability_condition| {
        return availability_condition(stats, attack);
    }
    return true;
}

/// Returns the purchase cost of this boon in experience points.
pub fn cost(self: Self) usize {
    return self.rarity.cost();
}

/// Returns whether two boons share the same unique identifier.
pub fn equals(self: Self, other: Self) bool {
    return std.mem.eql(u8, self.id, other.id);
}

test "BoonType and Rarity toString capitalize tag names" {
    try std.testing.expectEqualStrings("Spell", BoonType.spell.toString());
    try std.testing.expectEqualStrings("Stat", BoonType.stat.toString());
    try std.testing.expectEqualStrings("Weapon", BoonType.weapon.toString());

    try std.testing.expectEqualStrings("Normal", Rarity.normal.toString());
    try std.testing.expectEqualStrings("Rare", Rarity.rare.toString());
    try std.testing.expectEqualStrings("Epic", Rarity.epic.toString());
    try std.testing.expectEqualStrings("Legendary", Rarity.legendary.toString());
    try std.testing.expectEqualStrings("Mythic", Rarity.mythic.toString());
    try std.testing.expectEqualStrings("Cosmic", Rarity.cosmic.toString());
}
