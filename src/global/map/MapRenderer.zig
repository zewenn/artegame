const std = @import("std");
const lm = @import("loom");
const MapTypes = @import("MapTypes.zig");
const TerrainType = MapTypes.TerrainType;
const DualGridMesher = @import("DualGridMesher.zig");

const rl = lm.deps.rl;

const Self = @This();

render_texture: ?rl.RenderTexture = null,
baked_texture: ?rl.Texture = null,
is_baked: bool = false,
width_tiles: u32 = 0,
height_tiles: u32 = 0,
tile_size_pixels: f32 = 64.0,
map_width_pixels: f32 = 0,
map_height_pixels: f32 = 0,

pub fn init() Self {
    return Self{};
}

pub fn deinit(self: *Self) void {
    if (self.baked_texture) |texture| {
        texture.unload();
    }
    self.baked_texture = null;

    if (self.render_texture) |*texture| {
        texture.unload();
    }
    self.render_texture = null;
    self.is_baked = false;
}

/// Allocates or reallocates the RenderTexture to match map dimensions.
pub fn configureDimensions(self: *Self, width_tiles: u32, height_tiles: u32, tile_size_pixels: f32) !void {
    const target_width_pixels = @as(f32, @floatFromInt(width_tiles)) * tile_size_pixels;
    const target_height_pixels = @as(f32, @floatFromInt(height_tiles)) * tile_size_pixels;

    if (self.render_texture != null and
        self.width_tiles == width_tiles and
        self.height_tiles == height_tiles and
        self.tile_size_pixels == tile_size_pixels)
    {
        return;
    }

    if (self.baked_texture) |texture| {
        texture.unload();
        self.baked_texture = null;
    }

    if (self.render_texture) |*texture| {
        texture.unload();
        self.render_texture = null;
    }

    const width_integer: i32 = @intFromFloat(target_width_pixels);
    const height_integer: i32 = @intFromFloat(target_height_pixels);

    self.render_texture = try rl.RenderTexture.init(width_integer, height_integer);
    self.width_tiles = width_tiles;
    self.height_tiles = height_tiles;
    self.tile_size_pixels = tile_size_pixels;
    self.map_width_pixels = target_width_pixels;
    self.map_height_pixels = target_height_pixels;
    self.is_baked = false;
}

/// Bakes all background tiles and dual-grid transitions into the single RenderTexture.
/// Upscales 16x16 tiles by 4x to 64x64 destination pixels.
pub fn bake(self: *Self, background_tiles: []const u8) !void {
    const target_texture = &(self.render_texture orelse return error.RenderTextureNotConfigured);

    target_texture.begin();
    rl.clearBackground(rl.Color.blank);

    const quad_width_count = if (self.width_tiles > 0) self.width_tiles - 1 else 0;
    const quad_height_count = if (self.height_tiles > 0) self.height_tiles - 1 else 0;

    var layer_scores: [TerrainType.count]usize = undefined;

    for (0..TerrainType.count) |layer_index| {
        const terrain_type = lm.coerceTo(TerrainType, layer_index) orelse continue;
        const active_terrain_texture = lm.assets.texture.get(terrain_type.assetPath(), &.{ 64, 64 }) orelse continue;

        for (0..quad_height_count) |row_index| {
            for (0..quad_width_count) |column_index| {
                const north_west = background_tiles[row_index * self.width_tiles + column_index];
                const north_east = background_tiles[row_index * self.width_tiles + (column_index + 1)];
                const south_west = background_tiles[(row_index + 1) * self.width_tiles + column_index];
                const south_east = background_tiles[(row_index + 1) * self.width_tiles + (column_index + 1)];

                DualGridMesher.calculateQuadScores(north_west, north_east, south_west, south_east, &layer_scores);

                const score = layer_scores[layer_index];
                if (score == 0) continue;

                const sheet_coordinate = DualGridMesher.scoreToSheetCoordinate(score) orelse continue;
                const source_rectangle = sheet_coordinate.sourceRectangle();

                const destination_x_pixels = @as(f32, @floatFromInt(column_index)) * self.tile_size_pixels;
                const destination_y_pixels = @as(f32, @floatFromInt(row_index)) * self.tile_size_pixels;
                const destination_rectangle = lm.Rect(
                    destination_x_pixels,
                    destination_y_pixels,
                    self.tile_size_pixels,
                    self.tile_size_pixels,
                );

                rl.drawTexturePro(
                    active_terrain_texture.*,
                    source_rectangle,
                    destination_rectangle,
                    lm.Vec2(0, 0),
                    0.0,
                    rl.Color.white,
                );
            }
        }
    }

    target_texture.end();

    var image = try rl.loadImageFromTexture(target_texture.texture);
    defer image.unload();
    image.flipVertical();

    if (self.baked_texture) |texture| {
        texture.unload();
        self.baked_texture = null;
    }
    self.baked_texture = try rl.loadTextureFromImage(image);
    self.is_baked = true;
}

/// Returns the baked upright Texture suitable for Loom display.add.
pub fn getTexture(self: *Self) ?rl.Texture {
    return self.baked_texture;
}

/// Directly draws the pre-baked RenderTexture to the screen at the given world coordinates.
pub fn drawDirect(self: *Self, world_position: lm.Vector2) void {
    const active_texture = &(self.render_texture orelse return);
    if (!self.is_baked) return;

    const source_rectangle = lm.Rect(
        0.0,
        0.0,
        @as(f32, @floatFromInt(active_texture.texture.width)),
        -@as(f32, @floatFromInt(active_texture.texture.height)),
    );

    const half_tile = self.tile_size_pixels * 0.5;
    const destination_rectangle = lm.Rect(
        world_position.x + half_tile,
        world_position.y + half_tile,
        self.map_width_pixels,
        self.map_height_pixels,
    );

    rl.drawTexturePro(
        active_texture.texture,
        source_rectangle,
        destination_rectangle,
        lm.Vec2(0, 0),
        0.0,
        rl.Color.white,
    );
}
