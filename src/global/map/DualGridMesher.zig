const std = @import("std");
const lm = @import("loom");

const TILE_SHEET_CELL_PIXELS: f32 = 16.0;

/// Grid coordinates within a 4x4 dual-grid autotile sprite sheet.
pub const SheetCoordinate = struct {
    column_index: u32,
    row_index: u32,

    /// Converts the cell coordinate into a pixel source rectangle on the tilesheet.
    pub fn sourceRectangle(self: SheetCoordinate) lm.Rectangle {
        const x_pixels = @as(f32, @floatFromInt(self.column_index)) * TILE_SHEET_CELL_PIXELS;
        const y_pixels = @as(f32, @floatFromInt(self.row_index)) * TILE_SHEET_CELL_PIXELS;
        return lm.Rect(x_pixels, y_pixels, TILE_SHEET_CELL_PIXELS, TILE_SHEET_CELL_PIXELS);
    }
};

const SHEET_COORDINATES_BY_MASK: [16]?SheetCoordinate = .{
    null, // 0b0000: empty
    .{ .column_index = 3, .row_index = 3 }, // 0b0001: NW
    .{ .column_index = 0, .row_index = 2 }, // 0b0010: NE
    .{ .column_index = 1, .row_index = 2 }, // 0b0011: NW | NE
    .{ .column_index = 0, .row_index = 0 }, // 0b0100: SW
    .{ .column_index = 3, .row_index = 2 }, // 0b0101: NW | SW
    .{ .column_index = 2, .row_index = 3 }, // 0b0110: NE | SW
    .{ .column_index = 3, .row_index = 1 }, // 0b0111: NW | NE | SW
    .{ .column_index = 1, .row_index = 3 }, // 0b1000: SE
    .{ .column_index = 0, .row_index = 1 }, // 0b1001: NW | SE
    .{ .column_index = 1, .row_index = 0 }, // 0b1010: NE | SE
    .{ .column_index = 2, .row_index = 2 }, // 0b1011: NW | NE | SE
    .{ .column_index = 3, .row_index = 0 }, // 0b1100: SW | SE
    .{ .column_index = 2, .row_index = 0 }, // 0b1101: NW | SW | SE
    .{ .column_index = 1, .row_index = 1 }, // 0b1110: NE | SW | SE
    .{ .column_index = 2, .row_index = 1 }, // 0b1111: all corners
};

/// Maps a 4-bit corner presence mask (bit0=NW, bit1=NE, bit2=SW, bit3=SE) to its sheet coordinate.
pub fn scoreToSheetCoordinate(corner_mask: u4) ?SheetCoordinate {
    return SHEET_COORDINATES_BY_MASK[corner_mask];
}

/// Computes per-terrain dual-grid corner bitmasks for a 2x2 quad, filling the lowest terrain as base.
pub fn calculateQuadScores(
    north_west: u8,
    north_east: u8,
    south_west: u8,
    south_east: u8,
    out_masks: []u4,
) void {
    @memset(out_masks, 0);

    const corners = [4]struct { terrain: u8, bit: u4 }{
        .{ .terrain = north_west, .bit = 0b0001 },
        .{ .terrain = north_east, .bit = 0b0010 },
        .{ .terrain = south_west, .bit = 0b0100 },
        .{ .terrain = south_east, .bit = 0b1000 },
    };

    var lowest_terrain_index: usize = out_masks.len;

    for (corners) |corner| {
        const terrain_index = corner.terrain;
        if (terrain_index >= out_masks.len) continue;

        out_masks[terrain_index] |= corner.bit;

        if (terrain_index < lowest_terrain_index) {
            lowest_terrain_index = terrain_index;
        }
    }

    if (lowest_terrain_index < out_masks.len) {
        out_masks[lowest_terrain_index] = 0b1111;
    }
}

test "DualGridMesher calculateQuadScores solid base" {
    var masks: [2]u4 = undefined;
    calculateQuadScores(0, 0, 0, 0, &masks);
    try std.testing.expectEqual(@as(u4, 0b1111), masks[0]);
    try std.testing.expectEqual(@as(u4, 0b0000), masks[1]);
}

test "DualGridMesher calculateQuadScores transition" {
    var masks: [2]u4 = undefined;
    calculateQuadScores(0, 0, 0, 1, &masks);
    try std.testing.expectEqual(@as(u4, 0b1111), masks[0]);
    try std.testing.expectEqual(@as(u4, 0b1000), masks[1]);
}
