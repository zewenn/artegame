const std = @import("std");
const lm = @import("loom");

pub const Effect = @import("effects/Effect.zig");
pub const EffectType = Effect.EffectType;
pub const EffectCallback = Effect.EffectCallback;
pub const EffectTarget = Effect.EffectTarget;

pub const StatValues = struct {
    health: f32 = 100,
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

    experience: usize = 0,

    pub fn calculateMovementSpeed(self: StatValues) f32 {
        return @max(10, self.movement_speed);
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

effects: ?lm.List(Effect) = null,

pub fn Awake(self: *Self) void {
    if (self.effects == null) {
        self.effects = lm.List(Effect).init(lm.allocators.scene());
    }
}

pub fn Update(self: *Self) void {
    if (lm.time.paused()) return;
    self.tickEffects(lm.time.deltaTime());
}

pub fn End(self: *Self) void {
    if (self.effects) |*effects_list| {
        effects_list.deinit();
        self.effects = null;
    }
}

pub fn init(team: Teams, stats: StatValues) Self {
    return Self{
        .team = team,
        .base = stats,
        .current = stats,
        .max = stats,
        .effects = lm.List(Effect).init(lm.allocators.scene()),
    };
}

pub fn deinit(self: *Self) void {
    self.End();
}

pub fn getEffectsList(self: *Self) *lm.List(Effect) {
    if (self.effects == null) {
        self.effects = lm.List(Effect).init(lm.allocators.scene());
    }
    return &self.effects.?;
}

pub fn hasEffect(self: Self, target: EffectTarget) bool {
    const effects = self.effects orelse return false;
    for (effects.items()) |effect| {
        const matches = switch (target) {
            .id => |id| std.mem.eql(u8, effect.id, id),
            .effect_type => |effect_type| effect.effect_type == effect_type,
        };
        if (matches) return true;
    }
    return false;
}

pub fn getEffect(self: *Self, target: EffectTarget) ?*Effect {
    const effects = &(self.effects orelse return null);
    for (effects.items()) |*effect| {
        const matches = switch (target) {
            .id => |id| std.mem.eql(u8, effect.id, id),
            .effect_type => |effect_type| effect.effect_type == effect_type,
        };
        if (matches) return effect;
    }
    return null;
}

pub fn isStunned(self: Self) bool {
    return self.hasEffect(.{ .effect_type = .stun });
}

pub fn isRooted(self: Self) bool {
    return self.hasEffect(.{ .effect_type = .root });
}

pub fn isSlowed(self: Self) bool {
    return self.hasEffect(.{ .effect_type = .slow });
}

pub fn isSleeping(self: Self) bool {
    return self.hasEffect(.{ .effect_type = .sleep });
}

pub fn isStasis(self: Self) bool {
    return self.hasEffect(.{ .effect_type = .stasis });
}

pub fn isInvulnerable(self: Self) bool {
    return self.isStasis();
}

pub fn isBondOfLifeActive(self: Self) bool {
    return self.hasEffect(.{ .effect_type = .bond_of_life });
}

pub fn canMove(self: Self) bool {
    return !self.isStunned() and !self.isRooted() and !self.isSleeping() and !self.isStasis();
}

pub fn addEffect(self: *Self, effect: Effect) void {
    var new_effect = effect;
    if (new_effect.time_remaining <= 0) {
        new_effect.time_remaining = new_effect.duration;
    }

    const effects = self.getEffectsList();

    for (effects.items()) |*existing| {
        if (std.mem.eql(u8, existing.id, new_effect.id)) {
            if (existing.on_disable) |on_disable| {
                on_disable(self);
            }
            existing.* = new_effect;
            if (existing.on_enable) |on_enable| {
                on_enable(self);
            }
            return;
        }
    }

    effects.append(new_effect) catch |err| {
        std.log.err("Failed to append effect '{s}': {s}", .{ new_effect.id, @errorName(err) });
        return;
    };

    const new_index = effects.len() - 1;
    if (effects.items()[new_index].on_enable) |on_enable| {
        on_enable(self);
    }
}

pub fn removeEffectAtIndex(self: *Self, index: usize) void {
    const effects = &(self.effects orelse return);
    if (index >= effects.len()) return;

    if (effects.items()[index].on_disable) |on_disable| {
        on_disable(self);
    }

    _ = effects.orderedRemove(index);
}

pub fn removeEffect(self: *Self, target: EffectTarget) void {
    const effects = &(self.effects orelse return);
    var effect_index: usize = 0;
    while (effect_index < effects.len()) {
        const matches = switch (target) {
            .id => |id| std.mem.eql(u8, effects.items()[effect_index].id, id),
            .effect_type => |effect_type| effects.items()[effect_index].effect_type == effect_type,
        };
        if (matches) {
            self.removeEffectAtIndex(effect_index);
        } else {
            effect_index += 1;
        }
    }
}

pub fn clearEffects(self: *Self) void {
    const effects = &(self.effects orelse return);
    while (effects.len() > 0) {
        self.removeEffectAtIndex(effects.len() - 1);
    }
}

pub fn applySlow(self: *Self, strength: f32, duration_seconds: f32) void {
    self.addEffect(.{
        .id = "slow",
        .effect_type = .slow,
        .duration = duration_seconds,
        .value = strength,
        .on_enable = struct {
            pub fn onEnable(stats: *Self) void {
                if (stats.getEffect(.{ .id = "slow" })) |effect| {
                    stats.current.movement_speed = @max(10, stats.current.movement_speed - effect.value);
                }
            }
        }.onEnable,
        .on_disable = struct {
            pub fn onDisable(stats: *Self) void {
                if (stats.getEffect(.{ .id = "slow" })) |effect| {
                    stats.current.movement_speed += effect.value;
                }
            }
        }.onDisable,
    });
}

pub fn applyRoot(self: *Self, duration_seconds: f32) void {
    self.addEffect(.{
        .id = "root",
        .effect_type = .root,
        .duration = duration_seconds,
    });
}

pub fn applyStun(self: *Self, duration_seconds: f32) void {
    self.addEffect(.{
        .id = "stun",
        .effect_type = .stun,
        .duration = duration_seconds,
    });
}

pub fn applyStasis(self: *Self, duration_seconds: f32) void {
    self.addEffect(.{
        .id = "stasis",
        .effect_type = .stasis,
        .duration = duration_seconds,
    });
}

pub fn tickEffects(self: *Self, delta_seconds: f32) void {
    const effects = &(self.effects orelse return);
    const length = effects.len();

    for (1..length + 1) |step| {
        const index = length - step;
        const effect = &(effects.items()[index]);
        effect.anim_time += delta_seconds;

        if (effect.on_tick) |tick|
            @call(.auto, tick, .{self});

        if (effect.duration > 0) {
            effect.time_remaining -= delta_seconds;
            if (effect.time_remaining <= 0) {
                self.removeEffectAtIndex(index);
                continue;
            }
        }
    }
}

pub fn calculateDamage(self: Self, defender: Self, damage_type: DamageType, is_crit: bool) f32 {
    return switch (damage_type) {
        .physical => self.current.physical_damage * (1 - defenseToDamageReductionPercent(defender.current.armour)),
        .magic => self.current.magic_damage * (1 - defenseToDamageReductionPercent(defender.current.magic_resist)),
    } * if (is_crit) self.current.crit_damage_multiplier else 1;
}

pub fn defenseToDamageReductionPercent(defense: f32) f32 {
    const clamped_defense = @max(0.0, defense);
    const reduction = 0.3 * std.math.log10(clamped_defense + 1);
    return std.math.clamp(reduction, 0.0, 0.90);
}

test "Stats effect lifecycle with on_enable and on_disable callbacks using lm.List" {
    var stats = Self.init(.player, .{
        .movement_speed = 300,
        .physical_damage = 20,
    });
    defer stats.deinit();

    const CustomBuff = struct {
        pub fn onEnable(target_stats: *Self) void {
            target_stats.current.physical_damage += 15;
        }
        pub fn onDisable(target_stats: *Self) void {
            target_stats.current.physical_damage -= 15;
        }
    };

    stats.addEffect(.{
        .id = "might",
        .effect_type = .custom,
        .duration = 2.0,
        .on_enable = CustomBuff.onEnable,
        .on_disable = CustomBuff.onDisable,
    });

    try std.testing.expect(stats.hasEffect(.{ .id = "might" }));
    try std.testing.expect(stats.hasEffect(.{ .effect_type = .custom }));
    try std.testing.expectEqual(@as(f32, 35), stats.current.physical_damage);

    stats.tickEffects(1.0);
    try std.testing.expect(stats.hasEffect(.{ .id = "might" }));
    try std.testing.expectEqual(@as(f32, 35), stats.current.physical_damage);

    stats.tickEffects(1.0);
    try std.testing.expect(!stats.hasEffect(.{ .id = "might" }));
    try std.testing.expectEqual(@as(f32, 20), stats.current.physical_damage);
}

test "Stats slow directly modifies movement_speed and restores on disable" {
    var stats = Self.init(.player, .{
        .movement_speed = 300,
    });
    defer stats.deinit();

    stats.applySlow(50, 3.0);
    try std.testing.expect(stats.isSlowed());
    try std.testing.expect(stats.hasEffect(.{ .effect_type = .slow }));
    try std.testing.expectEqual(@as(f32, 250), stats.current.movement_speed);

    stats.tickEffects(3.0);
    try std.testing.expect(!stats.isSlowed());
    try std.testing.expectEqual(@as(f32, 300), stats.current.movement_speed);
}

test "Stats crowd control flags and canMove query" {
    var stats = Self.init(.player, .{});
    defer stats.deinit();

    try std.testing.expect(stats.canMove());
    try std.testing.expect(!stats.isStunned());
    try std.testing.expect(!stats.isRooted());

    stats.applyStun(1.5);
    try std.testing.expect(stats.isStunned());
    try std.testing.expect(stats.hasEffect(.{ .effect_type = .stun }));
    try std.testing.expect(!stats.canMove());

    stats.applyRoot(2.5);
    try std.testing.expect(stats.isRooted());
    try std.testing.expect(stats.hasEffect(.{ .effect_type = .root }));
    try std.testing.expect(!stats.canMove());

    stats.tickEffects(1.5);
    try std.testing.expect(!stats.isStunned());
    try std.testing.expect(stats.isRooted());
    try std.testing.expect(!stats.canMove());

    stats.tickEffects(1.0);
    try std.testing.expect(!stats.isRooted());
    try std.testing.expect(stats.canMove());
}

test "Stats re-applying effect refreshes duration without double-stacking stats" {
    var stats = Self.init(.player, .{
        .movement_speed = 300,
    });
    defer stats.deinit();

    stats.applySlow(50, 3.0);
    try std.testing.expectEqual(@as(f32, 250), stats.current.movement_speed);

    stats.applySlow(50, 4.0);
    try std.testing.expectEqual(@as(f32, 250), stats.current.movement_speed);
    try std.testing.expectEqual(@as(usize, 1), stats.effects.?.len());

    stats.tickEffects(4.0);
    try std.testing.expectEqual(@as(f32, 300), stats.current.movement_speed);
    try std.testing.expect(!stats.isSlowed());
}

test "Stats removeEffect with target union (by ID and by Type)" {
    var stats = Self.init(.player, .{});
    defer stats.deinit();

    stats.applyStun(5.0);
    stats.applyRoot(5.0);
    try std.testing.expect(stats.hasEffect(.{ .effect_type = .stun }));
    try std.testing.expect(stats.hasEffect(.{ .effect_type = .root }));

    stats.removeEffect(.{ .effect_type = .stun });
    try std.testing.expect(!stats.hasEffect(.{ .effect_type = .stun }));
    try std.testing.expect(stats.hasEffect(.{ .effect_type = .root }));

    stats.removeEffect(.{ .id = "root" });
    try std.testing.expect(!stats.hasEffect(.{ .id = "root" }));
}

test "Stats effect on_tick periodic callback execution" {
    var stats = Self.init(.player, .{
        .health = 50,
    });
    stats.max.health = 100;
    defer stats.deinit();

    const PeriodicHealing = struct {
        pub fn onTick(target_stats: *Self) void {
            if (target_stats.getEffect(.{ .id = "periodic_heal" })) |effect| {
                target_stats.current.health = @min(target_stats.max.health, target_stats.current.health + effect.value);
            }
        }
    };

    stats.addEffect(.{
        .id = "periodic_heal",
        .effect_type = .regen,
        .duration = 2.0,
        .value = 10,
        .on_tick = PeriodicHealing.onTick,
    });

    stats.tickEffects(1.0);
    try std.testing.expectEqual(@as(f32, 60), stats.current.health);

    stats.tickEffects(1.0);
    try std.testing.expectEqual(@as(f32, 70), stats.current.health);
    try std.testing.expect(!stats.hasEffect(.{ .id = "periodic_heal" }));
}

test "defenseToDamageReductionPercent clamping against negative and extreme values" {
    try std.testing.expectEqual(@as(f32, 0.0), defenseToDamageReductionPercent(-10.0));
    try std.testing.expectEqual(@as(f32, 0.0), defenseToDamageReductionPercent(-1.0));
    try std.testing.expectEqual(@as(f32, 0.0), defenseToDamageReductionPercent(0.0));

    const red10 = defenseToDamageReductionPercent(10.0);
    try std.testing.expect(red10 > 0.0 and red10 < 0.90);

    try std.testing.expectEqual(@as(f32, 0.90), defenseToDamageReductionPercent(100000.0));
}
