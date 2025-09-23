const std = @import("std");
const lm = @import("loom");

pub const StatValues = struct {
    health: f32 = 100,
    mana: f32 = 100,
    stamina: f32 = 100,

    movement_speed: f32 = 330,
    dash_time: f32 = 0.2,
    dash_speed_multiplier: f32 = 3,

    armour: f32 = 0,
    magic_resist: f32 = 0,

    physical_damage: f32 = 20,
    magic_damage: f32 = 0,

    crit_damage_multiplier: f32 = 2,
    crit_chance: f32 = 0,

    attack_speed: f32 = 0.6,

    aggro_range: f32 = 300,
};

pub const Teams = enum {
    player,
    neutral,
    enemy,
};

pub const DamageType = enum {
    magic,
    physical,
};

const Self = @This();

team: Teams = .neutral,

max: StatValues = .{},
base: StatValues = .{},
current: StatValues = .{},

pub fn calculateDamage(self: Self, defender: Self, damage_type: DamageType, is_crit: bool) f32 {
    return switch (damage_type) {
        .physical => self.current.physical_damage * (1 - defenseToDamageReductionPercent(defender.current.armour)),
        .magic => self.current.magic_damage * (1 - defenseToDamageReductionPercent(defender.current.magic_damage)),
    } * if (is_crit) self.current.crit_damage_multiplier else 1;
}

pub fn defenseToDamageReductionPercent(defense: f32) f32 {
    return 0.3 * std.math.log10(defense + 1);
}
