const std = @import("std");

const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const Weapon = @import("../../components/weapons/Weapon.zig");
const Spell = @import("../../components/weapons/Spell.zig");
const spells = @import("../../components/weapons/spells.zig");
const Boon = @import("Boon.zig");

const WeaponAttackSlot = enum {
    light_attack,
    heavy_attack,
    dash_attack,
    all,
};

const WeaponProjectileProperty = enum {
    width,
    speed,
    damage,
};

const StatAdjustment = struct {
    field_name: []const u8,
    delta: f32,
};

fn hasWeaponCondition(comptime weapon_id: []const u8) *const fn (*const Stats, *const Attack) bool {
    return struct {
        fn check(_: *const Stats, attack: *const Attack) bool {
            return attack.hasWeaponId(weapon_id);
        }
    }.check;
}

fn hasSpellInSlotCondition(comptime slot_index: usize) *const fn (*const Stats, *const Attack) bool {
    return struct {
        fn check(_: *const Stats, attack: *const Attack) bool {
            return attack.equipped_spells[slot_index] != null;
        }
    }.check;
}

fn isSpellBelowExcludedLevel(
    attack: *const Attack,
    comptime slot_index: usize,
    comptime spell_id: []const u8,
    comptime excluded_level: u32,
) bool {
    const equipped_spell = attack.equipped_spells[slot_index] orelse return true;
    const matches_spell = std.mem.eql(u8, equipped_spell.id, spell_id);
    return !(matches_spell and equipped_spell.level >= excluded_level);
}

fn maxSpellLevelCondition(
    comptime slot_index: usize,
    comptime spell_id: []const u8,
    comptime excluded_level: u32,
) *const fn (*const Stats, *const Attack) bool {
    return struct {
        fn check(_: *const Stats, attack: *const Attack) bool {
            return isSpellBelowExcludedLevel(attack, slot_index, spell_id, excluded_level);
        }
    }.check;
}

fn applyWeaponProperty(
    weapon_attack: *Weapon.Attack,
    comptime property: WeaponProjectileProperty,
    comptime multiplier: f32,
) void {
    switch (property) {
        .width => weapon_attack.projectile_options.size.x *= multiplier,
        .speed => weapon_attack.projectile_options.speed *= multiplier,
        .damage => weapon_attack.projectile_options.damage *= multiplier,
    }
}

fn applyWeaponModifier(
    maybe_attack: ?*Attack,
    comptime weapon_id: []const u8,
    comptime attack_slot: WeaponAttackSlot,
    comptime property: WeaponProjectileProperty,
    comptime multiplier: f32,
) void {
    const attack_component = maybe_attack orelse return;
    const weapon = attack_component.getWeaponById(weapon_id) orelse return;
    switch (attack_slot) {
        .light_attack => applyWeaponProperty(&weapon.light_attack, property, multiplier),
        .heavy_attack => applyWeaponProperty(&weapon.heavy_attack, property, multiplier),
        .dash_attack => applyWeaponProperty(&weapon.dash_attack, property, multiplier),
        .all => {
            applyWeaponProperty(&weapon.light_attack, property, multiplier);
            applyWeaponProperty(&weapon.heavy_attack, property, multiplier);
            applyWeaponProperty(&weapon.dash_attack, property, multiplier);
        },
    }
}

fn weaponModifierCallback(
    comptime weapon_id: []const u8,
    comptime attack_slot: WeaponAttackSlot,
    comptime property: WeaponProjectileProperty,
    comptime multiplier: f32,
) *const fn (*Stats, ?*Attack) void {
    return struct {
        fn apply(_: *Stats, maybe_attack: ?*Attack) void {
            applyWeaponModifier(maybe_attack, weapon_id, attack_slot, property, multiplier);
        }
    }.apply;
}

fn equipSpellCallback(
    comptime slot_index: usize,
    comptime spell_template: Spell,
    comptime spell_level: u32,
) *const fn (*Stats, ?*Attack) void {
    return struct {
        fn apply(_: *Stats, maybe_attack: ?*Attack) void {
            const attack_component = maybe_attack orelse return;
            var spell_instance = spell_template;
            spell_instance.level = spell_level;
            attack_component.equipped_spells[slot_index] = spell_instance;
        }
    }.apply;
}

fn equipAshwagandaTierOneCallback(_: *Stats, maybe_attack: ?*Attack) void {
    const attack_component = maybe_attack orelse return;
    var spell_instance = spells.root;
    var root_level: u32 = 1;
    if (attack_component.equipped_spells[1]) |current_spell| {
        if (std.mem.eql(u8, current_spell.id, "Root")) {
            root_level = @max(current_spell.level + 1, 2);
        }
    }
    spell_instance.level = root_level;
    attack_component.equipped_spells[1] = spell_instance;
}

fn spellLevelBonusCallback(
    comptime slot_index: usize,
    comptime level_delta: u32,
) *const fn (*Stats, ?*Attack) void {
    return struct {
        fn apply(_: *Stats, maybe_attack: ?*Attack) void {
            const attack_component = maybe_attack orelse return;
            const spell_slot = &(attack_component.equipped_spells[slot_index] orelse return);
            spell_slot.level += level_delta;
        }
    }.apply;
}

fn applyStatAdjustments(stats: *Stats, comptime adjustments: []const StatAdjustment) void {
    inline for (adjustments) |adjustment| {
        @field(stats.current, adjustment.field_name) += adjustment.delta;
        @field(stats.max, adjustment.field_name) += adjustment.delta;
    }
}

fn statBonusCallback(comptime adjustments: []const StatAdjustment) *const fn (*Stats, ?*Attack) void {
    return struct {
        fn apply(stats: *Stats, _: ?*Attack) void {
            applyStatAdjustments(stats, adjustments);
        }
    }.apply;
}

fn nikeOwBlazerCallback(stats: *Stats, _: ?*Attack) void {
    stats.max.stamina += 50;
    stats.current.stamina += 50;
    const speed_bonus: f32 = if (stats.current.movement_speed < 600) 100 else 50;
    stats.current.movement_speed += speed_bonus;
    stats.max.movement_speed += speed_bonus;
}

fn weaponBoon(
    comptime weapon_id: []const u8,
    comptime attack_slot: WeaponAttackSlot,
    comptime property: WeaponProjectileProperty,
    comptime multiplier: f32,
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime rarity: Boon.Rarity,
) Boon {
    return .{
        .id = id,
        .name = name,
        .description = description,
        .icon = "items/blueberry.png",
        .rarity = rarity,
        .boon_type = .weapon,
        .condition = hasWeaponCondition(weapon_id),
        .callback = weaponModifierCallback(weapon_id, attack_slot, property, multiplier),
    };
}

fn spellEquipBoon(
    comptime slot_index: usize,
    comptime spell_template: Spell,
    comptime spell_level: u32,
    comptime excluded_level: u32,
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime rarity: Boon.Rarity,
) Boon {
    return .{
        .id = id,
        .name = name,
        .description = description,
        .icon = "items/banana.png",
        .rarity = rarity,
        .boon_type = .spell,
        .condition = maxSpellLevelCondition(slot_index, spell_template.id, excluded_level),
        .callback = equipSpellCallback(slot_index, spell_template, spell_level),
    };
}

fn spellUpgradeBoon(
    comptime slot_index: usize,
    comptime level_delta: u32,
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime rarity: Boon.Rarity,
) Boon {
    return .{
        .id = id,
        .name = name,
        .description = description,
        .icon = "items/banana.png",
        .rarity = rarity,
        .boon_type = .spell,
        .condition = hasSpellInSlotCondition(slot_index),
        .callback = spellLevelBonusCallback(slot_index, level_delta),
    };
}

fn statBoon(
    comptime id: []const u8,
    comptime name: []const u8,
    comptime description: []const u8,
    comptime rarity: Boon.Rarity,
    comptime adjustments: []const StatAdjustment,
) Boon {
    return .{
        .id = id,
        .name = name,
        .description = description,
        .icon = "items/strawberry.png",
        .rarity = rarity,
        .boon_type = .stat,
        .callback = statBonusCallback(adjustments),
    };
}

/// Projectile width and velocity boons for the Goliath Weight Plate weapon.
pub const plates_width_speed_boons: []const Boon = &.{
    weaponBoon("Goliath", .light_attack, .width, 1.25, "goliath_wide_light_rare", "Wide Weight Plate: Light Sweep", "+25% light attack width", .rare),
    weaponBoon("Goliath", .heavy_attack, .width, 1.15, "goliath_wide_heavy_rare", "Wide Weight Plate: Heavy Sweep", "+15% heavy attack width", .rare),
    weaponBoon("Goliath", .dash_attack, .width, 1.1, "goliath_wide_dash_rare", "Wide Weight Plate: Dash Sweep", "+10% dash attack width", .rare),
    weaponBoon("Goliath", .heavy_attack, .width, 1.35, "goliath_wide_heavy_epic", "Wide Weight Plate: Colossus Slam", "+35% heavy attack width", .epic),
    weaponBoon("Goliath", .dash_attack, .width, 1.25, "goliath_wide_dash_epic", "Wide Weight Plate: Colossus Dash", "+25% dash attack width", .epic),
    weaponBoon("Goliath", .light_attack, .width, 1.5, "goliath_wide_light_legendary", "Wide Weight Plate: Titan Sweep", "+50% light attack width", .legendary),
    weaponBoon("Goliath", .light_attack, .speed, 1.20, "goliath_speed_light_normal", "Aerodynamic Plate: Fast Spin", "+20% light attack projectile speed", .normal),
    weaponBoon("Goliath", .heavy_attack, .speed, 1.20, "goliath_speed_heavy_normal", "Aerodynamic Plate: Swift Slam", "+20% heavy attack projectile speed", .normal),
    weaponBoon("Goliath", .dash_attack, .speed, 1.25, "goliath_speed_dash_rare", "Aerodynamic Plate: Ram Velocity", "+25% dash attack projectile speed", .rare),
    weaponBoon("Goliath", .all, .speed, 1.35, "goliath_speed_all_epic", "Vortex Weight Plate: Hyper Velocity", "+35% all plate attack projectile speed", .epic),
};

/// Attack damage multiplier boons for the Goliath Weight Plate weapon.
pub const plates_damage_boons: []const Boon = &.{
    weaponBoon("Goliath", .light_attack, .damage, 1.1, "goliath_pr_light", "New PR: Iron Grip (Weight Plate)", "+10% light attack damage", .normal),
    weaponBoon("Goliath", .heavy_attack, .damage, 1.1, "goliath_pr_heavy", "New PR: Heavy Slam (Weight Plate)", "+10% heavy attack damage", .normal),
    weaponBoon("Goliath", .dash_attack, .damage, 1.1, "goliath_pr_dash", "New PR: Momentum (Weight Plate)", "+10% dash attack damage", .normal),
    weaponBoon("Goliath", .light_attack, .damage, 1.25, "goliath_damage_light_rare", "Heavyweight Plate: Crushing Grip", "+25% light attack damage", .rare),
    weaponBoon("Goliath", .heavy_attack, .damage, 1.25, "goliath_damage_heavy_rare", "Heavyweight Plate: Brutal Slam", "+25% heavy attack damage", .rare),
    weaponBoon("Goliath", .dash_attack, .damage, 1.25, "goliath_damage_dash_rare", "Heavyweight Plate: Ramming Force", "+25% dash attack damage", .rare),
    weaponBoon("Goliath", .heavy_attack, .damage, 1.50, "goliath_damage_heavy_epic", "Iron Fortress: Cataclysmic Slam", "+50% heavy attack damage", .epic),
    weaponBoon("Goliath", .all, .damage, 1.75, "goliath_damage_colossus_legendary", "Colossus of Iron: Maximum Overload", "+75% all plate attack damage", .legendary),
};

/// Projectile width and velocity boons for the Fists Boxing Gloves weapon.
pub const gloves_width_speed_boons: []const Boon = &.{
    weaponBoon("Fists", .light_attack, .width, 1.25, "fists_wide_light_rare", "Wide Boxing Glove: Broad Jab", "+25% light attack width", .rare),
    weaponBoon("Fists", .heavy_attack, .width, 1.15, "fists_wide_heavy_rare", "Wide Boxing Glove: Broad Hook", "+15% heavy attack width", .rare),
    weaponBoon("Fists", .dash_attack, .width, 1.1, "fists_wide_dash_rare", "Wide Boxing Glove: Broad Cross", "+10% dash attack width", .rare),
    weaponBoon("Fists", .heavy_attack, .width, 1.35, "fists_wide_heavy_epic", "Wide Boxing Glove: Giant Hook", "+35% heavy attack width", .epic),
    weaponBoon("Fists", .dash_attack, .width, 1.25, "fists_wide_dash_epic", "Wide Boxing Glove: Giant Cross", "+25% dash attack width", .epic),
    weaponBoon("Fists", .light_attack, .width, 1.5, "fists_wide_light_legendary", "Wide Boxing Glove: Titan Jab", "+50% light attack width", .legendary),
    weaponBoon("Fists", .light_attack, .speed, 1.20, "fists_speed_jab_normal", "Speed Bag Training: Rapid Jab", "+20% light attack projectile speed", .normal),
    weaponBoon("Fists", .heavy_attack, .speed, 1.20, "fists_speed_hook_normal", "Speed Bag Training: Whiplash Hook", "+20% heavy attack projectile speed", .normal),
    weaponBoon("Fists", .dash_attack, .speed, 1.25, "fists_speed_cross_rare", "Lightning Step: Flash Cross", "+25% dash attack projectile speed", .rare),
    weaponBoon("Fists", .all, .speed, 1.35, "fists_speed_all_epic", "Mach Punch: Flurry Velocity", "+35% all boxing glove projectile speed", .epic),
};

/// Attack damage multiplier boons for the Fists Boxing Gloves weapon.
pub const gloves_damage_boons: []const Boon = &.{
    weaponBoon("Fists", .light_attack, .damage, 1.1, "fists_upg_light", "Boxing Glove: Jab Upgrade", "+10% light attack damage", .normal),
    weaponBoon("Fists", .heavy_attack, .damage, 1.1, "fists_upg_heavy", "Boxing Glove: Haymaker Upgrade", "+10% heavy attack damage", .normal),
    weaponBoon("Fists", .dash_attack, .damage, 1.1, "fists_upg_dash", "Boxing Glove: Cross Upgrade", "+10% dash attack damage", .normal),
    weaponBoon("Fists", .light_attack, .damage, 1.25, "fists_damage_light_rare", "Reinforced Leather: Lead Jab", "+25% light attack damage", .rare),
    weaponBoon("Fists", .heavy_attack, .damage, 1.25, "fists_damage_heavy_rare", "Reinforced Leather: Sledgehammer Hook", "+25% heavy attack damage", .rare),
    weaponBoon("Fists", .dash_attack, .damage, 1.25, "fists_damage_dash_rare", "Reinforced Leather: Bullet Cross", "+25% dash attack damage", .rare),
    weaponBoon("Fists", .heavy_attack, .damage, 1.50, "fists_damage_heavy_epic", "Knockout King: Thunderous Haymaker", "+50% heavy attack damage", .epic),
    weaponBoon("Fists", .all, .damage, 1.75, "fists_damage_champion_legendary", "Undisputed Champion: Golden Gloves", "+75% all boxing glove damage", .legendary),
};

/// Active spell replacement boons.
pub const new_supplements_boons: []const Boon = &.{
    .{
        .id = "ashwaganda_1",
        .name = "Ashwaganda",
        .description = "Puts surrounding enemies to sleep after 2s.\nReplaces: Right Spell",
        .icon = "items/banana.png",
        .rarity = .normal,
        .boon_type = .spell,
        .condition = maxSpellLevelCondition(1, "Root", 2),
        .callback = equipAshwagandaTierOneCallback,
    },
    spellEquipBoon(0, spells.heal, 5, 5, "vitamin_mix_1", "Vitamin Mix", "Restores health over time.\nReplaces: Left Spell", .normal),
    spellEquipBoon(0, spells.goliath, 1, 1, "creatine_1", "Creatine", "Increased size and max health for 15s.\nReplaces: Left Spell", .normal),
    spellEquipBoon(1, spells.haste, 6, 6, "pre_workout_1", "Pre Workout", "Bonus movement and attack speed for 5s.\nReplaces: Right Spell", .rare),
    spellEquipBoon(1, spells.root, 2, 2, "ashwaganda_2", "Ashwaganda x2", "Puts surrounding enemies to sleep after 2s.\nReplaces: Right Spell", .rare),
    spellEquipBoon(0, spells.heal, 10, 10, "vitamin_mix_2", "Vitamin Mix x2", "Restores health over time.\nReplaces: Left Spell", .rare),
    spellEquipBoon(0, spells.goliath, 2, 2, "creatine_2", "Creatine x2", "Increased size and max health for 15s.\nReplaces: Left Spell", .rare),
    spellEquipBoon(1, spells.haste, 9, 9, "pre_workout_monster", "Pre Workout + Monster", "Bonus movement and attack speed for 5s.\nReplaces: Right Spell", .legendary),
    spellEquipBoon(1, spells.root, 4, 4, "ashwaganda_3", "Ashwaganda x3", "Puts surrounding enemies to sleep after 2s.\nReplaces: Right Spell", .legendary),
    spellEquipBoon(0, spells.goliath, 5, 5, "creatine_3", "Creatine x3", "Increased size and max health for 15s.\nReplaces: Left Spell", .legendary),
    spellEquipBoon(0, spells.heal, 25, 25, "vitamin_mix_3", "Vitamin Mix x3", "Restores health over time.\nReplaces: Left Spell", .mythic),
};

/// Level upgrade boons for equipped left and right active spells.
pub const supplement_upgrades_boons: []const Boon = &.{
    spellUpgradeBoon(0, 1, "left_spell_upg_1", "Left Spell Upgrade", "+1 level", .normal),
    spellUpgradeBoon(1, 1, "right_spell_upg_1", "Right Spell Upgrade", "+1 level", .normal),
    spellUpgradeBoon(0, 2, "left_spell_upg_2", "Left Spell Upgrade (+2)", "+2 levels", .rare),
    spellUpgradeBoon(1, 2, "right_spell_upg_2", "Right Spell Upgrade (+2)", "+2 levels", .rare),
    spellUpgradeBoon(0, 3, "left_spell_upg_3", "Left Spell Upgrade (+3)", "+3 levels", .epic),
    spellUpgradeBoon(1, 3, "right_spell_upg_3", "Right Spell Upgrade (+3)", "+3 levels", .epic),
    spellUpgradeBoon(0, 5, "left_spell_upg_5", "Left Spell Upgrade (+5)", "+5 levels", .legendary),
    spellUpgradeBoon(1, 5, "right_spell_upg_5", "Right Spell Upgrade (+5)", "+5 levels", .legendary),
    spellUpgradeBoon(0, 7, "left_spell_upg_7", "Left Spell Upgrade (+7)", "+7 levels", .cosmic),
    spellUpgradeBoon(1, 7, "right_spell_upg_7", "Right Spell Upgrade (+7)", "+7 levels", .cosmic),
};

/// Player attribute boons covering health, stamina, speed, damage, and critical hits.
pub const vitality_boons: []const Boon = &.{
    statBoon("underpass_gyros", "Underpass Gyros", "Increases movement speed.\n+20 movement speed", .normal, &.{.{ .field_name = "movement_speed", .delta = 20 }}),
    statBoon("meat_tower", "Meat Tower", "+20 damage", .normal, &.{.{ .field_name = "physical_damage", .delta = 20 }}),
    statBoon("anabolic_tren", "Anabolic Tren", "+25 max health.", .normal, &.{.{ .field_name = "health", .delta = 25 }}),
    statBoon("energy_gel_normal", "Energy Gel", "+25 max stamina", .normal, &.{.{ .field_name = "stamina", .delta = 25 }}),
    statBoon("steroid_shot", "Steroid Shot", "+50 max health.", .rare, &.{.{ .field_name = "health", .delta = 50 }}),
    statBoon("tempting_meat_tower", "Tempting Meat Tower", "+35 damage", .rare, &.{.{ .field_name = "physical_damage", .delta = 35 }}),
    statBoon("nike_blazer", "Nike Blazer", "+1 dash", .rare, &.{.{ .field_name = "stamina", .delta = 50 }}),
    statBoon("wifebeater_tank_top", "Wifebeater Tank Top", "+1 attack speed", .rare, &.{.{ .field_name = "attack_speed", .delta = 1 }}),
    statBoon("caffeine_powder_rare", "Pure Caffeine Powder", "+50 max stamina\n+0.2 attack speed", .rare, &.{
        .{ .field_name = "stamina", .delta = 50 },
        .{ .field_name = "attack_speed", .delta = 0.2 },
    }),
    statBoon("focus_supplement_rare", "Focus Formula", "+10% critical hit chance", .rare, &.{.{ .field_name = "crit_chance", .delta = 0.10 }}),
    statBoon("electrolytes_rare", "Electrolyte Surge", "+50% critical damage multiplier", .rare, &.{.{ .field_name = "crit_damage_multiplier", .delta = 0.50 }}),
    statBoon("trenbolone_acetate", "Trenbolone Acetate", "+100 max health.", .epic, &.{.{ .field_name = "health", .delta = 100 }}),
    statBoon("nootropic_blend_epic", "Nootropic Mind Matrix", "+20% critical hit chance", .epic, &.{.{ .field_name = "crit_chance", .delta = 0.20 }}),
    statBoon("adrenochrome_epic", "Adrenaline Infusion", "+100% critical damage multiplier", .epic, &.{.{ .field_name = "crit_damage_multiplier", .delta = 1.00 }}),
    .{
        .id = "nike_ow_blazer",
        .name = "Nike OW Blazer",
        .description = "+1 dash\n+100 movement speed",
        .icon = "items/strawberry.png",
        .rarity = .legendary,
        .boon_type = .stat,
        .callback = nikeOwBlazerCallback,
    },
    statBoon("irresistible_meat_tower", "Irresistible Meat Tower", "+50 damage", .legendary, &.{.{ .field_name = "physical_damage", .delta = 50 }}),
    statBoon("apex_focus_legendary", "Apex Flow State", "+30% critical hit chance", .legendary, &.{.{ .field_name = "crit_chance", .delta = 0.30 }}),
};

fn collectAllBoons() []const Boon {
    var collected: []const Boon = &.{};
    for (@typeInfo(@This()).@"struct".decl_names) |declaration_name| {
        if (std.mem.eql(u8, declaration_name, "all_boons")) continue;
        const declaration_value = @field(@This(), declaration_name);
        if (@TypeOf(declaration_value) == []const Boon) {
            collected = collected ++ declaration_value;
        }
    }
    return collected;
}

/// Flattened slice of every boon across all category slices in this module.
pub const all_boons: []const Boon = collectAllBoons();

fn validateBoonPair(comptime first_boon: Boon, comptime second_boon: Boon) void {
    if (std.mem.eql(u8, first_boon.id, second_boon.id)) {
        @compileError("Duplicate boon id: " ++ first_boon.id);
    }
    if (std.mem.eql(u8, first_boon.name, second_boon.name)) {
        @compileError("Duplicate boon name: " ++ first_boon.name);
    }
}

fn validateAllBoons(comptime boon_list: []const Boon) void {
    for (boon_list, 0..) |first_boon, outer_index| {
        if (first_boon.id.len == 0) @compileError("Boon id must not be empty");
        if (first_boon.name.len == 0) @compileError("Boon name must not be empty");
        if (first_boon.description.len == 0) @compileError("Boon description must not be empty");
        if (first_boon.icon.len == 0) @compileError("Boon icon must not be empty");
        for (boon_list[outer_index + 1 ..]) |second_boon| {
            validateBoonPair(first_boon, second_boon);
        }
    }
}

comptime {
    @setEvalBranchQuota(100_000);
    validateAllBoons(all_boons);
}

test "all boons count and conditions preserve expected catalog" {
    try std.testing.expectEqual(@as(usize, 74), all_boons.len);

    const stats = Stats{ .team = .player };
    var attack = Attack{};
    try std.testing.expect(plates_damage_boons[0].isAvailable(&stats, &attack));
    attack.equipped_weapons[1] = null;
    try std.testing.expect(!plates_damage_boons[0].isAvailable(&stats, &attack));
}
