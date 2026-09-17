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
            lm.Renderer.tile(self.wall_type.assetPath(), .init(64, 64)),
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

/// Merges horizontal contiguous wall cells on a 2D grid into unified 1D colliders.
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
            const center_y = (@as(f32, @floatFromInt(row_index)) * tile_size_pixels) + (height_pixels / 2.0);

            try colliders.append(WallCollider{
                .center_position = lm.Vec2(center_x, center_y),
                .scale = lm.Vec2(width_pixels, height_pixels),
            });
        }
    }

    return try allocator.dupe(WallCollider, colliders.items());
}

/// Converts explicit wall line segments into unified 1D colliders.
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
        const center_y = (@as(f32, @floatFromInt(min_row)) * tile_size_pixels) + (height_pixels / 2.0);

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

    // Row 0: true, true, true, false
    // Row 1: false, false, false, false
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
    // Segment 1: 10 tiles wide
    try std.testing.expectEqual(@as(f32, 640.0), colliders[0].scale.x);
    try std.testing.expectEqual(@as(f32, 64.0), colliders[0].scale.y);
    try std.testing.expectEqual(WallType.solid, colliders[0].wall_type);
    // Segment 2: 5 tiles tall
    try std.testing.expectEqual(@as(f32, 64.0), colliders[1].scale.x);
    try std.testing.expectEqual(@as(f32, 320.0), colliders[1].scale.y);
    try std.testing.expectEqual(WallType.low, colliders[1].wall_type);
}
