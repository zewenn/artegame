const std = @import("std");

/// Baseline player stat overrides applied during map editor playtesting for each room tier.
pub const PlaytestStatProfile = struct {
    health: f32,
    physical_damage: ?f32 = null,
    magic_damage: ?f32 = null,
    armour: ?f32 = null,
    magic_resist: ?f32 = null,
    attack_speed: ?f32 = null,
};

/// Compile-time metadata associated with each room archetype.
pub const RoomMetadata = struct {
    display_name: []const u8,
    hud_label: []const u8,
    default_map_path: []const u8,
    objective_title: []const u8,
    objective_description: []const u8,
    max_active_enemies: u32,
    spawn_interval_seconds: f32,
    playtest_room_number: u32,
    playtest_stats: PlaytestStatProfile,
};

/// Unified room classification shared across progression, spawning, map loading, and editor tools.
pub const RoomType = enum {
    tutorial,
    normal,
    mini_boss,
    boss,

    const metadata_by_type = std.EnumArray(RoomType, RoomMetadata).init(.{
        .tutorial = .{
            .display_name = "Tutorial",
            .hud_label = "  -  Tutorial",
            .default_map_path = "maps/tutorial.json",
            .objective_title = "",
            .objective_description = "",
            .max_active_enemies = 2,
            .spawn_interval_seconds = 0.1,
            .playtest_room_number = 0,
            .playtest_stats = .{ .health = 100.0 },
        },
        .normal = .{
            .display_name = "Normal",
            .hud_label = "",
            .default_map_path = "maps/normal/arena_normal.json",
            .objective_title = "Combat Wave",
            .objective_description = "Defeat all enemies",
            .max_active_enemies = 64,
            .spawn_interval_seconds = 5.0,
            .playtest_room_number = 2,
            .playtest_stats = .{
                .health = 120.0,
                .physical_damage = 30.0,
                .magic_damage = 18.0,
            },
        },
        .mini_boss = .{
            .display_name = "Mini-Boss",
            .hud_label = "  -  Mini-Boss",
            .default_map_path = "maps/mini_boss/knight_arena.json",
            .objective_title = "Mini-Boss Room",
            .objective_description = "Defeat the Mini-Boss!",
            .max_active_enemies = 1,
            .spawn_interval_seconds = 0.1,
            .playtest_room_number = 5,
            .playtest_stats = .{
                .health = 240.0,
                .physical_damage = 50.0,
                .magic_damage = 35.0,
                .armour = 25.0,
                .magic_resist = 20.0,
            },
        },
        .boss = .{
            .display_name = "Boss",
            .hud_label = "  -  Boss",
            .default_map_path = "maps/boss/arena_boss.json",
            .objective_title = "Boss Room",
            .objective_description = "Defeat the Boss!",
            .max_active_enemies = 64,
            .spawn_interval_seconds = 0.1,
            .playtest_room_number = 15,
            .playtest_stats = .{
                .health = 400.0,
                .physical_damage = 75.0,
                .magic_damage = 55.0,
                .armour = 40.0,
                .magic_resist = 35.0,
                .attack_speed = 5.2,
            },
        },
    });

    /// Derives the room type from a 0-based progression room number.
    pub fn fromRoomNumber(room_number: u32) RoomType {
        if (room_number == 0) return .tutorial;
        if (room_number % 15 == 0) return .boss;
        if (room_number % 5 == 0) return .mini_boss;
        return .normal;
    }

    /// Returns compile-time metadata for this room type.
    pub fn metadata(self: RoomType) RoomMetadata {
        return metadata_by_type.get(self);
    }

    /// Returns the human-readable display name for this room type.
    pub fn displayName(self: RoomType) []const u8 {
        return self.metadata().display_name;
    }

    /// Returns the asset subdirectory category name matching this room type.
    pub fn directoryCategory(self: RoomType) []const u8 {
        return @tagName(self);
    }

    /// Returns the HUD round indicator suffix label for this room type.
    pub fn hudLabel(self: RoomType) []const u8 {
        return self.metadata().hud_label;
    }

    /// Returns the fallback default map asset path for this room type.
    pub fn defaultMapPath(self: RoomType) []const u8 {
        return self.metadata().default_map_path;
    }
};

test "RoomType determination from room number" {
    try std.testing.expectEqual(RoomType.tutorial, RoomType.fromRoomNumber(0));
    try std.testing.expectEqual(RoomType.normal, RoomType.fromRoomNumber(1));
    try std.testing.expectEqual(RoomType.normal, RoomType.fromRoomNumber(2));
    try std.testing.expectEqual(RoomType.normal, RoomType.fromRoomNumber(3));
    try std.testing.expectEqual(RoomType.normal, RoomType.fromRoomNumber(4));
    try std.testing.expectEqual(RoomType.mini_boss, RoomType.fromRoomNumber(5));
    try std.testing.expectEqual(RoomType.normal, RoomType.fromRoomNumber(6));
    try std.testing.expectEqual(RoomType.mini_boss, RoomType.fromRoomNumber(10));
    try std.testing.expectEqual(RoomType.normal, RoomType.fromRoomNumber(14));
    try std.testing.expectEqual(RoomType.boss, RoomType.fromRoomNumber(15));
    try std.testing.expectEqual(RoomType.mini_boss, RoomType.fromRoomNumber(20));
    try std.testing.expectEqual(RoomType.boss, RoomType.fromRoomNumber(30));
}
