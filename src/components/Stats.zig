const std = @import("std");
const lm = @import("loom");

pub const StatValues = struct {
    health: f32 = 100,
    mana: f32 = 100,
    stamina: f32 = 100,

    movement_speed: f32 = 330,

    armour: f32 = 0,
    magic_resist: f32 = 0,

    physical_damage: f32 = 20,
    magic_damage: f32 = 0,

    crit_damage_multiplier: f32 = 2,
    crit_chance: f32 = 0,

    attack_speed: f32 = 0.6,
};

max: StatValues = .{},
base: StatValues = .{},
current: StatValues = .{},
