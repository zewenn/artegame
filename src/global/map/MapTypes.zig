const std = @import("std");
const lm = @import("loom");

pub const TerrainType = enum(u8) {
    stone = 0,
    carpet = 1,

    pub const count = @typeInfo(TerrainType).@"enum".fields.len;

    pub fn assetPath(self: TerrainType) []const u8 {
        return switch (self) {
            .stone => "backgrounds/tiles/stone.png",
            .carpet => "backgrounds/tiles/carpet.png",
        };
    }

    pub fn displayName(self: TerrainType) []const u8 {
        return switch (self) {
            .stone => "Stone",
            .carpet => "Carpet",
        };
    }
};

pub const WallType = enum(u8) {
    solid = 0,
    low = 1,

    pub const count = @typeInfo(WallType).@"enum".fields.len;

    pub fn assetPath(self: WallType) []const u8 {
        return switch (self) {
            .solid => "backgrounds/bakcground_tile_2_32x32.png",
            .low => "backgrounds/base.png",
        };
    }

    pub fn displayName(self: WallType) []const u8 {
        return switch (self) {
            .solid => "Solid",
            .low => "Low",
        };
    }
};

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
    background_tiles: []u8,
    walls: []WallSegment,
    spawn_zones: []SpawnZoneRecord,
    entities: []EntityRecord,

    pub fn deinit(self: *MapData, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.background_tiles);
        allocator.free(self.walls);
        allocator.free(self.spawn_zones);
        for (self.entities) |entity_record| {
            allocator.free(entity_record.entity_type);
        }
        allocator.free(self.entities);
    }
};
