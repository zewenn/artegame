const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const Spell = @import("../../components/Weapons/Spell.zig");
const spells = @import("../../components/Weapons/spells.zig");
const Boon = @import("Boon.zig");

// Helper Condition Functions
fn hasSpellSlot0(_: Stats, attack: Attack) bool {
    return attack.equipped_spells[0] != null;
}

fn hasSpellSlot1(_: Stats, attack: Attack) bool {
    return attack.equipped_spells[1] != null;
}

fn hasFistsWeapon(_: Stats, attack: Attack) bool {
    for (attack.equipped_weapons) |maybe_w| {
        if (maybe_w) |w| {
            if (std.mem.eql(u8, w.id, "Fists")) return true;
        }
    }
    return false;
}

fn hasGoliathWeapon(_: Stats, attack: Attack) bool {
    for (attack.equipped_weapons) |maybe_w| {
        if (maybe_w) |w| {
            if (std.mem.eql(u8, w.id, "Goliath")) return true;
        }
    }
    return false;
}

// All 50 Boon Definitions (Reclassified across 6 Rarities: Normal, Rare, Epic, Legendary, Mythic, Cosmic)
pub const all_boons: []const Boon = &.{
    // --- Spell Boons (21) ---
    .{
        .name = "Ashwaganda",
        .description = "Puts surrounding enemies to sleep after 2s.\nReplaces: Right Spell",
        .icon = "items/banana.png",
        .rarity = .normal,
        .boon_type = .spell,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    var s = spells.root;
                    s.level = 1;
                    att.equipped_spells[1] = s;
                }
            }
        }.cb,
    },
    .{
        .name = "Vitamin Mix",
        .description = "Restores health over time.\nReplaces: Left Spell",
        .icon = "items/banana.png",
        .rarity = .normal,
        .boon_type = .spell,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    var s = spells.heal;
                    s.level = 5;
                    att.equipped_spells[0] = s;
                }
            }
        }.cb,
    },
    .{
        .name = "Creatine",
        .description = "Increased size and max health for 15s.\nReplaces: Left Spell",
        .icon = "items/banana.png",
        .rarity = .normal,
        .boon_type = .spell,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    var s = spells.goliath;
                    s.level = 1;
                    att.equipped_spells[0] = s;
                }
            }
        }.cb,
    },
    .{
        .name = "Left Spell Upgrade",
        .description = "+1 level",
        .icon = "items/banana.png",
        .rarity = .normal,
        .boon_type = .spell,
        .condition = hasSpellSlot0,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_spells[0]) |*s| s.level += 1;
                }
            }
        }.cb,
    },
    .{
        .name = "Right Spell Upgrade",
        .description = "+1 level",
        .icon = "items/banana.png",
        .rarity = .normal,
        .boon_type = .spell,
        .condition = hasSpellSlot1,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_spells[1]) |*s| s.level += 1;
                }
            }
        }.cb,
    },
    .{
        .name = "Pre Workout",
        .description = "Bonus movement and attack speed for 5s.\nReplaces: Right Spell",
        .icon = "items/banana.png",
        .rarity = .rare,
        .boon_type = .spell,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    var s = spells.haste;
                    s.level = 6;
                    att.equipped_spells[1] = s;
                }
            }
        }.cb,
    },
    .{
        .name = "Ashwaganda x2",
        .description = "Puts surrounding enemies to sleep after 2s.\nReplaces: Right Spell",
        .icon = "items/banana.png",
        .rarity = .rare,
        .boon_type = .spell,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    var s = spells.root;
                    s.level = 2;
                    att.equipped_spells[1] = s;
                }
            }
        }.cb,
    },
    .{
        .name = "Vitamin Mix x2",
        .description = "Restores health over time.\nReplaces: Left Spell",
        .icon = "items/banana.png",
        .rarity = .rare,
        .boon_type = .spell,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    var s = spells.heal;
                    s.level = 10;
                    att.equipped_spells[0] = s;
                }
            }
        }.cb,
    },
    .{
        .name = "Creatine x2",
        .description = "Increased size and max health for 15s.\nReplaces: Left Spell",
        .icon = "items/banana.png",
        .rarity = .rare,
        .boon_type = .spell,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    var s = spells.goliath;
                    s.level = 2;
                    att.equipped_spells[0] = s;
                }
            }
        }.cb,
    },
    .{
        .name = "Left Spell Upgrade (+2)",
        .description = "+2 levels",
        .icon = "items/banana.png",
        .rarity = .rare,
        .boon_type = .spell,
        .condition = hasSpellSlot0,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_spells[0]) |*s| s.level += 2;
                }
            }
        }.cb,
    },
    .{
        .name = "Right Spell Upgrade (+2)",
        .description = "+2 levels",
        .icon = "items/banana.png",
        .rarity = .rare,
        .boon_type = .spell,
        .condition = hasSpellSlot1,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_spells[1]) |*s| s.level += 2;
                }
            }
        }.cb,
    },
    .{
        .name = "Left Spell Upgrade (+3)",
        .description = "+3 levels",
        .icon = "items/banana.png",
        .rarity = .epic,
        .boon_type = .spell,
        .condition = hasSpellSlot0,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_spells[0]) |*s| s.level += 3;
                }
            }
        }.cb,
    },
    .{
        .name = "Right Spell Upgrade (+3)",
        .description = "+3 levels",
        .icon = "items/banana.png",
        .rarity = .epic,
        .boon_type = .spell,
        .condition = hasSpellSlot1,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_spells[1]) |*s| s.level += 3;
                }
            }
        }.cb,
    },
    .{
        .name = "Pre Workout + Monster",
        .description = "Bonus movement and attack speed for 5s.\nReplaces: Right Spell",
        .icon = "items/banana.png",
        .rarity = .legendary,
        .boon_type = .spell,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    var s = spells.haste;
                    s.level = 9;
                    att.equipped_spells[1] = s;
                }
            }
        }.cb,
    },
    .{
        .name = "Ashwaganda x3",
        .description = "Puts surrounding enemies to sleep after 2s.\nReplaces: Right Spell",
        .icon = "items/banana.png",
        .rarity = .legendary,
        .boon_type = .spell,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    var s = spells.root;
                    s.level = 4;
                    att.equipped_spells[1] = s;
                }
            }
        }.cb,
    },
    .{
        .name = "Creatine x3",
        .description = "Increased size and max health for 15s.\nReplaces: Left Spell",
        .icon = "items/banana.png",
        .rarity = .legendary,
        .boon_type = .spell,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    var s = spells.goliath;
                    s.level = 5;
                    att.equipped_spells[0] = s;
                }
            }
        }.cb,
    },
    .{
        .name = "Left Spell Upgrade (+5)",
        .description = "+5 levels",
        .icon = "items/banana.png",
        .rarity = .legendary,
        .boon_type = .spell,
        .condition = hasSpellSlot0,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_spells[0]) |*s| s.level += 5;
                }
            }
        }.cb,
    },
    .{
        .name = "Right Spell Upgrade (+5)",
        .description = "+5 levels",
        .icon = "items/banana.png",
        .rarity = .legendary,
        .boon_type = .spell,
        .condition = hasSpellSlot1,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_spells[1]) |*s| s.level += 5;
                }
            }
        }.cb,
    },
    .{
        .name = "Vitamin Mix x3",
        .description = "Restores health over time.\nReplaces: Left Spell",
        .icon = "items/banana.png",
        .rarity = .mythic,
        .boon_type = .spell,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    var s = spells.heal;
                    s.level = 25;
                    att.equipped_spells[0] = s;
                }
            }
        }.cb,
    },
    .{
        .name = "Left Spell Upgrade (+7)",
        .description = "+7 levels",
        .icon = "items/banana.png",
        .rarity = .cosmic,
        .boon_type = .spell,
        .condition = hasSpellSlot0,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_spells[0]) |*s| s.level += 7;
                }
            }
        }.cb,
    },
    .{
        .name = "Right Spell Upgrade (+7)",
        .description = "+7 levels",
        .icon = "items/banana.png",
        .rarity = .cosmic,
        .boon_type = .spell,
        .condition = hasSpellSlot1,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_spells[1]) |*s| s.level += 7;
                }
            }
        }.cb,
    },

    // --- Stat Boons (11) ---
    .{
        .name = "Underpass Gyros",
        .description = "Increases movement speed.\n+20 movement speed",
        .icon = "items/strawberry.png",
        .rarity = .normal,
        .boon_type = .stat,
        .callback = struct {
            pub fn cb(stats: *Stats, _: ?*Attack) void {
                stats.current.movement_speed += 20;
                stats.max.movement_speed += 20;
            }
        }.cb,
    },
    .{
        .name = "Meat Tower",
        .description = "+20 damage",
        .icon = "items/strawberry.png",
        .rarity = .normal,
        .boon_type = .stat,
        .callback = struct {
            pub fn cb(stats: *Stats, _: ?*Attack) void {
                stats.current.physical_damage += 20;
                stats.max.physical_damage += 20;
            }
        }.cb,
    },
    .{
        .name = "Anabolic Tren",
        .description = "+25 max health.",
        .icon = "items/strawberry.png",
        .rarity = .normal,
        .boon_type = .stat,
        .callback = struct {
            pub fn cb(stats: *Stats, _: ?*Attack) void {
                stats.max.health += 25;
                stats.current.health += 25;
            }
        }.cb,
    },
    .{
        .name = "More Mana",
        .description = "+10 max mana.",
        .icon = "items/strawberry.png",
        .rarity = .normal,
        .boon_type = .stat,
        .callback = struct {
            pub fn cb(stats: *Stats, _: ?*Attack) void {
                stats.max.mana += 10;
                stats.current.mana += 10;
            }
        }.cb,
    },
    .{
        .name = "Steroid Shot",
        .description = "+50 max health.",
        .icon = "items/strawberry.png",
        .rarity = .rare,
        .boon_type = .stat,
        .callback = struct {
            pub fn cb(stats: *Stats, _: ?*Attack) void {
                stats.max.health += 50;
                stats.current.health += 50;
            }
        }.cb,
    },
    .{
        .name = "Tempting Meat Tower",
        .description = "+35 damage",
        .icon = "items/strawberry.png",
        .rarity = .rare,
        .boon_type = .stat,
        .callback = struct {
            pub fn cb(stats: *Stats, _: ?*Attack) void {
                stats.current.physical_damage += 35;
                stats.max.physical_damage += 35;
            }
        }.cb,
    },
    .{
        .name = "Nike Blazer",
        .description = "+1 dash",
        .icon = "items/strawberry.png",
        .rarity = .rare,
        .boon_type = .stat,
        .callback = struct {
            pub fn cb(stats: *Stats, _: ?*Attack) void {
                stats.max.stamina += 50;
                stats.current.stamina += 50;
            }
        }.cb,
    },
    .{
        .name = "Wifebeater Tank Top",
        .description = "+1 attack speed",
        .icon = "items/strawberry.png",
        .rarity = .rare,
        .boon_type = .stat,
        .callback = struct {
            pub fn cb(stats: *Stats, _: ?*Attack) void {
                stats.current.attack_speed += 1;
                stats.max.attack_speed += 1;
            }
        }.cb,
    },
    .{
        .name = "Anabolic Tren",
        .description = "+100 max health.",
        .icon = "items/strawberry.png",
        .rarity = .epic,
        .boon_type = .stat,
        .callback = struct {
            pub fn cb(stats: *Stats, _: ?*Attack) void {
                stats.max.health += 100;
                stats.current.health += 100;
            }
        }.cb,
    },
    .{
        .name = "Nike OW Blazer",
        .description = "+1 dash\n+100 movement speed",
        .icon = "items/strawberry.png",
        .rarity = .legendary,
        .boon_type = .stat,
        .callback = struct {
            pub fn cb(stats: *Stats, _: ?*Attack) void {
                stats.max.stamina += 50;
                stats.current.stamina += 50;
                if (stats.current.movement_speed < 600) {
                    stats.current.movement_speed += 100;
                    stats.max.movement_speed += 100;
                } else {
                    stats.current.movement_speed += 50;
                    stats.max.movement_speed += 50;
                }
            }
        }.cb,
    },
    .{
        .name = "Irresistible Meat Tower",
        .description = "+50 damage",
        .icon = "items/strawberry.png",
        .rarity = .legendary,
        .boon_type = .stat,
        .callback = struct {
            pub fn cb(stats: *Stats, _: ?*Attack) void {
                stats.current.physical_damage += 50;
                stats.max.physical_damage += 50;
            }
        }.cb,
    },

    // --- Weapon Boons (18) ---
    .{
        .name = "New PR (Weight Plate)",
        .description = "+10% light attack damage",
        .icon = "items/blueberry.png",
        .rarity = .normal,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_weapons[1]) |*w| w.light_attack.projectile_options.damage *= 1.1;
                }
            }
        }.cb,
    },
    .{
        .name = "New PR (Weight Plate)",
        .description = "+10% heavy attack damage",
        .icon = "items/blueberry.png",
        .rarity = .normal,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_weapons[1]) |*w| w.heavy_attack.projectile_options.damage *= 1.1;
                }
            }
        }.cb,
    },
    .{
        .name = "New PR (Weight Plate)",
        .description = "+10% dash attack damage",
        .icon = "items/blueberry.png",
        .rarity = .normal,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_weapons[1]) |*w| w.dash_attack.projectile_options.damage *= 1.1;
                }
            }
        }.cb,
    },
    .{
        .name = "Boxing Glove Upgrade",
        .description = "+10% light attack damage",
        .icon = "items/blueberry.png",
        .rarity = .normal,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_weapons[0]) |*w| w.light_attack.projectile_options.damage *= 1.1;
                }
            }
        }.cb,
    },
    .{
        .name = "Boxing Glove Upgrade",
        .description = "+10% heavy attack damage",
        .icon = "items/blueberry.png",
        .rarity = .normal,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_weapons[0]) |*w| w.heavy_attack.projectile_options.damage *= 1.1;
                }
            }
        }.cb,
    },
    .{
        .name = "Boxing Glove Upgrade",
        .description = "+10% dash attack damage",
        .icon = "items/blueberry.png",
        .rarity = .normal,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_weapons[0]) |*w| w.dash_attack.projectile_options.damage *= 1.1;
                }
            }
        }.cb,
    },
    .{
        .name = "Wide Weight Plate",
        .description = "+25% light attack width",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_weapons[1]) |*w| w.light_attack.projectile_options.size.x *= 1.25;
                }
            }
        }.cb,
    },
    .{
        .name = "Wide Boxing Glove",
        .description = "+25% light attack width",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_weapons[0]) |*w| w.light_attack.projectile_options.size.x *= 1.25;
                }
            }
        }.cb,
    },
    .{
        .name = "Wide Weight Plate",
        .description = "+15% heavy attack width",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_weapons[1]) |*w| w.heavy_attack.projectile_options.size.x *= 1.15;
                }
            }
        }.cb,
    },
    .{
        .name = "Wide Boxing Glove",
        .description = "+15% heavy attack width",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_weapons[0]) |*w| w.heavy_attack.projectile_options.size.x *= 1.15;
                }
            }
        }.cb,
    },
    .{
        .name = "Wide Weight Plate",
        .description = "+10% dash attack width",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_weapons[1]) |*w| w.dash_attack.projectile_options.size.x *= 1.1;
                }
            }
        }.cb,
    },
    .{
        .name = "Wide Boxing Glove",
        .description = "+10% dash attack width",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_weapons[0]) |*w| w.dash_attack.projectile_options.size.x *= 1.1;
                }
            }
        }.cb,
    },
    .{
        .name = "Wide Weight Plate",
        .description = "+35% heavy attack width",
        .icon = "items/blueberry.png",
        .rarity = .epic,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_weapons[1]) |*w| w.heavy_attack.projectile_options.size.x *= 1.35;
                }
            }
        }.cb,
    },
    .{
        .name = "Wide Boxing Glove",
        .description = "+35% heavy attack width",
        .icon = "items/blueberry.png",
        .rarity = .epic,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_weapons[0]) |*w| w.heavy_attack.projectile_options.size.x *= 1.35;
                }
            }
        }.cb,
    },
    .{
        .name = "Wide Weight Plate",
        .description = "+25% dash attack width",
        .icon = "items/blueberry.png",
        .rarity = .epic,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_weapons[1]) |*w| w.dash_attack.projectile_options.size.x *= 1.25;
                }
            }
        }.cb,
    },
    .{
        .name = "Wide Boxing Glove",
        .description = "+25% dash attack width",
        .icon = "items/blueberry.png",
        .rarity = .epic,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_weapons[0]) |*w| w.dash_attack.projectile_options.size.x *= 1.25;
                }
            }
        }.cb,
    },
    .{
        .name = "Wide Weight Plate",
        .description = "+50% light attack width",
        .icon = "items/blueberry.png",
        .rarity = .legendary,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_weapons[1]) |*w| w.light_attack.projectile_options.size.x *= 1.5;
                }
            }
        }.cb,
    },
    .{
        .name = "Wide Boxing Glove",
        .description = "+50% light attack width",
        .icon = "items/blueberry.png",
        .rarity = .legendary,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.equipped_weapons[0]) |*w| w.light_attack.projectile_options.size.x *= 1.5;
                }
            }
        }.cb,
    },
};
