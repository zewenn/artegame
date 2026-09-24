const std = @import("std");
const lm = @import("loom");
const MapTypes = @import("MapTypes.zig");
const WallSegment = MapTypes.WallSegment;
pub const WallType = MapTypes.WallType;
pub const Wall = MapTypes.Wall;

pub const WallCollider = struct {
    center_position: lm.Vector2,
    scale: lm.Vector2,
    wall_type: WallType = .solid,

    pub fn createEntity(self: WallCollider, identifier: []const u8) !*lm.Entity {
        return try lm.makeEntity(identifier, .{
            lm.Transform{
                .position = lm.Vec3(self.center_position.x, self.center_position.y, -100),
                .scale = self.scale,
            },
            lm.RectangleCollider.initConfig(.{
                .type = .static,
                .transform = .{
                    .scale = self.scale,
                },
            }),
            Wall{ .wall_type = self.wall_type },
        });
    }
};

fn findHorizontalWallSpan(
    background_tiles: []const u8,
    visited_tiles: []const bool,
    width_tiles: u32,
    start_column: u32,
    row_index: u32,
    target_terrain: u8,
) u32 {
    var current_column = start_column;
    while (current_column + 1 < width_tiles) : (current_column += 1) {
        const next_tile_index = row_index * width_tiles + (current_column + 1);
        if (visited_tiles[next_tile_index]) break;
        if (background_tiles[next_tile_index] != target_terrain) break;
    }
    return current_column;
}

fn canExpandRow(
    background_tiles: []const u8,
    visited_tiles: []const bool,
    width_tiles: u32,
    check_row_index: u32,
    min_column: u32,
    max_column: u32,
    target_terrain: u8,
) bool {
    var column_index = min_column;
    while (column_index <= max_column) : (column_index += 1) {
        const tile_index = check_row_index * width_tiles + column_index;
        if (visited_tiles[tile_index] or background_tiles[tile_index] != target_terrain) {
            return false;
        }
    }
    return true;
}

fn findVerticalWallExpansion(
    background_tiles: []const u8,
    visited_tiles: []const bool,
    width_tiles: u32,
    height_tiles: u32,
    min_column: u32,
    max_column: u32,
    start_row: u32,
    target_terrain: u8,
) u32 {
    var current_row = start_row;
    while (current_row + 1 < height_tiles) : (current_row += 1) {
        const next_row = current_row + 1;
        if (!canExpandRow(background_tiles, visited_tiles, width_tiles, next_row, min_column, max_column, target_terrain)) {
            break;
        }
    }
    return current_row;
}

fn markRectangleVisited(
    visited_tiles: []bool,
    width_tiles: u32,
    min_column: u32,
    max_column: u32,
    min_row: u32,
    max_row: u32,
) void {
    var row_index = min_row;
    while (row_index <= max_row) : (row_index += 1) {
        var column_index = min_column;
        while (column_index <= max_column) : (column_index += 1) {
            visited_tiles[row_index * width_tiles + column_index] = true;
        }
    }
}

pub fn generateSegmentsFromTiles(
    allocator: std.mem.Allocator,
    background_tiles: []const u8,
    width_tiles: u32,
    height_tiles: u32,
) ![]WallSegment {
    const total_tile_count = width_tiles * height_tiles;
    if (total_tile_count == 0 or background_tiles.len < total_tile_count) {
        return try allocator.alloc(WallSegment, 0);
    }

    const visited_tiles = try allocator.alloc(bool, total_tile_count);
    defer allocator.free(visited_tiles);
    @memset(visited_tiles, false);

    var segments = lm.List(WallSegment).init(allocator);
    defer segments.deinit();

    for (0..height_tiles) |row_index_usize| {
        const row_index: u32 = @intCast(row_index_usize);
        for (0..width_tiles) |column_index_usize| {
            const column_index: u32 = @intCast(column_index_usize);
            const tile_index = row_index * width_tiles + column_index;
            if (visited_tiles[tile_index]) continue;

            const terrain_byte = background_tiles[tile_index];
            const terrain_type = lm.coerceTo(MapTypes.TerrainType, terrain_byte) orelse {
                visited_tiles[tile_index] = true;
                continue;
            };
            const wall_type = terrain_type.toWallType() orelse {
                visited_tiles[tile_index] = true;
                continue;
            };

            const max_column = findHorizontalWallSpan(
                background_tiles,
                visited_tiles,
                width_tiles,
                column_index,
                row_index,
                terrain_byte,
            );

            const max_row = findVerticalWallExpansion(
                background_tiles,
                visited_tiles,
                width_tiles,
                height_tiles,
                column_index,
                max_column,
                row_index,
                terrain_byte,
            );

            markRectangleVisited(visited_tiles, width_tiles, column_index, max_column, row_index, max_row);

            try segments.append(WallSegment{
                .start_x_tiles = column_index,
                .start_y_tiles = row_index,
                .end_x_tiles = max_column,
                .end_y_tiles = max_row,
                .wall_type = wall_type,
            });
        }
    }

    return try allocator.dupe(WallSegment, segments.items());
}

pub fn meshGridFromTiles(
    allocator: std.mem.Allocator,
    background_tiles: []const u8,
    width_tiles: u32,
    height_tiles: u32,
    tile_size_pixels: f32,
) ![]WallCollider {
    const segments = try generateSegmentsFromTiles(allocator, background_tiles, width_tiles, height_tiles);
    defer allocator.free(segments);

    return try meshSegments(allocator, segments, tile_size_pixels);
}

pub const wall_collider_vertical_offset_pixels: f32 = 0;

pub fn meshGridHorizontally(
    allocator: std.mem.Allocator,
    wall_grid: []const bool,
    width_tiles: u32,
    height_tiles: u32,
    tile_size_pixels: f32,
) ![]WallCollider {
    var colliders = lm.List(WallCollider).init(allocator);
    defer colliders.deinit();

    for (0..height_tiles) |row_index| {
        var column_index: u32 = 0;
        while (column_index < width_tiles) {
            const current_grid_index = row_index * width_tiles + column_index;
            if (!wall_grid[current_grid_index]) {
                column_index += 1;
                continue;
            }

            const start_column = column_index;
            while (column_index < width_tiles) : (column_index += 1) {
                const next_grid_index = row_index * width_tiles + column_index;
                if (!wall_grid[next_grid_index]) break;
            }

            const run_length_tiles = column_index - start_column;
            const width_pixels = @as(f32, @floatFromInt(run_length_tiles)) * tile_size_pixels;
            const height_pixels = tile_size_pixels;

            const center_x = (@as(f32, @floatFromInt(start_column)) * tile_size_pixels) + (width_pixels / 2.0);
            const center_y = (@as(f32, @floatFromInt(row_index)) * tile_size_pixels) + (height_pixels / 2.0) + wall_collider_vertical_offset_pixels;

            try colliders.append(WallCollider{
                .center_position = lm.Vec2(center_x, center_y),
                .scale = lm.Vec2(width_pixels, height_pixels),
            });
        }
    }

    return try allocator.dupe(WallCollider, colliders.items());
}

pub fn meshSegments(
    allocator: std.mem.Allocator,
    segments: []const WallSegment,
    tile_size_pixels: f32,
) ![]WallCollider {
    var colliders = lm.List(WallCollider).init(allocator);
    defer colliders.deinit();

    for (segments) |segment| {
        const min_column = @min(segment.start_x_tiles, segment.end_x_tiles);
        const max_column = @max(segment.start_x_tiles, segment.end_x_tiles);
        const min_row = @min(segment.start_y_tiles, segment.end_y_tiles);
        const max_row = @max(segment.start_y_tiles, segment.end_y_tiles);

        const run_columns = max_column - min_column + 1;
        const run_rows = max_row - min_row + 1;

        const width_pixels = @as(f32, @floatFromInt(run_columns)) * tile_size_pixels;
        const height_pixels = @as(f32, @floatFromInt(run_rows)) * tile_size_pixels;

        const center_x = (@as(f32, @floatFromInt(min_column)) * tile_size_pixels) + (width_pixels / 2.0);
        const center_y = (@as(f32, @floatFromInt(min_row)) * tile_size_pixels) + (height_pixels / 2.0) + wall_collider_vertical_offset_pixels;

        try colliders.append(WallCollider{
            .center_position = lm.Vec2(center_x, center_y),
            .scale = lm.Vec2(width_pixels, height_pixels),
            .wall_type = segment.wall_type,
        });
    }

    return try allocator.dupe(WallCollider, colliders.items());
}

test "WallMesher meshGridHorizontally single run" {
    const testing_allocator = std.testing.allocator;
    const width: u32 = 4;
    const height: u32 = 2;

    const grid = [_]bool{
        true,  true,  true,  false,
        false, false, false, false,
    };

    const colliders = try meshGridHorizontally(testing_allocator, &grid, width, height, 64.0);
    defer testing_allocator.free(colliders);

    try std.testing.expectEqual(@as(usize, 1), colliders.len);
    try std.testing.expectEqual(@as(f32, 192.0), colliders[0].scale.x);
    try std.testing.expectEqual(@as(f32, 64.0), colliders[0].scale.y);
    try std.testing.expectEqual(@as(f32, 96.0), colliders[0].center_position.x);
    try std.testing.expectEqual(@as(f32, 32.0), colliders[0].center_position.y);
}

test "WallMesher meshSegments horizontal and vertical" {
    const testing_allocator = std.testing.allocator;
    const segments = [_]WallSegment{
        .{ .start_x_tiles = 0, .start_y_tiles = 0, .end_x_tiles = 9, .end_y_tiles = 0, .wall_type = .solid },
        .{ .start_x_tiles = 0, .start_y_tiles = 1, .end_x_tiles = 0, .end_y_tiles = 5, .wall_type = .low },
    };

    const colliders = try meshSegments(testing_allocator, &segments, 64.0);
    defer testing_allocator.free(colliders);

    try std.testing.expectEqual(@as(usize, 2), colliders.len);
    try std.testing.expectEqual(@as(f32, 640.0), colliders[0].scale.x);
    try std.testing.expectEqual(@as(f32, 64.0), colliders[0].scale.y);
    try std.testing.expectEqual(@as(f32, 32.0), colliders[0].center_position.y);
    try std.testing.expectEqual(WallType.solid, colliders[0].wall_type);
    try std.testing.expectEqual(@as(f32, 64.0), colliders[1].scale.x);
    try std.testing.expectEqual(@as(f32, 320.0), colliders[1].scale.y);
    try std.testing.expectEqual(@as(f32, 224.0), colliders[1].center_position.y);
    try std.testing.expectEqual(WallType.low, colliders[1].wall_type);
}

test "WallMesher generateSegmentsFromTiles 2D block merge" {
    const testing_allocator = std.testing.allocator;
    const width: u32 = 4;
    const height: u32 = 4;

    const tiles = [_]u8{
        0, 0, 0, 0,
        0, 2, 2, 0,
        0, 2, 2, 0,
        3, 3, 0, 0,
    };

    const segments = try generateSegmentsFromTiles(testing_allocator, &tiles, width, height);
    defer testing_allocator.free(segments);

    try std.testing.expectEqual(@as(usize, 2), segments.len);

    try std.testing.expectEqual(@as(u32, 1), segments[0].start_x_tiles);
    try std.testing.expectEqual(@as(u32, 1), segments[0].start_y_tiles);
    try std.testing.expectEqual(@as(u32, 2), segments[0].end_x_tiles);
    try std.testing.expectEqual(@as(u32, 2), segments[0].end_y_tiles);
    try std.testing.expectEqual(WallType.solid, segments[0].wall_type);

    try std.testing.expectEqual(@as(u32, 0), segments[1].start_x_tiles);
    try std.testing.expectEqual(@as(u32, 3), segments[1].start_y_tiles);
    try std.testing.expectEqual(@as(u32, 1), segments[1].end_x_tiles);
    try std.testing.expectEqual(@as(u32, 3), segments[1].end_y_tiles);
    try std.testing.expectEqual(WallType.low, segments[1].wall_type);
}
