const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const Spell = @import("../../components/Weapons/Spell.zig");
const spells = @import("../../components/Weapons/spells.zig");
const Boon = @import("Boon.zig");

pub const BoonPool = @import("BoonPool.zig");
pub const BoonCategory = @import("BoonCategory.zig");

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
    const equipped_spell = attack.equipped_spells[1] orelse return true;
    if (std.mem.eql(u8, equipped_spell.id, "Root") and equipped_spell.level >= 2) return false;
    return true;
}

fn canOfferAshwaganda2(_: Stats, attack: Attack) bool {
    const equipped_spell = attack.equipped_spells[1] orelse return true;
    if (std.mem.eql(u8, equipped_spell.id, "Root") and equipped_spell.level >= 2) return false;
    return true;
}

fn canOfferAshwaganda3(_: Stats, attack: Attack) bool {
    const equipped_spell = attack.equipped_spells[1] orelse return true;
    if (std.mem.eql(u8, equipped_spell.id, "Root") and equipped_spell.level >= 4) return false;
    return true;
}

fn canOfferVitaminMix1(_: Stats, attack: Attack) bool {
    const equipped_spell = attack.equipped_spells[0] orelse return true;
    if (std.mem.eql(u8, equipped_spell.id, "Heal") and equipped_spell.level >= 5) return false;
    return true;
}

fn canOfferVitaminMix2(_: Stats, attack: Attack) bool {
    const equipped_spell = attack.equipped_spells[0] orelse return true;
    if (std.mem.eql(u8, equipped_spell.id, "Heal") and equipped_spell.level >= 10) return false;
    return true;
}

fn canOfferVitaminMix3(_: Stats, attack: Attack) bool {
    const equipped_spell = attack.equipped_spells[0] orelse return true;
    if (std.mem.eql(u8, equipped_spell.id, "Heal") and equipped_spell.level >= 25) return false;
    return true;
}

fn canOfferCreatine1(_: Stats, attack: Attack) bool {
    const equipped_spell = attack.equipped_spells[0] orelse return true;
    if (std.mem.eql(u8, equipped_spell.id, "Goliath") and equipped_spell.level >= 1) return false;
    return true;
}

fn canOfferCreatine2(_: Stats, attack: Attack) bool {
    const equipped_spell = attack.equipped_spells[0] orelse return true;
    if (std.mem.eql(u8, equipped_spell.id, "Goliath") and equipped_spell.level >= 2) return false;
    return true;
}

fn canOfferCreatine3(_: Stats, attack: Attack) bool {
    const equipped_spell = attack.equipped_spells[0] orelse return true;
    if (std.mem.eql(u8, equipped_spell.id, "Goliath") and equipped_spell.level >= 5) return false;
    return true;
}

fn canOfferPreWorkout1(_: Stats, attack: Attack) bool {
    const equipped_spell = attack.equipped_spells[1] orelse return true;
    if (std.mem.eql(u8, equipped_spell.id, "Haste") and equipped_spell.level >= 6) return false;
    return true;
}

fn canOfferPreWorkout2(_: Stats, attack: Attack) bool {
    const equipped_spell = attack.equipped_spells[1] orelse return true;
    if (std.mem.eql(u8, equipped_spell.id, "Haste") and equipped_spell.level >= 9) return false;
    return true;
}

pub const plates_width_speed_boons: []const Boon = &.{
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
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Goliath")) |weapon| {
                    weapon.light_attack.projectile_options.size.x *= 1.25;
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
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Goliath")) |weapon| {
                    weapon.heavy_attack.projectile_options.size.x *= 1.15;
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
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Goliath")) |weapon| {
                    weapon.dash_attack.projectile_options.size.x *= 1.1;
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
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Goliath")) |weapon| {
                    weapon.heavy_attack.projectile_options.size.x *= 1.35;
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
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Goliath")) |weapon| {
                    weapon.dash_attack.projectile_options.size.x *= 1.25;
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
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Goliath")) |weapon| {
                    weapon.light_attack.projectile_options.size.x *= 1.5;
                }
            }
        }.cb,
    },
    .{
        .id = "goliath_speed_light_normal",
        .name = "Aerodynamic Plate: Fast Spin",
        .description = "+20% light attack projectile speed",
        .icon = "items/blueberry.png",
        .rarity = .normal,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Goliath")) |weapon| {
                    weapon.light_attack.projectile_options.speed *= 1.20;
                }
            }
        }.cb,
    },
    .{
        .id = "goliath_speed_heavy_normal",
        .name = "Aerodynamic Plate: Swift Slam",
        .description = "+20% heavy attack projectile speed",
        .icon = "items/blueberry.png",
        .rarity = .normal,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Goliath")) |weapon| {
                    weapon.heavy_attack.projectile_options.speed *= 1.20;
                }
            }
        }.cb,
    },
    .{
        .id = "goliath_speed_dash_rare",
        .name = "Aerodynamic Plate: Ram Velocity",
        .description = "+25% dash attack projectile speed",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Goliath")) |weapon| {
                    weapon.dash_attack.projectile_options.speed *= 1.25;
                }
            }
        }.cb,
    },
    .{
        .id = "goliath_speed_all_epic",
        .name = "Vortex Weight Plate: Hyper Velocity",
        .description = "+35% all plate attack projectile speed",
        .icon = "items/blueberry.png",
        .rarity = .epic,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Goliath")) |weapon| {
                    weapon.light_attack.projectile_options.speed *= 1.35;
                    weapon.heavy_attack.projectile_options.speed *= 1.35;
                    weapon.dash_attack.projectile_options.speed *= 1.35;
                }
            }
        }.cb,
    },
};

pub const plates_damage_boons: []const Boon = &.{
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
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Goliath")) |weapon| {
                    weapon.light_attack.projectile_options.damage *= 1.1;
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
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Goliath")) |weapon| {
                    weapon.heavy_attack.projectile_options.damage *= 1.1;
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
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Goliath")) |weapon| {
                    weapon.dash_attack.projectile_options.damage *= 1.1;
                }
            }
        }.cb,
    },
    .{
        .id = "goliath_damage_light_rare",
        .name = "Heavyweight Plate: Crushing Grip",
        .description = "+25% light attack damage",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Goliath")) |weapon| {
                    weapon.light_attack.projectile_options.damage *= 1.25;
                }
            }
        }.cb,
    },
    .{
        .id = "goliath_damage_heavy_rare",
        .name = "Heavyweight Plate: Brutal Slam",
        .description = "+25% heavy attack damage",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Goliath")) |weapon| {
                    weapon.heavy_attack.projectile_options.damage *= 1.25;
                }
            }
        }.cb,
    },
    .{
        .id = "goliath_damage_dash_rare",
        .name = "Heavyweight Plate: Ramming Force",
        .description = "+25% dash attack damage",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Goliath")) |weapon| {
                    weapon.dash_attack.projectile_options.damage *= 1.25;
                }
            }
        }.cb,
    },
    .{
        .id = "goliath_damage_heavy_epic",
        .name = "Iron Fortress: Cataclysmic Slam",
        .description = "+50% heavy attack damage",
        .icon = "items/blueberry.png",
        .rarity = .epic,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Goliath")) |weapon| {
                    weapon.heavy_attack.projectile_options.damage *= 1.50;
                }
            }
        }.cb,
    },
    .{
        .id = "goliath_damage_colossus_legendary",
        .name = "Colossus of Iron: Maximum Overload",
        .description = "+75% all plate attack damage",
        .icon = "items/blueberry.png",
        .rarity = .legendary,
        .boon_type = .weapon,
        .condition = hasGoliathWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Goliath")) |weapon| {
                    weapon.light_attack.projectile_options.damage *= 1.75;
                    weapon.heavy_attack.projectile_options.damage *= 1.75;
                    weapon.dash_attack.projectile_options.damage *= 1.75;
                }
            }
        }.cb,
    },
};

pub const gloves_width_speed_boons: []const Boon = &.{
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
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Fists")) |weapon| {
                    weapon.light_attack.projectile_options.size.x *= 1.25;
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
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Fists")) |weapon| {
                    weapon.heavy_attack.projectile_options.size.x *= 1.15;
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
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Fists")) |weapon| {
                    weapon.dash_attack.projectile_options.size.x *= 1.1;
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
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Fists")) |weapon| {
                    weapon.heavy_attack.projectile_options.size.x *= 1.35;
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
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Fists")) |weapon| {
                    weapon.dash_attack.projectile_options.size.x *= 1.25;
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
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Fists")) |weapon| {
                    weapon.light_attack.projectile_options.size.x *= 1.5;
                }
            }
        }.cb,
    },
    .{
        .id = "fists_speed_jab_normal",
        .name = "Speed Bag Training: Rapid Jab",
        .description = "+20% light attack projectile speed",
        .icon = "items/blueberry.png",
        .rarity = .normal,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Fists")) |weapon| {
                    weapon.light_attack.projectile_options.speed *= 1.20;
                }
            }
        }.cb,
    },
    .{
        .id = "fists_speed_hook_normal",
        .name = "Speed Bag Training: Whiplash Hook",
        .description = "+20% heavy attack projectile speed",
        .icon = "items/blueberry.png",
        .rarity = .normal,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Fists")) |weapon| {
                    weapon.heavy_attack.projectile_options.speed *= 1.20;
                }
            }
        }.cb,
    },
    .{
        .id = "fists_speed_cross_rare",
        .name = "Lightning Step: Flash Cross",
        .description = "+25% dash attack projectile speed",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Fists")) |weapon| {
                    weapon.dash_attack.projectile_options.speed *= 1.25;
                }
            }
        }.cb,
    },
    .{
        .id = "fists_speed_all_epic",
        .name = "Mach Punch: Flurry Velocity",
        .description = "+35% all boxing glove projectile speed",
        .icon = "items/blueberry.png",
        .rarity = .epic,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Fists")) |weapon| {
                    weapon.light_attack.projectile_options.speed *= 1.35;
                    weapon.heavy_attack.projectile_options.speed *= 1.35;
                    weapon.dash_attack.projectile_options.speed *= 1.35;
                }
            }
        }.cb,
    },
};

pub const gloves_damage_boons: []const Boon = &.{
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
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Fists")) |weapon| {
                    weapon.light_attack.projectile_options.damage *= 1.1;
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
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Fists")) |weapon| {
                    weapon.heavy_attack.projectile_options.damage *= 1.1;
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
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Fists")) |weapon| {
                    weapon.dash_attack.projectile_options.damage *= 1.1;
                }
            }
        }.cb,
    },
    .{
        .id = "fists_damage_light_rare",
        .name = "Reinforced Leather: Lead Jab",
        .description = "+25% light attack damage",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Fists")) |weapon| {
                    weapon.light_attack.projectile_options.damage *= 1.25;
                }
            }
        }.cb,
    },
    .{
        .id = "fists_damage_heavy_rare",
        .name = "Reinforced Leather: Sledgehammer Hook",
        .description = "+25% heavy attack damage",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Fists")) |weapon| {
                    weapon.heavy_attack.projectile_options.damage *= 1.25;
                }
            }
        }.cb,
    },
    .{
        .id = "fists_damage_dash_rare",
        .name = "Reinforced Leather: Bullet Cross",
        .description = "+25% dash attack damage",
        .icon = "items/blueberry.png",
        .rarity = .rare,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Fists")) |weapon| {
                    weapon.dash_attack.projectile_options.damage *= 1.25;
                }
            }
        }.cb,
    },
    .{
        .id = "fists_damage_heavy_epic",
        .name = "Knockout King: Thunderous Haymaker",
        .description = "+50% heavy attack damage",
        .icon = "items/blueberry.png",
        .rarity = .epic,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Fists")) |weapon| {
                    weapon.heavy_attack.projectile_options.damage *= 1.50;
                }
            }
        }.cb,
    },
    .{
        .id = "fists_damage_champion_legendary",
        .name = "Undisputed Champion: Golden Gloves",
        .description = "+75% all boxing glove damage",
        .icon = "items/blueberry.png",
        .rarity = .legendary,
        .boon_type = .weapon,
        .condition = hasFistsWeapon,
        .callback = struct {
            pub fn cb(_: *Stats, attack: ?*Attack) void {
                const attack_component = attack orelse return;
                if (attack_component.getWeaponById("Fists")) |weapon| {
                    weapon.light_attack.projectile_options.damage *= 1.75;
                    weapon.heavy_attack.projectile_options.damage *= 1.75;
                    weapon.dash_attack.projectile_options.damage *= 1.75;
                }
            }
        }.cb,
    },
};

pub const new_supplements_boons: []const Boon = &.{
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
                const attack_component = attack orelse return;
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
                const attack_component = attack orelse return;
                var spell_instance = spells.heal;
                spell_instance.level = 5;
                attack_component.equipped_spells[0] = spell_instance;
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
                const attack_component = attack orelse return;
                var spell_instance = spells.goliath;
                spell_instance.level = 1;
                attack_component.equipped_spells[0] = spell_instance;
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
                const attack_component = attack orelse return;
                var spell_instance = spells.haste;
                spell_instance.level = 6;
                attack_component.equipped_spells[1] = spell_instance;
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
                const attack_component = attack orelse return;
                var spell_instance = spells.root;
                spell_instance.level = 2;
                attack_component.equipped_spells[1] = spell_instance;
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
                const attack_component = attack orelse return;
                var spell_instance = spells.heal;
                spell_instance.level = 10;
                attack_component.equipped_spells[0] = spell_instance;
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
                const attack_component = attack orelse return;
                var spell_instance = spells.goliath;
                spell_instance.level = 2;
                attack_component.equipped_spells[0] = spell_instance;
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
                const attack_component = attack orelse return;
                var spell_instance = spells.haste;
                spell_instance.level = 9;
                attack_component.equipped_spells[1] = spell_instance;
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
                const attack_component = attack orelse return;
                var spell_instance = spells.root;
                spell_instance.level = 4;
                attack_component.equipped_spells[1] = spell_instance;
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
                const attack_component = attack orelse return;
                var spell_instance = spells.goliath;
                spell_instance.level = 5;
                attack_component.equipped_spells[0] = spell_instance;
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
                const attack_component = attack orelse return;
                var spell_instance = spells.heal;
                spell_instance.level = 25;
                attack_component.equipped_spells[0] = spell_instance;
            }
        }.cb,
    },
};

pub const supplement_upgrades_boons: []const Boon = &.{
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
                const attack_component = attack orelse return;
                if (attack_component.equipped_spells[0]) |*spell_slot| spell_slot.level += 1;
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
                const attack_component = attack orelse return;
                if (attack_component.equipped_spells[1]) |*spell_slot| spell_slot.level += 1;
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
                const attack_component = attack orelse return;
                if (attack_component.equipped_spells[0]) |*spell_slot| spell_slot.level += 2;
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
                const attack_component = attack orelse return;
                if (attack_component.equipped_spells[1]) |*spell_slot| spell_slot.level += 2;
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
                const attack_component = attack orelse return;
                if (attack_component.equipped_spells[0]) |*spell_slot| spell_slot.level += 3;
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
                const attack_component = attack orelse return;
                if (attack_component.equipped_spells[1]) |*spell_slot| spell_slot.level += 3;
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
                const attack_component = attack orelse return;
                if (attack_component.equipped_spells[0]) |*spell_slot| spell_slot.level += 5;
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
                const attack_component = attack orelse return;
                if (attack_component.equipped_spells[1]) |*spell_slot| spell_slot.level += 5;
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
                const attack_component = attack orelse return;
                if (attack_component.equipped_spells[0]) |*spell_slot| spell_slot.level += 7;
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
                const attack_component = attack orelse return;
                if (attack_component.equipped_spells[1]) |*spell_slot| spell_slot.level += 7;
            }
        }.cb,
    },
};

pub const vitality_boons: []const Boon = &.{
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
        .id = "energy_gel_normal",
        .name = "Energy Gel",
        .description = "+25 max stamina",
        .icon = "items/strawberry.png",
        .rarity = .normal,
        .boon_type = .stat,
        .callback = struct {
            pub fn cb(stats: *Stats, _: ?*Attack) void {
                stats.max.stamina += 25;
                stats.current.stamina += 25;
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
        .id = "caffeine_powder_rare",
        .name = "Pure Caffeine Powder",
        .description = "+50 max stamina\n+0.2 attack speed",
        .icon = "items/strawberry.png",
        .rarity = .rare,
        .boon_type = .stat,
        .callback = struct {
            pub fn cb(stats: *Stats, _: ?*Attack) void {
                stats.max.stamina += 50;
                stats.current.stamina += 50;
                stats.current.attack_speed += 0.2;
                stats.max.attack_speed += 0.2;
            }
        }.cb,
    },
    .{
        .id = "focus_supplement_rare",
        .name = "Focus Formula",
        .description = "+10% critical hit chance",
        .icon = "items/strawberry.png",
        .rarity = .rare,
        .boon_type = .stat,
        .callback = struct {
            pub fn cb(stats: *Stats, _: ?*Attack) void {
                stats.current.crit_chance += 0.10;
                stats.max.crit_chance += 0.10;
            }
        }.cb,
    },
    .{
        .id = "electrolytes_rare",
        .name = "Electrolyte Surge",
        .description = "+50% critical damage multiplier",
        .icon = "items/strawberry.png",
        .rarity = .rare,
        .boon_type = .stat,
        .callback = struct {
            pub fn cb(stats: *Stats, _: ?*Attack) void {
                stats.current.crit_damage_multiplier += 0.50;
                stats.max.crit_damage_multiplier += 0.50;
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
        .id = "nootropic_blend_epic",
        .name = "Nootropic Mind Matrix",
        .description = "+20% critical hit chance",
        .icon = "items/strawberry.png",
        .rarity = .epic,
        .boon_type = .stat,
        .callback = struct {
            pub fn cb(stats: *Stats, _: ?*Attack) void {
                stats.current.crit_chance += 0.20;
                stats.max.crit_chance += 0.20;
            }
        }.cb,
    },
    .{
        .id = "adrenochrome_epic",
        .name = "Adrenaline Infusion",
        .description = "+100% critical damage multiplier",
        .icon = "items/strawberry.png",
        .rarity = .epic,
        .boon_type = .stat,
        .callback = struct {
            pub fn cb(stats: *Stats, _: ?*Attack) void {
                stats.current.crit_damage_multiplier += 1.00;
                stats.max.crit_damage_multiplier += 1.00;
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
        .id = "apex_focus_legendary",
        .name = "Apex Flow State",
        .description = "+30% critical hit chance",
        .icon = "items/strawberry.png",
        .rarity = .legendary,
        .boon_type = .stat,
        .callback = struct {
            pub fn cb(stats: *Stats, _: ?*Attack) void {
                stats.current.crit_chance += 0.30;
                stats.max.crit_chance += 0.30;
            }
        }.cb,
    },
};

pub const all_boons: []const Boon = plates_width_speed_boons ++
    plates_damage_boons ++
    gloves_width_speed_boons ++
    gloves_damage_boons ++
    new_supplements_boons ++
    supplement_upgrades_boons ++
    vitality_boons;

test "all boons have unique IDs and non-empty metadata" {
    for (all_boons, 0..) |boon_first, outer_index| {
        try std.testing.expect(boon_first.id.len > 0);
        try std.testing.expect(boon_first.name.len > 0);
        for (all_boons[outer_index + 1 ..]) |boon_second| {
            try std.testing.expect(!std.mem.eql(u8, boon_first.id, boon_second.id));
            try std.testing.expect(!std.mem.eql(u8, boon_first.name, boon_second.name));
            try std.testing.expect(!boon_first.eql(boon_second));
        }
    }
}
