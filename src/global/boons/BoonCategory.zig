const std = @import("std");

const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const Boon = @import("Boon.zig");
const boons_module = @import("boons.zig");

/// Grouping of related boons presented as a door reward category.
pub const Self = @This();

id: []const u8,
name: []const u8,
description: []const u8,
icon: []const u8,
boons: []const Boon,

/// Returns whether at least one boon in this category can be offered to the player.
pub fn isAvailableForPlayer(self: Self, stats: *const Stats, attack: *const Attack) bool {
    for (self.boons) |boon| {
        if (boon.isAvailable(stats, attack)) return true;
    }
    return false;
}

pub const plates_width_speed: Self = .{
    .id = "plates_width_speed",
    .name = "Plate Size & Speed",
    .description = "Projectile width and velocity upgrades for Weight Plate attacks",
    .icon = "weapons/plates/plates_0.png",
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

fn countCategoryDeclarations() usize {
    var count: usize = 0;
    for (@typeInfo(@This()).@"struct".decl_names) |declaration_name| {
        if (std.mem.eql(u8, declaration_name, "all_categories")) continue;
        if (std.mem.eql(u8, declaration_name, "Self")) continue;
        const declaration_value = @field(@This(), declaration_name);
        if (@TypeOf(declaration_value) == Self) count += 1;
    }
    return count;
}

fn collectAllCategories() [countCategoryDeclarations()]Self {
    var categories: [countCategoryDeclarations()]Self = undefined;
    var category_index: usize = 0;
    for (@typeInfo(@This()).@"struct".decl_names) |declaration_name| {
        if (std.mem.eql(u8, declaration_name, "all_categories")) continue;
        if (std.mem.eql(u8, declaration_name, "Self")) continue;
        const declaration_value = @field(@This(), declaration_name);
        if (@TypeOf(declaration_value) == Self) {
            categories[category_index] = declaration_value;
            category_index += 1;
        }
    }
    return categories;
}

/// Array of every boon category declared in this module.
pub const all_categories = collectAllCategories();

/// Looks up a boon category by its unique string identifier.
pub fn getCategoryById(category_id: []const u8) ?Self {
    for (all_categories) |category| {
        if (std.mem.eql(u8, category.id, category_id)) return category;
    }
    return null;
}

/// Fills `destination_buffer` with categories eligible for the given player state and returns the populated slice.
pub fn selectEligibleCategories(
    stats: Stats,
    attack: Attack,
    destination_buffer: []Self,
) []const Self {
    var eligible_count: usize = 0;
    for (all_categories) |category| {
        if (eligible_count >= destination_buffer.len) break;
        if (category.isAvailableForPlayer(&stats, &attack)) {
            destination_buffer[eligible_count] = category;
            eligible_count += 1;
        }
    }
    return destination_buffer[0..eligible_count];
}

fn validateCategoryPair(comptime first_category: Self, comptime second_category: Self) void {
    if (std.mem.eql(u8, first_category.id, second_category.id)) {
        @compileError("Duplicate category id: " ++ first_category.id);
    }
    if (std.mem.eql(u8, first_category.name, second_category.name)) {
        @compileError("Duplicate category name: " ++ first_category.name);
    }
}

fn validateAllCategories(comptime categories: []const Self) void {
    for (categories, 0..) |first_category, outer_index| {
        if (first_category.id.len == 0) @compileError("Category id must not be empty");
        if (first_category.name.len == 0) @compileError("Category name must not be empty");
        if (first_category.description.len == 0) @compileError("Category description must not be empty");
        if (first_category.icon.len == 0) @compileError("Category icon must not be empty");
        if (first_category.boons.len == 0) @compileError("Category boons must not be empty");
        for (categories[outer_index + 1 ..]) |second_category| {
            validateCategoryPair(first_category, second_category);
        }
    }
}

comptime {
    @setEvalBranchQuota(10_000);
    validateAllCategories(&all_categories);
}

test "BoonCategory eligibility respects player equipment" {
    const stats = Stats{ .team = .player };
    var attack = Attack{};

    try std.testing.expect(plates_damage.isAvailableForPlayer(&stats, &attack));
    try std.testing.expect(gloves_damage.isAvailableForPlayer(&stats, &attack));

    attack.equipped_weapons[1] = null;
    try std.testing.expect(!plates_damage.isAvailableForPlayer(&stats, &attack));
    try std.testing.expect(!plates_width_speed.isAvailableForPlayer(&stats, &attack));
    try std.testing.expect(gloves_damage.isAvailableForPlayer(&stats, &attack));

    attack.equipped_weapons[0] = null;
    try std.testing.expect(!gloves_damage.isAvailableForPlayer(&stats, &attack));
    try std.testing.expect(!gloves_width_speed.isAvailableForPlayer(&stats, &attack));

    try std.testing.expect(vitality.isAvailableForPlayer(&stats, &attack));
}
