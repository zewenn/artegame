const std = @import("std");
const lm = @import("loom");
const rl = lm.deps.rl;
const EnemyType = @import("../../components/enemy/EnemyType.zig").EnemyType;

pub const DEFAULT_TILE_SIZE_PIXELS: u32 = 64;

/// Terrain tile identifiers stored in map grids and palette mappings.
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

    /// Converts an integer tile index into a TerrainType if valid.
    pub fn fromInt(value: anytype) ?TerrainType {
        inline for (all_values) |terrain_type| {
            if (@intFromEnum(terrain_type) == value) {
                return terrain_type;
            }
        }
        return null;
    }

    /// Returns the relative texture asset path for this terrain tile sheet.
    pub fn assetPath(self: TerrainType) [:0]const u8 {
        return switch (self) {
            inline else => |terrain_tag| "backgrounds/tiles/" ++ @tagName(terrain_tag) ++ ".png",
        };
    }

    /// Returns the human-readable label for editor display.
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

    /// Maps wall terrain tiles to their corresponding WallType, or null for floor tiles.
    pub fn toWallType(self: TerrainType) ?WallType {
        inline for (std.enums.values(WallType)) |wall_type| {
            if (self == comptime wall_type.terrainType()) {
                return wall_type;
            }
        }
        return null;
    }

    /// Returns whether this terrain represents a wall tile.
    pub fn isWall(self: TerrainType) bool {
        return self.toWallType() != null;
    }
};

/// Texture pixel dimensions for wall side sprites.
pub const SideSpriteDimensions = struct {
    width_pixels: u32,
    height_pixels: u32,
};

/// Consolidated compile-time properties for each wall variant.
pub const WallSpec = struct {
    terrain_type: TerrainType,
    side_asset_path: [:0]const u8,
    side_dimensions_pixels: SideSpriteDimensions,
    blocks_projectiles: bool,
    editor_outline_color: rl.Color,
};

/// Wall archetypes determining collider physics, visuals, and projectile blocking.
pub const WallType = enum(u8) {
    solid = 0,
    low = 1,
    royale = 2,

    pub const all_values = std.enums.values(WallType);
    pub const count = all_values.len;

    const specs = std.EnumArray(WallType, WallSpec).init(.{
        .solid = .{
            .terrain_type = .wall_top,
            .side_asset_path = "backgrounds/wall_normal.png",
            .side_dimensions_pixels = .{ .width_pixels = 16, .height_pixels = 16 },
            .blocks_projectiles = true,
            .editor_outline_color = rl.Color.lime,
        },
        .low = .{
            .terrain_type = .wall_low_top,
            .side_asset_path = "backgrounds/wall_short.png",
            .side_dimensions_pixels = .{ .width_pixels = 16, .height_pixels = 12 },
            .blocks_projectiles = false,
            .editor_outline_color = rl.Color.sky_blue,
        },
        .royale = .{
            .terrain_type = .royale_wall_top,
            .side_asset_path = "backgrounds/wall_royale.png",
            .side_dimensions_pixels = .{ .width_pixels = 16, .height_pixels = 16 },
            .blocks_projectiles = true,
            .editor_outline_color = rl.Color.gold,
        },
    });

    /// Returns the consolidated specification for this wall type.
    pub fn spec(self: WallType) WallSpec {
        return specs.get(self);
    }

    /// Returns the terrain tile corresponding to this wall type.
    pub fn terrainType(self: WallType) TerrainType {
        return self.spec().terrain_type;
    }

    /// Returns the relative texture asset path for this wall's south-facing side sprite.
    pub fn sideAssetPath(self: WallType) [:0]const u8 {
        return self.spec().side_asset_path;
    }

    /// Returns the texture pixel dimensions for this wall's side sprite.
    pub fn sideDimensionsPixels(self: WallType) SideSpriteDimensions {
        return self.spec().side_dimensions_pixels;
    }

    /// Returns whether projectiles collide with and stop on this wall type.
    pub fn blocksProjectiles(self: WallType) bool {
        return self.spec().blocks_projectiles;
    }

    /// Returns the outline color used in the map editor overlay.
    pub fn editorOutlineColor(self: WallType) rl.Color {
        return self.spec().editor_outline_color;
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

/// ECS component attached to instantiated wall collider entities.
pub const Wall = struct {
    wall_type: WallType = .solid,
};

/// Normalized inclusive tile bounds for a rectangular wall segment.
pub const TileBounds = struct {
    min_x: u32,
    max_x: u32,
    min_y: u32,
    max_y: u32,
};

/// Rectangular run of wall tiles serialized in map files and meshed into colliders.
pub const WallSegment = struct {
    start_x_tiles: u32,
    start_y_tiles: u32,
    end_x_tiles: u32,
    end_y_tiles: u32,
    wall_type: WallType = .solid,

    /// Returns normalized inclusive tile bounds regardless of start/end ordering.
    pub fn tileBounds(self: WallSegment) TileBounds {
        return .{
            .min_x = @min(self.start_x_tiles, self.end_x_tiles),
            .max_x = @max(self.start_x_tiles, self.end_x_tiles),
            .min_y = @min(self.start_y_tiles, self.end_y_tiles),
            .max_y = @max(self.start_y_tiles, self.end_y_tiles),
        };
    }
};

/// Rectangular enemy spawn region in map-local pixel coordinates.
pub const SpawnZoneRecord = struct {
    center_x_pixels: f32,
    center_y_pixels: f32,
    width_pixels: f32 = 192.0,
    height_pixels: f32 = 192.0,
    enemy_type: ?EnemyType = null,

    /// Returns whether a map-local pixel position falls inside this spawn zone.
    pub fn contains(self: SpawnZoneRecord, target_position: lm.Vector2) bool {
        const half_width_pixels = self.width_pixels / 2.0;
        const half_height_pixels = self.height_pixels / 2.0;
        const is_within_horizontal = target_position.x >= (self.center_x_pixels - half_width_pixels) and
            target_position.x <= (self.center_x_pixels + half_width_pixels);
        const is_within_vertical = target_position.y >= (self.center_y_pixels - half_height_pixels) and
            target_position.y <= (self.center_y_pixels + half_height_pixels);
        return is_within_horizontal and is_within_vertical;
    }
};

/// Placed marker entity record serialized in map files.
pub const EntityRecord = struct {
    entity_type: []const u8,
    position_x: f32,
    position_y: f32,
};

/// Complete serializable map layout and metadata payload.
pub const MapData = struct {
    version: u32 = 1,
    name: []const u8,
    width_tiles: u32,
    height_tiles: u32,
    tile_size_pixels: u32 = DEFAULT_TILE_SIZE_PIXELS,
    tile_palette: ?[]const TerrainType = null,
    background_tiles: []u8,
    walls: []WallSegment,
    spawn_zones: []SpawnZoneRecord,
    entities: []EntityRecord,

    /// Deep-clones all owned slices and entity type strings using the provided allocator.
    pub fn clone(self: MapData, allocator: std.mem.Allocator) !MapData {
        const cloned_name = try allocator.dupe(u8, self.name);
        const cloned_palette = if (self.tile_palette) |palette|
            try allocator.dupe(TerrainType, palette)
        else
            null;
        const cloned_tiles = try allocator.dupe(u8, self.background_tiles);
        const cloned_walls = try allocator.dupe(WallSegment, self.walls);
        const cloned_spawn_zones = try allocator.dupe(SpawnZoneRecord, self.spawn_zones);
        const cloned_entities = try allocator.alloc(EntityRecord, self.entities.len);

        for (self.entities, 0..) |entity_record, entity_index| {
            cloned_entities[entity_index] = .{
                .entity_type = try allocator.dupe(u8, entity_record.entity_type),
                .position_x = entity_record.position_x,
                .position_y = entity_record.position_y,
            };
        }

        return MapData{
            .version = self.version,
            .name = cloned_name,
            .width_tiles = self.width_tiles,
            .height_tiles = self.height_tiles,
            .tile_size_pixels = self.tile_size_pixels,
            .tile_palette = cloned_palette,
            .background_tiles = cloned_tiles,
            .walls = cloned_walls,
            .spawn_zones = cloned_spawn_zones,
            .entities = cloned_entities,
        };
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

test "WallSegment tileBounds normalizes reversed coordinates" {
    const segment = WallSegment{
        .start_x_tiles = 8,
        .start_y_tiles = 5,
        .end_x_tiles = 2,
        .end_y_tiles = 1,
        .wall_type = .royale,
    };
    const bounds = segment.tileBounds();
    try std.testing.expectEqual(@as(u32, 2), bounds.min_x);
    try std.testing.expectEqual(@as(u32, 8), bounds.max_x);
    try std.testing.expectEqual(@as(u32, 1), bounds.min_y);
    try std.testing.expectEqual(@as(u32, 5), bounds.max_y);
}

test "MapData clone deep-copies all slices including tile_palette and entity_type strings" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const source_palette = [_]TerrainType{ .stone, .royale_wall_top };
    var source_tiles = [_]u8{ 0, 1, 1, 0 };
    var source_walls = [_]WallSegment{
        .{ .start_x_tiles = 0, .start_y_tiles = 0, .end_x_tiles = 1, .end_y_tiles = 0, .wall_type = .royale },
    };
    var source_zones = [_]SpawnZoneRecord{
        .{ .center_x_pixels = 64.0, .center_y_pixels = 64.0, .enemy_type = .knight },
    };
    var source_entities = [_]EntityRecord{
        .{ .entity_type = "player_spawn", .position_x = 32.0, .position_y = 32.0 },
    };

    const source = MapData{
        .name = "clone_test",
        .width_tiles = 2,
        .height_tiles = 2,
        .tile_palette = &source_palette,
        .background_tiles = &source_tiles,
        .walls = &source_walls,
        .spawn_zones = &source_zones,
        .entities = &source_entities,
    };

    const cloned = try source.clone(arena_allocator);
    try std.testing.expectEqualStrings("clone_test", cloned.name);
    try std.testing.expect(cloned.name.ptr != source.name.ptr);
    try std.testing.expect(cloned.tile_palette != null);
    try std.testing.expectEqualSlices(TerrainType, &source_palette, cloned.tile_palette.?);
    try std.testing.expectEqualSlices(u8, &source_tiles, cloned.background_tiles);
    try std.testing.expect(cloned.background_tiles.ptr != source.background_tiles.ptr);
    try std.testing.expectEqual(@as(usize, 1), cloned.walls.len);
    try std.testing.expectEqual(@as(usize, 1), cloned.spawn_zones.len);
    try std.testing.expectEqual(@as(usize, 1), cloned.entities.len);
    try std.testing.expectEqualStrings("player_spawn", cloned.entities[0].entity_type);
    try std.testing.expect(cloned.entities[0].entity_type.ptr != source.entities[0].entity_type.ptr);
}
