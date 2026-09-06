const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const Spell = @import("../../components/Weapons/Spell.zig");
const spells = @import("../../components/Weapons/spells.zig");
const Boon = @import("Boon.zig");

pub const BoonPool = @import("BoonPool.zig");

fn hasSpellSlot0(_: Stats, attack: Attack) bool {
    return attack.equipped_spells[0] != null;
}

fn hasSpellSlot1(_: Stats, attack: Attack) bool {
    return attack.equipped_spells[1] != null;
}

fn hasFistsWeapon(_: Stats, attack: Attack) bool {
    return attack.hasWeaponId("Fists");
}

fn hasGoliathWeapon(_: Stats, attack: Attack) bool {
    return attack.hasWeaponId("Goliath");
}

fn canOfferAshwaganda1(_: Stats, attack: Attack) bool {
    if (attack.equipped_spells[1]) |s| {
        if (std.mem.eql(u8, s.id, "Root") and s.level >= 2) return false;
    }
    return true;
}

fn canOfferAshwaganda2(_: Stats, attack: Attack) bool {
    if (attack.equipped_spells[1]) |s| {
        if (std.mem.eql(u8, s.id, "Root") and s.level >= 2) return false;
    }
    return true;
}

fn canOfferAshwaganda3(_: Stats, attack: Attack) bool {
    if (attack.equipped_spells[1]) |s| {
        if (std.mem.eql(u8, s.id, "Root") and s.level >= 4) return false;
    }
    return true;
}

fn canOfferVitaminMix1(_: Stats, attack: Attack) bool {
    if (attack.equipped_spells[0]) |s| {
        if (std.mem.eql(u8, s.id, "Heal") and s.level >= 5) return false;
    }
    return true;
}

fn canOfferVitaminMix2(_: Stats, attack: Attack) bool {
    if (attack.equipped_spells[0]) |s| {
        if (std.mem.eql(u8, s.id, "Heal") and s.level >= 10) return false;
    }
    return true;
}

fn canOfferVitaminMix3(_: Stats, attack: Attack) bool {
    if (attack.equipped_spells[0]) |s| {
        if (std.mem.eql(u8, s.id, "Heal") and s.level >= 25) return false;
    }
    return true;
}

fn canOfferCreatine1(_: Stats, attack: Attack) bool {
    if (attack.equipped_spells[0]) |s| {
        if (std.mem.eql(u8, s.id, "Goliath") and s.level >= 1) return false;
    }
    return true;
}

fn canOfferCreatine2(_: Stats, attack: Attack) bool {
    if (attack.equipped_spells[0]) |s| {
        if (std.mem.eql(u8, s.id, "Goliath") and s.level >= 2) return false;
    }
    return true;
}

fn canOfferCreatine3(_: Stats, attack: Attack) bool {
    if (attack.equipped_spells[0]) |s| {
        if (std.mem.eql(u8, s.id, "Goliath") and s.level >= 5) return false;
    }
    return true;
}

fn canOfferPreWorkout1(_: Stats, attack: Attack) bool {
    if (attack.equipped_spells[1]) |s| {
        if (std.mem.eql(u8, s.id, "Haste") and s.level >= 6) return false;
    }
    return true;
}

fn canOfferPreWorkout2(_: Stats, attack: Attack) bool {
    if (attack.equipped_spells[1]) |s| {
        if (std.mem.eql(u8, s.id, "Haste") and s.level >= 9) return false;
    }
    return true;
}

pub const all_boons: []const Boon = &.{
    .{
        .id = "ashwaganda_1",
        .name = "Ashwaganda",
        .description = "Puts surrounding enemies to sleep after 2s.\nReplaces: Right Spell",
        .icon = "items/banana.png",
        .rarity = .normal,
        .boon_type = .spell,
        .condition = canOfferAshwaganda1,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    var s = spells.root;
                    s.level = if (att.equipped_spells[1]) |curr|
                        if (std.mem.eql(u8, curr.id, "Root")) @max(curr.level + 1, 2) else 1
                    else
                        1;
                    att.equipped_spells[1] = s;
                }
            }
        }.cb,
    },
    .{
        .id = "vitamin_mix_1",
        .name = "Vitamin Mix",
        .description = "Restores health over time.\nReplaces: Left Spell",
        .icon = "items/banana.png",
        .rarity = .normal,
        .boon_type = .spell,
        .condition = canOfferVitaminMix1,
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
        .id = "creatine_1",
        .name = "Creatine",
        .description = "Increased size and max health for 15s.\nReplaces: Left Spell",
        .icon = "items/banana.png",
        .rarity = .normal,
        .boon_type = .spell,
        .condition = canOfferCreatine1,
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
        .id = "left_spell_upg_1",
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
        .id = "right_spell_upg_1",
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
        .id = "pre_workout_1",
        .name = "Pre Workout",
        .description = "Bonus movement and attack speed for 5s.\nReplaces: Right Spell",
        .icon = "items/banana.png",
        .rarity = .rare,
        .boon_type = .spell,
        .condition = canOfferPreWorkout1,
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
        .id = "ashwaganda_2",
        .name = "Ashwaganda x2",
        .description = "Puts surrounding enemies to sleep after 2s.\nReplaces: Right Spell",
        .icon = "items/banana.png",
        .rarity = .rare,
        .boon_type = .spell,
        .condition = canOfferAshwaganda2,
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
        .id = "vitamin_mix_2",
        .name = "Vitamin Mix x2",
        .description = "Restores health over time.\nReplaces: Left Spell",
        .icon = "items/banana.png",
        .rarity = .rare,
        .boon_type = .spell,
        .condition = canOfferVitaminMix2,
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
        .id = "creatine_2",
        .name = "Creatine x2",
        .description = "Increased size and max health for 15s.\nReplaces: Left Spell",
        .icon = "items/banana.png",
        .rarity = .rare,
        .boon_type = .spell,
        .condition = canOfferCreatine2,
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
        .id = "left_spell_upg_2",
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
        .id = "right_spell_upg_2",
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
        .id = "left_spell_upg_3",
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
        .id = "right_spell_upg_3",
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
        .id = "pre_workout_monster",
        .name = "Pre Workout + Monster",
        .description = "Bonus movement and attack speed for 5s.\nReplaces: Right Spell",
        .icon = "items/banana.png",
        .rarity = .legendary,
        .boon_type = .spell,
        .condition = canOfferPreWorkout2,
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
        .id = "ashwaganda_3",
        .name = "Ashwaganda x3",
        .description = "Puts surrounding enemies to sleep after 2s.\nReplaces: Right Spell",
        .icon = "items/banana.png",
        .rarity = .legendary,
        .boon_type = .spell,
        .condition = canOfferAshwaganda3,
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
        .id = "creatine_3",
        .name = "Creatine x3",
        .description = "Increased size and max health for 15s.\nReplaces: Left Spell",
        .icon = "items/banana.png",
        .rarity = .legendary,
        .boon_type = .spell,
        .condition = canOfferCreatine3,
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
        .id = "left_spell_upg_5",
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
        .id = "right_spell_upg_5",
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
        .id = "vitamin_mix_3",
        .name = "Vitamin Mix x3",
        .description = "Restores health over time.\nReplaces: Left Spell",
        .icon = "items/banana.png",
        .rarity = .mythic,
        .boon_type = .spell,
        .condition = canOfferVitaminMix3,
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
        .id = "left_spell_upg_7",
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
        .id = "right_spell_upg_7",
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

    .{
        .id = "underpass_gyros",
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
        .id = "meat_tower",
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
        .id = "anabolic_tren",
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
        .id = "steroid_shot",
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
        .id = "tempting_meat_tower",
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
        .id = "nike_blazer",
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
        .id = "wifebeater_tank_top",
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
        .id = "trenbolone_acetate",
        .name = "Trenbolone Acetate",
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
        .id = "nike_ow_blazer",
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
        .id = "irresistible_meat_tower",
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

    .{
        .id = "goliath_pr_light",
        .name = "New PR: Iron Grip (Weight Plate)",
        .description = "+10% light attack damage",
        .icon = "items/blueberry.png",
        .rarity = .normal,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.getWeaponById("Goliath")) |w| w.light_attack.projectile_options.damage *= 1.1;
                }
            }
        }.cb,
    },
    .{
        .id = "goliath_pr_heavy",
        .name = "New PR: Heavy Slam (Weight Plate)",
        .description = "+10% heavy attack damage",
        .icon = "items/blueberry.png",
        .rarity = .normal,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.getWeaponById("Goliath")) |w| w.heavy_attack.projectile_options.damage *= 1.1;
                }
            }
        }.cb,
    },
    .{
        .id = "goliath_pr_dash",
        .name = "New PR: Momentum (Weight Plate)",
        .description = "+10% dash attack damage",
        .icon = "items/blueberry.png",
        .rarity = .normal,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.getWeaponById("Goliath")) |w| w.dash_attack.projectile_options.damage *= 1.1;
                }
            }
        }.cb,
    },
    .{
        .id = "fists_upg_light",
        .name = "Boxing Glove: Jab Upgrade",
        .description = "+10% light attack damage",
        .icon = "items/blueberry.png",
        .rarity = .normal,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.getWeaponById("Fists")) |w| w.light_attack.projectile_options.damage *= 1.1;
                }
            }
        }.cb,
    },
    .{
        .id = "fists_upg_heavy",
        .name = "Boxing Glove: Haymaker Upgrade",
        .description = "+10% heavy attack damage",
        .icon = "items/blueberry.png",
        .rarity = .normal,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.getWeaponById("Fists")) |w| w.heavy_attack.projectile_options.damage *= 1.1;
                }
            }
        }.cb,
    },
    .{
        .id = "fists_upg_dash",
        .name = "Boxing Glove: Cross Upgrade",
        .description = "+10% dash attack damage",
        .icon = "items/blueberry.png",
        .rarity = .normal,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.getWeaponById("Fists")) |w| w.dash_attack.projectile_options.damage *= 1.1;
                }
            }
        }.cb,
    },
    .{
        .id = "goliath_wide_light_rare",
        .name = "Wide Weight Plate: Light Sweep",
        .description = "+25% light attack width",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.getWeaponById("Goliath")) |w| w.light_attack.projectile_options.size.x *= 1.25;
                }
            }
        }.cb,
    },
    .{
        .id = "fists_wide_light_rare",
        .name = "Wide Boxing Glove: Broad Jab",
        .description = "+25% light attack width",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.getWeaponById("Fists")) |w| w.light_attack.projectile_options.size.x *= 1.25;
                }
            }
        }.cb,
    },
    .{
        .id = "goliath_wide_heavy_rare",
        .name = "Wide Weight Plate: Heavy Sweep",
        .description = "+15% heavy attack width",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.getWeaponById("Goliath")) |w| w.heavy_attack.projectile_options.size.x *= 1.15;
                }
            }
        }.cb,
    },
    .{
        .id = "fists_wide_heavy_rare",
        .name = "Wide Boxing Glove: Broad Hook",
        .description = "+15% heavy attack width",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.getWeaponById("Fists")) |w| w.heavy_attack.projectile_options.size.x *= 1.15;
                }
            }
        }.cb,
    },
    .{
        .id = "goliath_wide_dash_rare",
        .name = "Wide Weight Plate: Dash Sweep",
        .description = "+10% dash attack width",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.getWeaponById("Goliath")) |w| w.dash_attack.projectile_options.size.x *= 1.1;
                }
            }
        }.cb,
    },
    .{
        .id = "fists_wide_dash_rare",
        .name = "Wide Boxing Glove: Broad Cross",
        .description = "+10% dash attack width",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.getWeaponById("Fists")) |w| w.dash_attack.projectile_options.size.x *= 1.1;
                }
            }
        }.cb,
    },
    .{
        .id = "goliath_wide_heavy_epic",
        .name = "Wide Weight Plate: Colossus Slam",
        .description = "+35% heavy attack width",
        .icon = "items/blueberry.png",
        .rarity = .epic,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.getWeaponById("Goliath")) |w| w.heavy_attack.projectile_options.size.x *= 1.35;
                }
            }
        }.cb,
    },
    .{
        .id = "fists_wide_heavy_epic",
        .name = "Wide Boxing Glove: Giant Hook",
        .description = "+35% heavy attack width",
        .icon = "items/blueberry.png",
        .rarity = .epic,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.getWeaponById("Fists")) |w| w.heavy_attack.projectile_options.size.x *= 1.35;
                }
            }
        }.cb,
    },
    .{
        .id = "goliath_wide_dash_epic",
        .name = "Wide Weight Plate: Colossus Dash",
        .description = "+25% dash attack width",
        .icon = "items/blueberry.png",
        .rarity = .epic,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.getWeaponById("Goliath")) |w| w.dash_attack.projectile_options.size.x *= 1.25;
                }
            }
        }.cb,
    },
    .{
        .id = "fists_wide_dash_epic",
        .name = "Wide Boxing Glove: Giant Cross",
        .description = "+25% dash attack width",
        .icon = "items/blueberry.png",
        .rarity = .epic,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.getWeaponById("Fists")) |w| w.dash_attack.projectile_options.size.x *= 1.25;
                }
            }
        }.cb,
    },
    .{
        .id = "goliath_wide_light_legendary",
        .name = "Wide Weight Plate: Titan Sweep",
        .description = "+50% light attack width",
        .icon = "items/blueberry.png",
        .rarity = .legendary,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.getWeaponById("Goliath")) |w| w.light_attack.projectile_options.size.x *= 1.5;
                }
            }
        }.cb,
    },
    .{
        .id = "fists_wide_light_legendary",
        .name = "Wide Boxing Glove: Titan Jab",
        .description = "+50% light attack width",
        .icon = "items/blueberry.png",
        .rarity = .legendary,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                if (attack) |att| {
                    if (att.getWeaponById("Fists")) |w| w.light_attack.projectile_options.size.x *= 1.5;
                }
            }
        }.cb,
    },
};

test "all boons have unique IDs and non-empty metadata" {
    for (all_boons, 0..) |b1, i| {
        try std.testing.expect(b1.id.len > 0);
        try std.testing.expect(b1.name.len > 0);
        for (all_boons[i + 1 ..]) |b2| {
            try std.testing.expect(!std.mem.eql(u8, b1.id, b2.id));
            try std.testing.expect(!std.mem.eql(u8, b1.name, b2.name));
            try std.testing.expect(!b1.eql(b2));
        }
    }
}
