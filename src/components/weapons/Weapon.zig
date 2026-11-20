const std = @import("std");
const lm = @import("loom");

const projectiles = @import("../../prefabs/Projectile.zig");
const ProjectileOptions = projectiles.Options;

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
    passthrough: bool = false,
    is_crit: bool = false,
    damage_type: Stats.DamageType = .physical,
    damage: f32 = 1,
    knockback_strength: f32 = 0,
    knockback_duration: f32 = 0,
    onhit_effect: ?projectiles.OnHitEffect = null,
    onhit_duration: f32 = 0,
    onhit_strength: f32 = 0,
    override_sprite: ?[]const u8 = null,

    pub fn fromAttack(attack: Attack) SerializedAttack {
        var serialized = SerializedAttack{
            .shooting_degrees = attack.shooting_degrees,
            .size_x = attack.projectile_options.size.x,
            .size_y = attack.projectile_options.size.y,
        };
        inline for (@typeInfo(SerializedAttack).@"struct".field_names) |field_name| {
            if (@hasField(ProjectileOptions, field_name)) {
                @field(serialized, field_name) = @field(attack.projectile_options, field_name);
            }
        }
        return serialized;
    }

    pub fn toAttack(self: SerializedAttack) Attack {
        var projectile_options = ProjectileOptions{
            .size = .init(self.size_x, self.size_y),
        };
        inline for (@typeInfo(SerializedAttack).@"struct".field_names) |field_name| {
            if (@hasField(ProjectileOptions, field_name)) {
                @field(projectile_options, field_name) = @field(self, field_name);
            }
        }
        return .{
            .shooting_degrees = self.shooting_degrees,
            .projectile_options = projectile_options,
        };
    }
};

pub const SerializedWeapon = struct {
    id: []const u8 = "",
    type: WeaponType = .close,
    sprite_left: []const u8 = "ui/icons/empty_icon.png",
    sprite_right: []const u8 = "ui/icons/empty_icon.png",
    light_attack: SerializedAttack = .{},
    heavy_attack: SerializedAttack = .{},
    dash_attack: SerializedAttack = .{},
};

pub const WeaponType = enum {
    close,
    wide,
};

const path_migrations = std.StaticStringMap([]const u8).initComptime(.{
    .{ "weapons/gloves_0.png", "weapons/gloves/gloves_0.png" },
    .{ "weapons/gloves_1.png", "weapons/gloves/gloves_1.png" },
    .{ "weapons/plates_0.png", "weapons/plates/plates_0.png" },
    .{ "weapons/plates_1.png", "weapons/plates/plates_1.png" },
    .{ "weapons/weight_plate.png", "weapons/plates/plates_0.png" },
    .{ "weapons/plates/weight_plate.png", "weapons/plates/plates_0.png" },
    .{ "ui/empty_icon.png", "ui/icons/empty_icon.png" },
});

const Self = @This();

id: []const u8,

light_attack: Attack = .{},
heavy_attack: Attack = .{},
dash_attack: Attack = .{},

sprite_left: []const u8 = "ui/icons/empty_icon.png",
sprite_right: []const u8 = "ui/icons/empty_icon.png",

type: WeaponType = .close,

pub fn jsonStringify(self: @This(), json_writer: anytype) !void {
    const serialized_weapon = SerializedWeapon{
        .id = self.id,
        .type = self.type,
        .sprite_left = self.sprite_left,
        .sprite_right = self.sprite_right,
        .light_attack = SerializedAttack.fromAttack(self.light_attack),
        .heavy_attack = SerializedAttack.fromAttack(self.heavy_attack),
        .dash_attack = SerializedAttack.fromAttack(self.dash_attack),
    };
    try json_writer.write(serialized_weapon);
}

pub fn migratePath(path: []const u8) []const u8 {
    return path_migrations.get(path) orelse path;
}

pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
    const serialized_weapon = try std.json.innerParse(SerializedWeapon, allocator, source, options);
    return @This(){
        .id = serialized_weapon.id,
        .type = serialized_weapon.type,
        .sprite_left = migratePath(serialized_weapon.sprite_left),
        .sprite_right = migratePath(serialized_weapon.sprite_right),
        .light_attack = serialized_weapon.light_attack.toAttack(),
        .heavy_attack = serialized_weapon.heavy_attack.toAttack(),
        .dash_attack = serialized_weapon.dash_attack.toAttack(),
    };
}

pub fn doAttack(
    attack: Attack,
    attack_kind: projectiles.AttackKind,
    position: lm.Vector2,
    target: lm.Vector2,
    shooter_stats: Stats,
) !void {
    const target_offset = target.subtract(position);
    const angle = switch (target_offset.length() > 0.001) {
        true => std.math.atan2(target_offset.y, target_offset.x),
        false => 0.0,
    };

    for (attack.shooting_degrees) |degree_offset| {
        const new_angle = std.math.degreesToRadians(degree_offset) + angle;
        const target_vector = lm.Vec2(1, 0).rotate(new_angle);

        var options = attack.projectile_options;
        const is_rolled_crit = shooter_stats.current.crit_chance > 0 and
            lm.randFloat(f32, 0, 1) <= shooter_stats.current.crit_chance;
        options.is_crit = options.is_crit or is_rolled_crit;
        options.attack_kind = attack_kind;
        options.start_position = position;
        options.target_position = target_vector.add(position);
        options.target_team = switch (shooter_stats.team) {
            .enemy => .player,
            else => .enemy,
        };
        options.shooter_stats = shooter_stats;

        try projectiles.emit(options);
    }
}

pub fn lightAttack(self: *Self, position: lm.Vector2, target: lm.Vector2, shooter_stats: Stats) !void {
    try doAttack(self.light_attack, .light, position, target, shooter_stats);
}

pub fn heavyAttack(self: *Self, position: lm.Vector2, target: lm.Vector2, shooter_stats: Stats) !void {
    try doAttack(self.heavy_attack, .heavy, position, target, shooter_stats);
}

pub fn dashAttack(self: *Self, position: lm.Vector2, target: lm.Vector2, shooter_stats: Stats) !void {
    try doAttack(self.dash_attack, .dash, position, target, shooter_stats);
}

test "Weapon serialization and deserialization roundtrip" {
    const testing = std.testing;
    const allocator = testing.allocator;

    const original = Self{
        .id = "TestGoliath",
        .type = .wide,
        .sprite_left = "weapons/plates/plates_1.png",
        .sprite_right = "weapons/plates/plates_0.png",
        .light_attack = .{
            .shooting_degrees = &.{ -5, 0, 5 },
            .projectile_options = .{
                .damage = 42.5,
                .speed = 500,
                .passthrough = true,
                .knockback_strength = 2.5,
            },
        },
    };

    const weapons_array: [2]?Self = [_]?Self{ original, null };
    const json_string = try std.fmt.allocPrint(allocator, "{f}", .{std.json.fmt(weapons_array, .{})});
    defer allocator.free(json_string);

    var parsed = try std.json.parseFromSlice([2]?Self, allocator, json_string, .{ .ignore_unknown_fields = true });
    defer parsed.deinit();

    const loaded = parsed.value[0].?;
    try testing.expectEqualStrings("TestGoliath", loaded.id);
    try testing.expectEqual(WeaponType.wide, loaded.type);
    try testing.expectEqual(@as(f32, 42.5), loaded.light_attack.projectile_options.damage);
    try testing.expectEqual(@as(f32, 500), loaded.light_attack.projectile_options.speed);
    try testing.expect(loaded.light_attack.projectile_options.passthrough);
    try testing.expectEqual(@as(f32, 2.5), loaded.light_attack.projectile_options.knockback_strength);
    try testing.expectEqual(@as(usize, 3), loaded.light_attack.shooting_degrees.len);
    try testing.expectEqual(@as(f32, -5), loaded.light_attack.shooting_degrees[0]);
    try testing.expect(parsed.value[1] == null);
}

test "Weapon migratePath maps legacy paths and preserves current paths" {
    try std.testing.expectEqualStrings("weapons/plates/plates_0.png", migratePath("weapons/plates/weight_plate.png"));
    try std.testing.expectEqualStrings("weapons/plates/plates_0.png", migratePath("weapons/weight_plate.png"));
    try std.testing.expectEqualStrings("weapons/gloves/gloves_0.png", migratePath("weapons/gloves_0.png"));
    try std.testing.expectEqualStrings("weapons/plates/plates_1.png", migratePath("weapons/plates/plates_1.png"));
}
