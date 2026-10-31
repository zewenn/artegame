const std = @import("std");
const lm = @import("loom");
const rl = lm.deps.rl;
const EnemyType = @import("../../components/enemy/EnemyType.zig").EnemyType;

pub const TerrainType = enum(u8) {
    stone = 0,
    royale_stone = 1,
    carpet = 2,
    royale_carpet = 3,
    wall_top = 4,
    wall_low_top = 5,
    royale_wall_top = 6,

    pub const all_values = std.enums.values(TerrainType);
    pub const count = all_values.len;

    pub fn fromInt(value: anytype) ?TerrainType {
        inline for (all_values) |terrain_type| {
            if (@intFromEnum(terrain_type) == value) {
                return terrain_type;
            }
        }
        return null;
    }

    pub fn assetPath(self: TerrainType) [:0]const u8 {
        return switch (self) {
            inline else => |terrain_tag| "backgrounds/tiles/" ++ @tagName(terrain_tag) ++ ".png",
        };
    }

    pub fn displayName(self: TerrainType) []const u8 {
        return switch (self) {
            .stone => "Stone",
            .royale_stone => "Royale Stone",
            .carpet => "Carpet",
            .royale_carpet => "Royale Carpet",
            .wall_top => "Solid Wall",
            .wall_low_top => "Low Wall",
            .royale_wall_top => "Royale Wall",
        };
    }

    pub fn toWallType(self: TerrainType) ?WallType {
        inline for (std.enums.values(WallType)) |wall_type| {
            if (self == comptime wall_type.terrainType()) {
                return wall_type;
            }
        }
        return null;
    }

    pub fn isWall(self: TerrainType) bool {
        return self.toWallType() != null;
    }

    pub fn sideAssetPath(self: TerrainType) ?[:0]const u8 {
        const wall_type = self.toWallType() orelse return null;
        return wall_type.sideAssetPath();
    }
};

pub const SideSpriteDimensions = struct {
    width_pixels: u32,
    height_pixels: u32,
};

pub const WallType = enum(u8) {
    solid = 0,
    low = 1,
    royale = 2,

    pub const all_values = std.enums.values(WallType);
    pub const count = all_values.len;

    pub fn terrainType(self: WallType) TerrainType {
        return switch (self) {
            .solid => .wall_top,
            .low => .wall_low_top,
            .royale => .royale_wall_top,
        };
    }

    pub fn sideAssetPath(self: WallType) [:0]const u8 {
        return switch (self) {
            .solid => "backgrounds/wall_normal.png",
            .low => "backgrounds/wall_short.png",
            .royale => "backgrounds/wall_royale.png",
        };
    }

    pub fn assetPath(self: WallType) [:0]const u8 {
        return self.sideAssetPath();
    }

    pub fn sideDimensionsPixels(self: WallType) SideSpriteDimensions {
        return switch (self) {
            .solid, .royale => .{ .width_pixels = 16, .height_pixels = 16 },
            .low => .{ .width_pixels = 16, .height_pixels = 12 },
        };
    }

    pub fn blocksProjectiles(self: WallType) bool {
        return switch (self) {
            .solid, .royale => true,
            .low => false,
        };
    }

    pub fn editorOutlineColor(self: WallType) rl.Color {
        return switch (self) {
            .solid => rl.Color.lime,
            .low => rl.Color.sky_blue,
            .royale => rl.Color.gold,
        };
    }

    pub fn displayName(self: WallType) []const u8 {
        return switch (self) {
            .solid => "Solid",
            .low => "Low",
            .royale => "Royale",
        };
    }
};

comptime {
    for (std.enums.values(TerrainType)) |terrain_type| {
        const is_wall_terrain = std.mem.indexOf(u8, @tagName(terrain_type), "wall") != null;
        if (is_wall_terrain and terrain_type.toWallType() == null) {
            @compileError("TerrainType." ++ @tagName(terrain_type) ++ " contains 'wall' but has no corresponding WallType mapping");
        }
    }
    for (std.enums.values(WallType)) |wall_type| {
        const round_trip_wall = wall_type.terrainType().toWallType();
        if (round_trip_wall != wall_type) {
            @compileError("WallType." ++ @tagName(wall_type) ++ " failed round-trip bijection verification through TerrainType");
        }
    }
}

pub const Wall = struct {
    wall_type: WallType = .solid,
};

pub const WallSegment = struct {
    start_x_tiles: u32,
    start_y_tiles: u32,
    end_x_tiles: u32,
    end_y_tiles: u32,
    wall_type: WallType = .solid,
};

pub const SpawnZoneRecord = struct {
    center_x_pixels: f32,
    center_y_pixels: f32,
    width_pixels: f32 = 192.0,
    height_pixels: f32 = 192.0,
    enemy_type: ?EnemyType = null,

    pub fn contains(self: SpawnZoneRecord, target_position: lm.Vector2) bool {
        const half_width = self.width_pixels / 2.0;
        const half_height = self.height_pixels / 2.0;
        const is_within_horizontal = target_position.x >= (self.center_x_pixels - half_width) and
            target_position.x <= (self.center_x_pixels + half_width);
        const is_within_vertical = target_position.y >= (self.center_y_pixels - half_height) and
            target_position.y <= (self.center_y_pixels + half_height);
        return is_within_horizontal and is_within_vertical;
    }
};

pub const EntityRecord = struct {
    entity_type: []const u8,
    position_x: f32,
    position_y: f32,
};

pub const MapData = struct {
    version: u32 = 1,
    name: []const u8,
    width_tiles: u32,
    height_tiles: u32,
    tile_size_pixels: u32 = 64,
    tile_palette: ?[]const TerrainType = null,
    background_tiles: []u8,
    walls: []WallSegment,
    spawn_zones: []SpawnZoneRecord,
    entities: []EntityRecord,

    pub fn deinit(self: *MapData, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        if (self.tile_palette) |palette| {
            allocator.free(palette);
        }
        allocator.free(self.background_tiles);
        allocator.free(self.walls);
        allocator.free(self.spawn_zones);
        for (self.entities) |entity_record| {
            allocator.free(entity_record.entity_type);
        }
        allocator.free(self.entities);
    }
};

test "MapTypes all TerrainType and WallType asset paths exist on disk" {
    const io = lm.io.singleThreaded();
    inline for (std.enums.values(TerrainType)) |terrain_type| {
        const asset_path = "src/assets/" ++ comptime terrain_type.assetPath();
        var file = try std.Io.Dir.cwd().openFile(io, asset_path, .{ .mode = .read_only });
        file.close(io);
    }
    inline for (std.enums.values(WallType)) |wall_type| {
        const asset_path = "src/assets/" ++ comptime wall_type.sideAssetPath();
        var file = try std.Io.Dir.cwd().openFile(io, asset_path, .{ .mode = .read_only });
        file.close(io);
    }
}

test "MapTypes comptime reflection maps wall terrains to WallType bijectively" {
    try std.testing.expectEqual(WallType.solid, TerrainType.wall_top.toWallType());
    try std.testing.expectEqual(WallType.low, TerrainType.wall_low_top.toWallType());
    try std.testing.expectEqual(WallType.royale, TerrainType.royale_wall_top.toWallType());
    try std.testing.expectEqual(@as(?WallType, null), TerrainType.stone.toWallType());
    try std.testing.expectEqual(@as(?WallType, null), TerrainType.royale_stone.toWallType());
    try std.testing.expectEqual(@as(?WallType, null), TerrainType.carpet.toWallType());
    try std.testing.expectEqual(@as(?WallType, null), TerrainType.royale_carpet.toWallType());

    try std.testing.expectEqual(TerrainType.wall_top, WallType.solid.terrainType());
    try std.testing.expectEqual(TerrainType.wall_low_top, WallType.low.terrainType());
    try std.testing.expectEqual(TerrainType.royale_wall_top, WallType.royale.terrainType());

    try std.testing.expect(TerrainType.wall_top.isWall());
    try std.testing.expect(TerrainType.wall_low_top.isWall());
    try std.testing.expect(TerrainType.royale_wall_top.isWall());
    try std.testing.expect(!TerrainType.stone.isWall());
    try std.testing.expect(!TerrainType.royale_stone.isWall());
    try std.testing.expect(!TerrainType.carpet.isWall());
    try std.testing.expect(!TerrainType.royale_carpet.isWall());

    try std.testing.expect(WallType.solid.blocksProjectiles());
    try std.testing.expect(!WallType.low.blocksProjectiles());
    try std.testing.expect(WallType.royale.blocksProjectiles());

    try std.testing.expectEqual(SideSpriteDimensions{ .width_pixels = 16, .height_pixels = 16 }, WallType.solid.sideDimensionsPixels());
    try std.testing.expectEqual(SideSpriteDimensions{ .width_pixels = 16, .height_pixels = 12 }, WallType.low.sideDimensionsPixels());
    try std.testing.expectEqual(SideSpriteDimensions{ .width_pixels = 16, .height_pixels = 16 }, WallType.royale.sideDimensionsPixels());

    try std.testing.expectEqualStrings("Solid", WallType.solid.displayName());
    try std.testing.expectEqualStrings("Low", WallType.low.displayName());
    try std.testing.expectEqualStrings("Royale", WallType.royale.displayName());

    try std.testing.expectEqual(rl.Color.lime, WallType.solid.editorOutlineColor());
    try std.testing.expectEqual(rl.Color.sky_blue, WallType.low.editorOutlineColor());
    try std.testing.expectEqual(rl.Color.gold, WallType.royale.editorOutlineColor());
}

test "MapData deinit handles tile_palette cleanly" {
    const testing_allocator = std.testing.allocator;
    const palette = try testing_allocator.dupe(TerrainType, &.{ .stone, .royale_wall_top });
    var map_data = MapData{
        .name = try testing_allocator.dupe(u8, "test_arena"),
        .width_tiles = 10,
        .height_tiles = 10,
        .tile_palette = palette,
        .background_tiles = try testing_allocator.dupe(u8, &.{}),
        .walls = try testing_allocator.dupe(WallSegment, &.{}),
        .spawn_zones = try testing_allocator.dupe(SpawnZoneRecord, &.{}),
        .entities = try testing_allocator.dupe(EntityRecord, &.{}),
    };
    map_data.deinit(testing_allocator);
}
