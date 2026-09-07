const std = @import("std");
const lm = @import("loom");

const projectiles = @import("../../prefabs/Projectile.zig");
const ProjectileOptions = projectiles.Options;
const Projectile = projectiles.Projectile;

const Stats = @import("../Stats.zig");

pub const Attack = struct {
    shooting_degrees: []const f32 = &.{0},
    projectile_options: ProjectileOptions = .{},
};

pub const SerializedAttack = struct {
    shooting_degrees: []const f32 = &.{0},
    lifetime: f32 = 1,
    speed: f32 = 330,
    size_x: f32 = 64,
    size_y: f32 = 64,
    passtrough: bool = false,
    is_crit: bool = false,
    damage_type: Stats.DamageType = .physical,
    damage: f32 = 1,
    knockback_strength: f32 = 0,
    knockback_duration: f32 = 0,
    onhit_effect: ?projectiles.OnHitEffect = null,
    onhit_duration: f32 = 0,
    onhit_strength: f32 = 0,
    override_sprite: ?[]const u8 = null,

    pub fn fromAttack(att: Attack) SerializedAttack {
        const opt = att.projectile_options;
        return .{
            .shooting_degrees = att.shooting_degrees,
            .lifetime = opt.lifetime,
            .speed = opt.speed,
            .size_x = opt.size.x,
            .size_y = opt.size.y,
            .passtrough = opt.passtrough,
            .is_crit = opt.is_crit,
            .damage_type = opt.damage_type,
            .damage = opt.damage,
            .knockback_strength = opt.knockback_strength,
            .knockback_duration = opt.knockback_duration,
            .onhit_effect = opt.onhit_effect,
            .onhit_duration = opt.onhit_duration,
            .onhit_strength = opt.onhit_strength,
            .override_sprite = opt.override_sprite,
        };
    }

    pub fn toAttack(self: SerializedAttack) Attack {
        var opt = ProjectileOptions{};
        opt.lifetime = self.lifetime;
        opt.speed = self.speed;
        opt.size = .init(self.size_x, self.size_y);
        opt.passtrough = self.passtrough;
        opt.is_crit = self.is_crit;
        opt.damage_type = self.damage_type;
        opt.damage = self.damage;
        opt.knockback_strength = self.knockback_strength;
        opt.knockback_duration = self.knockback_duration;
        opt.onhit_effect = self.onhit_effect;
        opt.onhit_duration = self.onhit_duration;
        opt.onhit_strength = self.onhit_strength;
        opt.override_sprite = self.override_sprite;
        return .{
            .shooting_degrees = self.shooting_degrees,
            .projectile_options = opt,
        };
    }
};

pub const SerializedWeapon = struct {
    id: []const u8 = "",
    type: WeaponType = .close,
    sprite_left: []const u8 = "ui/empty_icon.png",
    sprite_right: []const u8 = "ui/empty_icon.png",
    light_attack: SerializedAttack = .{},
    heavy_attack: SerializedAttack = .{},
    dash_attack: SerializedAttack = .{},
};

pub const WeaponType = enum {
    close,
    wide,
};

const Self = @This();

id: []const u8,

light_attack: Attack = .{},
heavy_attack: Attack = .{},
dash_attack: Attack = .{},

sprite_left: []const u8 = "ui/empty_icon.png",
sprite_right: []const u8 = "ui/empty_icon.png",

type: WeaponType = .close,

pub fn jsonStringify(self: @This(), jw: anytype) !void {
    const sw = SerializedWeapon{
        .id = self.id,
        .type = self.type,
        .sprite_left = self.sprite_left,
        .sprite_right = self.sprite_right,
        .light_attack = SerializedAttack.fromAttack(self.light_attack),
        .heavy_attack = SerializedAttack.fromAttack(self.heavy_attack),
        .dash_attack = SerializedAttack.fromAttack(self.dash_attack),
    };
    try jw.write(sw);
}

pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
    const sw = try std.json.innerParse(SerializedWeapon, allocator, source, options);
    return @This(){
        .id = sw.id,
        .type = sw.type,
        .sprite_left = sw.sprite_left,
        .sprite_right = sw.sprite_right,
        .light_attack = sw.light_attack.toAttack(),
        .heavy_attack = sw.heavy_attack.toAttack(),
        .dash_attack = sw.dash_attack.toAttack(),
    };
}

pub fn doAttack(attack: Attack, position: lm.Vector2, target: lm.Vector2, shooter_stats: Stats) !void {
    const diff = target.subtract(position);
    const angle = switch (diff.length() > 0.001) {
        true => std.math.atan2(diff.y, diff.x),
        false => 0.0,
    };

    for (attack.shooting_degrees) |degree_offset| {
        const new_angle = std.math.degreesToRadians(degree_offset) + angle;
        const target_vector = lm.Vec2(1, 0).rotate(new_angle);

        const options = attack.projectile_options;

        try lm.summoning.entity(try Projectile(.{
            .start_position = position,
            .target_position = target_vector.add(position),

            .target_team = switch (shooter_stats.team) {
                .enemy => .player,
                else => .enemy,
            },

            .shooter_stats = shooter_stats,

            .speed = options.speed,

            .damage = options.damage,
            .damage_type = options.damage_type,
            .passtrough = options.passtrough,
            .lifetime = options.lifetime,
            .size = options.size,
            .override_sprite = options.override_sprite,

            .onhit_effect = options.onhit_effect,
            .onhit_duration = options.onhit_duration,
            .onhit_strength = options.onhit_strength,

            .knockback_duration = options.knockback_duration,
            .knockback_strength = options.knockback_strength,
        }));
    }
}

pub fn lightAttack(self: *Self, position: lm.Vector2, target: lm.Vector2, shooter_stats: Stats) !void {
    try doAttack(self.light_attack, position, target, shooter_stats);
}

pub fn heavyAttack(self: *Self, position: lm.Vector2, target: lm.Vector2, shooter_stats: Stats) !void {
    try doAttack(self.heavy_attack, position, target, shooter_stats);
}

pub fn dashAttack(self: *Self, position: lm.Vector2, target: lm.Vector2, shooter_stats: Stats) !void {
    try doAttack(self.dash_attack, position, target, shooter_stats);
}

test "Weapon serialization and deserialization roundtrip" {
    const testing = std.testing;
    const alloc = testing.allocator;

    const original = Self{
        .id = "TestGoliath",
        .type = .wide,
        .sprite_left = "weapons/plates_1.png",
        .sprite_right = "weapons/plates_0.png",
        .light_attack = .{
            .shooting_degrees = &.{ -5, 0, 5 },
            .projectile_options = .{
                .damage = 42.5,
                .speed = 500,
                .passtrough = true,
                .knockback_strength = 2.5,
            },
        },
    };

    const weapons_arr: [2]?Self = [_]?Self{ original, null };
    const json_str = try std.fmt.allocPrint(alloc, "{f}", .{std.json.fmt(weapons_arr, .{})});
    defer alloc.free(json_str);

    var parsed = try std.json.parseFromSlice([2]?Self, alloc, json_str, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const loaded = parsed.value[0].?;
    try testing.expectEqualStrings("TestGoliath", loaded.id);
    try testing.expectEqual(WeaponType.wide, loaded.type);
    try testing.expectEqual(@as(f32, 42.5), loaded.light_attack.projectile_options.damage);
    try testing.expectEqual(@as(f32, 500), loaded.light_attack.projectile_options.speed);
    try testing.expect(loaded.light_attack.projectile_options.passtrough);
    try testing.expectEqual(@as(f32, 2.5), loaded.light_attack.projectile_options.knockback_strength);
    try testing.expectEqual(@as(usize, 3), loaded.light_attack.shooting_degrees.len);
    try testing.expectEqual(@as(f32, -5), loaded.light_attack.shooting_degrees[0]);
    try testing.expect(parsed.value[1] == null);
}

