const std = @import("std");
const lm = @import("loom");

const Stats = @import("../Stats.zig");
const Spell = @import("Spell.zig");

const Projectile = @import("../../prefabs/Projectile.zig").Projectile;

pub const heal: Spell = Spell{
    .id = "Heal",
    .cooldown = 8,
    .slot = .left,
    .icon = "ui/heal_icon.png",
    .cast_fn = struct {
        fn onTick(s: *Stats) void {
            if (s.getEffect(.{ .id = "heal_regen" })) |e| {
                s.current.health = @min(s.max.health, s.current.health + e.value * lm.time.deltaTime());
            }
        }

        pub fn callback(target: *lm.Entity, level: u32) !void {
            const stats = target.getComponent(Stats) orelse return;
            const regen_val = 20 * lm.tof32(level);
            stats.addEffect(.{
                .id = "heal_regen",
                .effect_type = .regen,
                .duration = 2.0,
                .value = regen_val,
                .on_tick = onTick,
                .visual = .{
                    .frames = &.{
                        "effects/heal_effect_0.png",
                        "effects/heal_effect_1.png",
                    },
                    .frame_duration = 0.1,
                    .offset = .init(0, 0),
                    .scale = .init(64, 64),
                    .icon = "ui/heal_icon.png",
                },
            });
        }
    }.callback,
};

pub const root: Spell = Spell{
    .id = "Root",
    .cooldown = 3,
    .slot = .right,
    .icon = "ui/sleep_icon.png",
    .cast_fn = struct {
        pub fn callback(target: *lm.Entity, level: u32) !void {
            const transform = target.getComponent(lm.Transform) orelse return;

            for (@as([]const f32, &.{ -180, -90, 0, 90 })) |value| {
                const vec = lm.Vec2(1, 0)
                    .rotate(std.math.degreesToRadians(value))
                    .add(lm.vec3ToVec2(transform.position));

                const projectile = try Projectile(.{
                    .target_team = .enemy,
                    .size = .init(512, 64),
                    .onhit_effect = .root,
                    .onhit_duration = lm.tof32(level + 1),
                    .passtrough = true,
                    .damage = 0,

                    .target_position = vec,
                    .start_position = lm.vec3ToVec2(transform.position),
                });

                try lm.summoning.entity(projectile);
            }
        }
    }.callback,
};

pub const goliath: Spell = Spell{
    .id = "Goliath",
    .cooldown = 8,
    .slot = .left,
    .icon = "ui/goliath_icon.png",
    .cast_fn = struct {
        fn onEnable(s: *Stats) void {
            if (s.getEffect(.{ .id = "goliath" })) |e| {
                s.max.health += e.value;
                s.current.health += e.value;
                s.current.physical_damage += e.secondary_value;
            }
        }

        fn onDisable(s: *Stats) void {
            if (s.getEffect(.{ .id = "goliath" })) |e| {
                s.max.health = @max(1, s.max.health - e.value);
                s.current.health = @min(s.current.health, s.max.health);
                s.current.physical_damage = @max(0, s.current.physical_damage - e.secondary_value);
            }
        }

        pub fn callback(target: *lm.Entity, level: u32) !void {
            const stats = target.getComponent(Stats) orelse return;
            const hp_boost = 50 * lm.tof32(level);
            const dmg_boost = 15 * lm.tof32(level);
            stats.addEffect(.{
                .id = "goliath",
                .effect_type = .goliath,
                .duration = 6.0,
                .value = hp_boost,
                .secondary_value = dmg_boost,
                .on_enable = onEnable,
                .on_disable = onDisable,
                .visual = .{
                    .icon = "ui/goliath_icon.png",
                },
            });
        }
    }.callback,
};

pub const haste: Spell = Spell{
    .id = "Haste",
    .cooldown = 6,
    .slot = .right,
    .icon = "ui/haste_icon.png",
    .cast_fn = struct {
        fn onEnable(s: *Stats) void {
            if (s.getEffect(.{ .id = "haste" })) |e| {
                s.current.movement_speed += e.value;
                s.current.attack_speed += e.secondary_value;
            }
        }

        fn onDisable(s: *Stats) void {
            if (s.getEffect(.{ .id = "haste" })) |e| {
                s.current.movement_speed = @max(10, s.current.movement_speed - e.value);
                s.current.attack_speed = @max(0.1, s.current.attack_speed - e.secondary_value);
            }
        }

        pub fn callback(target: *lm.Entity, level: u32) !void {
            const stats = target.getComponent(Stats) orelse return;
            const speed_boost = 60 * lm.tof32(level);
            const atk_speed_boost = 0.3 * lm.tof32(level);
            stats.addEffect(.{
                .id = "haste",
                .effect_type = .haste,
                .duration = 5.0,
                .value = speed_boost,
                .secondary_value = atk_speed_boost,
                .on_enable = onEnable,
                .on_disable = onDisable,
                .visual = .{
                    .icon = "ui/haste_icon.png",
                },
            });
        }
    }.callback,
};

pub fn getById(id: []const u8) ?Spell {
    if (std.ascii.eqlIgnoreCase(id, "Heal")) return heal;
    if (std.ascii.eqlIgnoreCase(id, "Root")) return root;
    if (std.ascii.eqlIgnoreCase(id, "Goliath")) return goliath;
    if (std.ascii.eqlIgnoreCase(id, "Haste")) return haste;
    return null;
}

test "spells getById resolves known spells" {
    try std.testing.expect(getById("Heal") != null);
    try std.testing.expect(getById("Root") != null);
    try std.testing.expect(getById("Goliath") != null);
    try std.testing.expect(getById("Haste") != null);
    try std.testing.expect(getById("Unknown") == null);
}

