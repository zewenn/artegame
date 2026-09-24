const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const Boon = @import("Boon.zig");
const boons_module = @import("boons.zig");

pub const Self = @This();

id: []const u8,
name: []const u8,
description: []const u8,
icon: []const u8,
boons: []const Boon,

pub fn isAvailableForPlayer(self: Self, stats: Stats, attack: Attack) bool {
    for (self.boons) |boon| {
        if (boon.isAvailable(stats, attack)) return true;
    }
    return false;
}

pub fn countAvailableBoons(self: Self, stats: Stats, attack: Attack) usize {
    var count: usize = 0;
    for (self.boons) |boon| {
        if (boon.isAvailable(stats, attack)) count += 1;
    }
    return count;
}

pub fn equals(self: Self, other: Self) bool {
    return std.mem.eql(u8, self.id, other.id);
}

pub const eql = equals;

pub const plates_width_speed: Self = .{
    .id = "plates_width_speed",
    .name = "Plate Size & Speed",
    .description = "Projectile width and velocity upgrades for Weight Plate attacks",
    .icon = "weapons/plates/weight_plate.png",
    .boons = boons_module.plates_width_speed_boons,
};

pub const plates_damage: Self = .{
    .id = "plates_damage",
    .name = "Plate Damage",
    .description = "Attack damage multipliers for Weight Plate strikes and slams",
    .icon = "weapons/plates/plates_0.png",
    .boons = boons_module.plates_damage_boons,
};

pub const gloves_width_speed: Self = .{
    .id = "gloves_width_speed",
    .name = "Glove Size & Speed",
    .description = "Punch reach, width, and velocity for Boxing Glove strikes",
    .icon = "weapons/gloves/gloves_0.png",
    .boons = boons_module.gloves_width_speed_boons,
};

pub const gloves_damage: Self = .{
    .id = "gloves_damage",
    .name = "Glove Damage",
    .description = "Attack damage multipliers for Boxing Glove jabs, hooks, and crosses",
    .icon = "weapons/gloves/gloves_1.png",
    .boons = boons_module.gloves_damage_boons,
};

pub const new_supplements: Self = .{
    .id = "new_supplements",
    .name = "New Supplements",
    .description = "Learn or replace active smoothie spells",
    .icon = "ui/icons/heal_icon.png",
    .boons = boons_module.new_supplements_boons,
};

pub const supplement_upgrades: Self = .{
    .id = "supplement_upgrades",
    .name = "Supplement Upgrades",
    .description = "Level up equipped active smoothie spells",
    .icon = "ui/icons/haste_icon.png",
    .boons = boons_module.supplement_upgrades_boons,
};

pub const vitality: Self = .{
    .id = "vitality",
    .name = "Vitality",
    .description = "Speed, HP, Stamina, Damage, Attack Speed, and Critical Hit stats",
    .icon = "items/strawberry.png",
    .boons = boons_module.vitality_boons,
};

pub const all_categories = [_]Self{
    plates_width_speed,
    plates_damage,
    gloves_width_speed,
    gloves_damage,
    new_supplements,
    supplement_upgrades,
    vitality,
};

pub fn getCategoryById(category_id: []const u8) ?Self {
    for (all_categories) |category| {
        if (std.mem.eql(u8, category.id, category_id)) return category;
    }
    return null;
}

pub fn selectEligibleCategories(
    stats: Stats,
    attack: Attack,
    destination_buffer: []Self,
) []const Self {
    var eligible_count: usize = 0;
    for (all_categories) |category| {
        if (eligible_count >= destination_buffer.len) break;
        if (category.isAvailableForPlayer(stats, attack)) {
            destination_buffer[eligible_count] = category;
            eligible_count += 1;
        }
    }
    return destination_buffer[0..eligible_count];
}

pub fn getRandomCategoryForPlayer(stats: Stats, attack: Attack) ?Self {
    var eligible_buffer: [all_categories.len]Self = undefined;
    const eligible_categories = selectEligibleCategories(stats, attack, &eligible_buffer);
    if (eligible_categories.len == 0) return null;
    const chosen_index = lm.random.intRangeLessThan(usize, 0, eligible_categories.len);
    return eligible_categories[chosen_index];
}

test "all categories have unique IDs and non-empty metadata" {
    for (all_categories, 0..) |first_category, outer_index| {
        try std.testing.expect(first_category.id.len > 0);
        try std.testing.expect(first_category.name.len > 0);
        try std.testing.expect(first_category.description.len > 0);
        try std.testing.expect(first_category.icon.len > 0);
        try std.testing.expect(first_category.boons.len > 0);

        for (all_categories[outer_index + 1 ..]) |second_category| {
            try std.testing.expect(!std.mem.eql(u8, first_category.id, second_category.id));
            try std.testing.expect(!std.mem.eql(u8, first_category.name, second_category.name));
            try std.testing.expect(!first_category.equals(second_category));
            try std.testing.expect(!first_category.eql(second_category));
        }
    }
}

test "BoonCategory lookup by ID" {
    try std.testing.expect(getCategoryById("plates_width_speed") != null);
    try std.testing.expect(getCategoryById("plates_damage") != null);
    try std.testing.expect(getCategoryById("gloves_width_speed") != null);
    try std.testing.expect(getCategoryById("gloves_damage") != null);
    try std.testing.expect(getCategoryById("new_supplements") != null);
    try std.testing.expect(getCategoryById("supplement_upgrades") != null);
    try std.testing.expect(getCategoryById("vitality") != null);
    try std.testing.expect(getCategoryById("unknown_category") == null);
}

test "BoonCategory eligibility respects player equipment" {
    const stats = Stats{ .team = .player };
    var attack = Attack{};

    try std.testing.expect(plates_damage.isAvailableForPlayer(stats, attack));
    try std.testing.expect(gloves_damage.isAvailableForPlayer(stats, attack));

    attack.equipped_weapons[1] = null;
    try std.testing.expect(!plates_damage.isAvailableForPlayer(stats, attack));
    try std.testing.expect(!plates_width_speed.isAvailableForPlayer(stats, attack));
    try std.testing.expect(gloves_damage.isAvailableForPlayer(stats, attack));

    attack.equipped_weapons[0] = null;
    try std.testing.expect(!gloves_damage.isAvailableForPlayer(stats, attack));
    try std.testing.expect(!gloves_width_speed.isAvailableForPlayer(stats, attack));

    try std.testing.expect(vitality.isAvailableForPlayer(stats, attack));
}
