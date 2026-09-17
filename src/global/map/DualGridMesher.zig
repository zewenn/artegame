const std = @import("std");
const lm = @import("loom");
const MapTypes = @import("MapTypes.zig");
const TerrainType = MapTypes.TerrainType;

pub const SheetCoordinate = struct {
    column_index: u32,
    row_index: u32,

    pub fn sourceRectangle(self: SheetCoordinate) lm.Rectangle {
        const x_pixels = @as(f32, @floatFromInt(self.column_index * 16));
        const y_pixels = @as(f32, @floatFromInt(self.row_index * 16));
        return lm.Rect(x_pixels, y_pixels, 16.0, 16.0);
    }
};

/// Converts prime-factor dual-grid score to (column, row) coordinate on 4x4 tilesheet.
/// Conforms to tilemap_mapping.md:
/// Row 0: sw (5), nese (21), nwswse (70), swse (35)
/// Row 1: nwse (14), neswse (105), nwneswse (210), nwnesw (30)
/// Row 2: ne (3), nwne (6), nwnese (42), nwsw (10)
/// Row 3: empty, se (7), nesw (15), nw (2)
pub fn scoreToSheetCoordinate(score: usize) ?SheetCoordinate {
    return switch (score) {
        5 => SheetCoordinate{ .column_index = 0, .row_index = 0 },
        21 => SheetCoordinate{ .column_index = 1, .row_index = 0 },
        70 => SheetCoordinate{ .column_index = 2, .row_index = 0 },
        35 => SheetCoordinate{ .column_index = 3, .row_index = 0 },

        14 => SheetCoordinate{ .column_index = 0, .row_index = 1 },
        105 => SheetCoordinate{ .column_index = 1, .row_index = 1 },
        210 => SheetCoordinate{ .column_index = 2, .row_index = 1 },
        30 => SheetCoordinate{ .column_index = 3, .row_index = 1 },

        3 => SheetCoordinate{ .column_index = 0, .row_index = 2 },
        6 => SheetCoordinate{ .column_index = 1, .row_index = 2 },
        42 => SheetCoordinate{ .column_index = 2, .row_index = 2 },
        10 => SheetCoordinate{ .column_index = 3, .row_index = 2 },

        7 => SheetCoordinate{ .column_index = 1, .row_index = 3 },
        15 => SheetCoordinate{ .column_index = 2, .row_index = 3 },
        2 => SheetCoordinate{ .column_index = 3, .row_index = 3 },

        else => null,
    };
}

/// Evaluates dual-grid corner scoring for each terrain layer at a given quad intersection.
/// Returns array of scores per terrain type.
pub fn calculateQuadScores(
    north_west: u8,
    north_east: u8,
    south_west: u8,
    south_east: u8,
    out_scores: []usize,
) void {
    @memset(out_scores, 0);

    const corners = [4]struct { terrain: u8, prime: usize }{
        .{ .terrain = north_west, .prime = 2 },
        .{ .terrain = north_east, .prime = 3 },
        .{ .terrain = south_west, .prime = 5 },
        .{ .terrain = south_east, .prime = 7 },
    };

    var lowest_terrain_index: usize = out_scores.len;

    for (corners) |corner| {
        const terrain_index = corner.terrain;
        if (terrain_index >= out_scores.len) continue;

        if (out_scores[terrain_index] == 0) {
            out_scores[terrain_index] = corner.prime;
        } else {
            out_scores[terrain_index] *= corner.prime;
        }

        if (terrain_index < lowest_terrain_index) {
            lowest_terrain_index = terrain_index;
        }
    }

    if (lowest_terrain_index < out_scores.len) {
        // Base terrain forms solid base under overlay transitions
        out_scores[lowest_terrain_index] = 2 * 3 * 5 * 7;
    }
}

test "DualGridMesher scoreToSheetCoordinate" {
    const full_tile_coordinate = scoreToSheetCoordinate(210) orelse unreachable;
    try std.testing.expectEqual(@as(u32, 2), full_tile_coordinate.column_index);
    try std.testing.expectEqual(@as(u32, 1), full_tile_coordinate.row_index);

    const north_west_coordinate = scoreToSheetCoordinate(2) orelse unreachable;
    try std.testing.expectEqual(@as(u32, 3), north_west_coordinate.column_index);
    try std.testing.expectEqual(@as(u32, 3), north_west_coordinate.row_index);

    try std.testing.expect(scoreToSheetCoordinate(0) == null);
    try std.testing.expect(scoreToSheetCoordinate(999) == null);
}

test "DualGridMesher calculateQuadScores solid base" {
    var scores: [2]usize = undefined;
    calculateQuadScores(0, 0, 0, 0, &scores);
    try std.testing.expectEqual(@as(usize, 210), scores[0]);
    try std.testing.expectEqual(@as(usize, 0), scores[1]);
}

test "DualGridMesher calculateQuadScores transition" {
    var scores: [2]usize = undefined;
    // 3 corners stone (0), south-east carpet (1)
    calculateQuadScores(0, 0, 0, 1, &scores);
    // Stone is lowest so it becomes solid base (210)
    try std.testing.expectEqual(@as(usize, 210), scores[0]);
    // Carpet is SE corner only (prime 7)
    try std.testing.expectEqual(@as(usize, 7), scores[1]);
}
