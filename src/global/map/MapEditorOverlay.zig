const std = @import("std");
const lm = @import("loom");
const rl = lm.deps.rl;
const EnemyType = @import("../../components/enemy/EnemyType.zig").EnemyType;
const MapEditorDocument = @import("MapEditorDocument.zig");

fn drawTileGrid(
    top_left_pixels: lm.Vector2,
    width_tiles: u32,
    height_tiles: u32,
    tile_size_pixels: f32,
) void {
    const grid_color = rl.Color{ .r = 255, .g = 255, .b = 255, .a = 30 };
    const total_width_pixels = @as(f32, @floatFromInt(width_tiles)) * tile_size_pixels;
    const total_height_pixels = @as(f32, @floatFromInt(height_tiles)) * tile_size_pixels;

    var column_index: u32 = 0;
    while (column_index <= width_tiles) : (column_index += 1) {
        const line_x_pixels = top_left_pixels.x + @as(f32, @floatFromInt(column_index)) * tile_size_pixels;
        rl.drawLineEx(
            lm.Vec2(line_x_pixels, top_left_pixels.y),
            lm.Vec2(line_x_pixels, top_left_pixels.y + total_height_pixels),
            1.0,
            grid_color,
        );
    }

    var row_index: u32 = 0;
    while (row_index <= height_tiles) : (row_index += 1) {
        const line_y_pixels = top_left_pixels.y + @as(f32, @floatFromInt(row_index)) * tile_size_pixels;
        rl.drawLineEx(
            lm.Vec2(top_left_pixels.x, line_y_pixels),
            lm.Vec2(top_left_pixels.x + total_width_pixels, line_y_pixels),
            1.0,
            grid_color,
        );
    }
}

fn drawWallOutlines(
    top_left_pixels: lm.Vector2,
    walls: []const @import("MapTypes.zig").WallSegment,
    tile_size_pixels: f32,
) void {
    for (walls) |wall| {
        const bounds = wall.tileBounds();
        const width_pixels = @as(f32, @floatFromInt(bounds.max_x - bounds.min_x + 1)) * tile_size_pixels;
        const height_pixels = @as(f32, @floatFromInt(bounds.max_y - bounds.min_y + 1)) * tile_size_pixels;

        const rectangle_x_pixels = top_left_pixels.x + @as(f32, @floatFromInt(bounds.min_x)) * tile_size_pixels;
        const rectangle_y_pixels = top_left_pixels.y + @as(f32, @floatFromInt(bounds.min_y)) * tile_size_pixels;

        rl.drawRectangleLinesEx(
            lm.Rect(rectangle_x_pixels, rectangle_y_pixels, width_pixels, height_pixels),
            3.0,
            wall.wall_type.editorOutlineColor(),
        );
    }
}

fn drawSpawnZones(
    top_left_pixels: lm.Vector2,
    spawn_zones: []const @import("MapTypes.zig").SpawnZoneRecord,
) void {
    const font_size_pixels: i32 = 14;
    for (spawn_zones) |zone| {
        const zone_x_pixels = top_left_pixels.x + zone.center_x_pixels - (zone.width_pixels / 2.0);
        const zone_y_pixels = top_left_pixels.y + zone.center_y_pixels - (zone.height_pixels / 2.0);
        const zone_rectangle = lm.Rect(zone_x_pixels, zone_y_pixels, zone.width_pixels, zone.height_pixels);

        rl.drawRectangleRec(zone_rectangle, EnemyType.editorFillColor(zone.enemy_type));
        rl.drawRectangleLinesEx(zone_rectangle, 2.0, EnemyType.editorOutlineColor(zone.enemy_type));

        const zone_label = EnemyType.label(zone.enemy_type);
        const text_width_pixels = rl.measureText(zone_label, font_size_pixels);
        const text_x_pixels: i32 = @intFromFloat(zone_x_pixels + (zone.width_pixels / 2.0) - (@as(f32, @floatFromInt(text_width_pixels)) / 2.0));
        const text_y_pixels: i32 = @intFromFloat(zone_y_pixels + (zone.height_pixels / 2.0) - (@as(f32, @floatFromInt(font_size_pixels)) / 2.0));

        rl.drawText(zone_label, text_x_pixels + 1, text_y_pixels + 1, font_size_pixels, rl.Color.black);
        rl.drawText(zone_label, text_x_pixels, text_y_pixels, font_size_pixels, rl.Color.white);
    }
}

fn drawEntityMarkers(
    top_left_pixels: lm.Vector2,
    player_spawn_position: lm.Vector2,
    exit_door_positions: []const lm.Vector2,
    tile_size_pixels: f32,
) void {
    const player_world_x_pixels = top_left_pixels.x + player_spawn_position.x;
    const player_world_y_pixels = top_left_pixels.y + player_spawn_position.y;
    rl.drawCircleV(lm.Vec2(player_world_x_pixels, player_world_y_pixels), 24.0, rl.Color.gold);
    rl.drawCircleLinesV(lm.Vec2(player_world_x_pixels, player_world_y_pixels), 26.0, rl.Color.white);

    const half_tile_pixels = tile_size_pixels * 0.5;
    for (exit_door_positions) |door_position| {
        const door_top_left_x_pixels = top_left_pixels.x + door_position.x - half_tile_pixels;
        const door_top_left_y_pixels = top_left_pixels.y + door_position.y - half_tile_pixels;
        rl.drawRectangleV(
            lm.Vec2(door_top_left_x_pixels, door_top_left_y_pixels),
            lm.Vec2(tile_size_pixels, tile_size_pixels),
            rl.Color.sky_blue,
        );
        rl.drawRectangleLinesEx(
            lm.Rect(door_top_left_x_pixels, door_top_left_y_pixels, tile_size_pixels, tile_size_pixels),
            2.0,
            rl.Color.white,
        );
    }
}

fn drawSpawnZoneRemovalHighlight(
    document: *const MapEditorDocument,
    top_left_pixels: lm.Vector2,
    maybe_hovered_position: ?lm.Vector2,
) void {
    const relative_position = maybe_hovered_position orelse return;
    const zone_index = document.findSpawnZoneIndexAtPosition(relative_position) orelse return;
    const zone = document.spawn_zones.items()[zone_index];

    const zone_x_pixels = top_left_pixels.x + zone.center_x_pixels - (zone.width_pixels / 2.0);
    const zone_y_pixels = top_left_pixels.y + zone.center_y_pixels - (zone.height_pixels / 2.0);
    const highlight_rectangle = lm.Rect(zone_x_pixels, zone_y_pixels, zone.width_pixels, zone.height_pixels);

    rl.drawRectangleRec(highlight_rectangle, rl.Color{ .r = 255, .g = 40, .b = 40, .a = 120 });
    rl.drawRectangleLinesEx(highlight_rectangle, 3.0, rl.Color.red);
}

fn drawExitDoorRemovalHighlight(
    document: *const MapEditorDocument,
    top_left_pixels: lm.Vector2,
    maybe_hovered_position: ?lm.Vector2,
) void {
    const relative_position = maybe_hovered_position orelse return;
    const door_index = document.findExitDoorIndexAtPosition(relative_position) orelse return;
    const door_position = document.exit_door_positions.items()[door_index];

    const half_tile_pixels = document.tile_size_pixels * 0.5;
    const highlight_rectangle = lm.Rect(
        top_left_pixels.x + door_position.x - half_tile_pixels,
        top_left_pixels.y + door_position.y - half_tile_pixels,
        document.tile_size_pixels,
        document.tile_size_pixels,
    );

    rl.drawRectangleRec(highlight_rectangle, rl.Color{ .r = 255, .g = 40, .b = 40, .a = 120 });
    rl.drawRectangleLinesEx(highlight_rectangle, 3.0, rl.Color.red);
}

/// Renders world-space editor overlays (tile grid, wall outlines, spawn zones, entity markers, highlights).
pub fn drawCanvasOverlays(
    document: *const MapEditorDocument,
    top_left_pixels: lm.Vector2,
    maybe_hovered_position: ?lm.Vector2,
) void {
    drawTileGrid(top_left_pixels, document.width_tiles, document.height_tiles, document.tile_size_pixels);
    drawWallOutlines(top_left_pixels, document.walls.items(), document.tile_size_pixels);

    if (document.current_tool == .spawn_zone_erase) {
        drawSpawnZoneRemovalHighlight(document, top_left_pixels, maybe_hovered_position);
    }

    drawSpawnZones(top_left_pixels, document.spawn_zones.items());
    drawEntityMarkers(
        top_left_pixels,
        document.player_spawn_position,
        document.exit_door_positions.items(),
        document.tile_size_pixels,
    );

    if (document.current_tool == .exit_door_erase) {
        drawExitDoorRemovalHighlight(document, top_left_pixels, maybe_hovered_position);
    }
}
