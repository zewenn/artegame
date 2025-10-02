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

    slow_movement_speed_decrease: f32 = 0,
    rooted: bool = false,
    stunned: bool = false,

    regeneration_amount: f32 = 0,

    timer_slow_remaining: f32 = 0,
    timer_root_remaining: f32 = 0,
    timer_stun_remaining: f32 = 0,
    timer_regen_remaining: f32 = 0,

    pub fn calculateMovementSpeed(self: StatValues) f32 {
        return @max(10, self.movement_speed - self.slow_movement_speed_decrease);
    }
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

pub fn Update(self: *Self) void {
    if (lm.time.paused()) return;

    self.current.health += self.current.regeneration_amount * lm.time.deltaTime();

    self.current.timer_slow_remaining -= lm.time.deltaTime();
    self.current.timer_root_remaining -= lm.time.deltaTime();
    self.current.timer_stun_remaining -= lm.time.deltaTime();
    self.current.timer_regen_remaining -= lm.time.deltaTime();

    if (self.current.timer_slow_remaining < 0) self.current.timer_slow_remaining = 0;
    if (self.current.timer_root_remaining < 0) self.current.timer_root_remaining = 0;
    if (self.current.timer_stun_remaining < 0) self.current.timer_stun_remaining = 0;
    if (self.current.timer_regen_remaining < 0) self.current.timer_regen_remaining = 0;

    if (self.current.timer_slow_remaining == 0) self.current.slow_movement_speed_decrease = 0;
    if (self.current.timer_root_remaining == 0) self.current.rooted = false;
    if (self.current.timer_stun_remaining == 0) self.current.stunned = false;
    if (self.current.timer_regen_remaining == 0) self.current.regeneration_amount = 0;
}

pub fn calculateDamage(self: Self, defender: Self, damage_type: DamageType, is_crit: bool) f32 {
    return switch (damage_type) {
        .physical => self.current.physical_damage * (1 - defenseToDamageReductionPercent(defender.current.armour)),
        .magic => self.current.magic_damage * (1 - defenseToDamageReductionPercent(defender.current.magic_damage)),
    } * if (is_crit) self.current.crit_damage_multiplier else 1;
}

pub fn defenseToDamageReductionPercent(defense: f32) f32 {
    return 0.3 * std.math.log10(defense + 1);
}

pub fn applySlow(self: *Self, strength: f32, duration: f32) void {
    if (self.current.slow_movement_speed_decrease < strength)
        self.current.slow_movement_speed_decrease = strength;
    self.current.timer_slow_remaining = duration;
}

pub fn applyRoot(self: *Self, duration: f32) void {
    self.current.timer_root_remaining = duration;
    self.current.rooted = true;
}

pub fn applyStun(self: *Self, duration: f32) void {
    self.current.timer_stun_remaining = duration;
    self.current.stunned = true;
}

pub fn canMove(self: *Self) bool {
    return !(self.current.rooted or self.current.stunned);
}
