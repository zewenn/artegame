const std = @import("std");
const lm = @import("loom");
const MapTypes = @import("MapTypes.zig");
const TerrainType = MapTypes.TerrainType;
const WallSegment = MapTypes.WallSegment;
const SpawnZoneRecord = MapTypes.SpawnZoneRecord;
const EntityRecord = MapTypes.EntityRecord;
const MapData = MapTypes.MapData;
const EnemyType = @import("../../components/enemy/EnemyType.zig").EnemyType;
const MapRenderer = @import("MapRenderer.zig");
const WallMesher = @import("WallMesher.zig");
const MapSerializer = @import("MapSerializer.zig");
const MapLoader = @import("MapLoader.zig");
const MapRegistry = @import("MapRegistry.zig");
const RoomManager = @import("../RoomManager.zig");
const RoomType = @import("../RoomType.zig").RoomType;

const Self = @This();

pub const MIN_MAP_DIMENSION_TILES: u32 = 32;
pub const MAX_MAP_DIMENSION_TILES: u32 = 128;
pub const DIMENSION_STEP_INCREMENT_TILES: u32 = 16;
pub const DEFAULT_SPAWN_ZONE_SIZE_PIXELS: f32 = 192.0;

/// Grid coordinate in tile units.
pub const TileCoordinate = struct {
    column_index: u32,
    row_index: u32,
};

/// Compile-time metadata describing an editor sidebar category tab.
pub const CategorySpec = struct {
    tab_label: []const u8,
    default_tool: ?EditorTool = null,
    default_terrain: ?TerrainType = null,
    status_message: []const u8,
};

/// Sidebar category tabs in the map editor.
pub const EditorCategory = enum {
    terrain,
    spawners,
    entities,
    map_size,
    file_management,

    const specs = std.EnumArray(EditorCategory, CategorySpec).init(.{
        .terrain = .{
            .tab_label = "TILES",
            .default_tool = .brush_1x1,
            .default_terrain = .stone,
            .status_message = "Switched to Terrain panel",
        },
        .spawners = .{
            .tab_label = "SPAWN",
            .default_tool = .spawn_zone,
            .status_message = "Switched to Spawners panel",
        },
        .entities = .{
            .tab_label = "ENTITY",
            .default_tool = .player_spawn,
            .status_message = "Switched to Entities panel",
        },
        .map_size = .{
            .tab_label = "SIZE",
            .status_message = "Switched to Map Size panel",
        },
        .file_management = .{
            .tab_label = "FILE",
            .status_message = "Switched to File panel",
        },
    });

    /// Returns compile-time tab configuration for this category.
    pub fn spec(self: EditorCategory) CategorySpec {
        return specs.get(self);
    }
};

/// Compile-time metadata describing a canvas editing tool.
pub const ToolSpec = struct {
    category: EditorCategory,
    label: []const u8,
    brush_width_tiles: ?u32 = null,
};

/// Interactive canvas tools selectable in the editor sidebar.
pub const EditorTool = enum {
    brush_1x1,
    brush_2x2,
    brush_3x3,
    bucket_fill,
    box_fill,
    eraser,
    spawn_zone,
    spawn_zone_erase,
    player_spawn,
    exit_door,
    exit_door_erase,

    const specs = std.EnumArray(EditorTool, ToolSpec).init(.{
        .brush_1x1 = .{ .category = .terrain, .label = "Brush 1x1", .brush_width_tiles = 1 },
        .brush_2x2 = .{ .category = .terrain, .label = "Brush 2x2", .brush_width_tiles = 2 },
        .brush_3x3 = .{ .category = .terrain, .label = "Brush 3x3", .brush_width_tiles = 3 },
        .bucket_fill = .{ .category = .terrain, .label = "Bucket / Flood Fill" },
        .box_fill = .{ .category = .terrain, .label = "Rectangle Fill" },
        .eraser = .{ .category = .terrain, .label = "Eraser (Clear to Stone)" },
        .spawn_zone = .{ .category = .spawners, .label = "Place Spawn Zone (192x192)" },
        .spawn_zone_erase = .{ .category = .spawners, .label = "Remove Spawn Zone Tool" },
        .player_spawn = .{ .category = .entities, .label = "Set Player Spawn Position" },
        .exit_door = .{ .category = .entities, .label = "Place/Toggle Exit Door" },
        .exit_door_erase = .{ .category = .entities, .label = "Remove Exit Door" },
    });

    /// Returns compile-time UI and tool behavior metadata.
    pub fn spec(self: EditorTool) ToolSpec {
        return specs.get(self);
    }
};

backing_allocator: ?std.mem.Allocator = null,
map_arena: ?std.heap.ArenaAllocator = null,
renderer: MapRenderer = MapRenderer.init(),

width_tiles: u32 = MIN_MAP_DIMENSION_TILES,
height_tiles: u32 = MIN_MAP_DIMENSION_TILES,
tile_size_pixels: f32 = @floatFromInt(MapTypes.DEFAULT_TILE_SIZE_PIXELS),

background_tiles: []u8 = &.{},
walls: lm.List(WallSegment) = undefined,
spawn_zones: lm.List(SpawnZoneRecord) = undefined,
player_spawn_position: lm.Vector2 = .init(1024, 768),
exit_door_positions: lm.List(lm.Vector2) = undefined,

current_category: EditorCategory = .terrain,
current_tool: EditorTool = .brush_1x1,
selected_terrain: TerrainType = .stone,
selected_arena_category: RoomType = .normal,
selected_spawn_enemy_type: ?EnemyType = null,
show_save_popup: bool = false,

box_fill_start: ?TileCoordinate = null,

status_message: []const u8 = "Ready",
status_message_buffer: [64]u8 = undefined,
map_name_buffer: [64]u8 = undefined,
map_name_length: usize = 0,
is_dirty: bool = true,

/// Initializes document allocators, lists, and a fresh default map grid.
pub fn init(self: *Self, backing_allocator: std.mem.Allocator) !void {
    self.backing_allocator = backing_allocator;
    self.walls = lm.List(WallSegment).init(backing_allocator);
    self.spawn_zones = lm.List(SpawnZoneRecord).init(backing_allocator);
    self.exit_door_positions = lm.List(lm.Vector2).init(backing_allocator);

    const initial_name = "custom_map";
    @memcpy(self.map_name_buffer[0..initial_name.len], initial_name);
    self.map_name_length = initial_name.len;

    try self.resetMapGrid(MIN_MAP_DIMENSION_TILES, MIN_MAP_DIMENSION_TILES);
}

/// Releases all GPU textures, lists, and per-map arena allocations.
pub fn deinit(self: *Self) void {
    self.renderer.deinit();
    if (self.backing_allocator != null) {
        self.walls.deinit();
        self.spawn_zones.deinit();
        self.exit_door_positions.deinit();
    }
    if (self.map_arena) |*arena| {
        arena.deinit();
        self.map_arena = null;
    }
    self.background_tiles = &.{};
    self.backing_allocator = null;
}

/// Re-bakes the map renderer and wall segments if the canvas has pending edits.
pub fn syncDirtyVisuals(self: *Self) !void {
    if (!self.is_dirty) return;
    try self.renderer.configureDimensions(self.width_tiles, self.height_tiles, self.tile_size_pixels);
    try self.renderer.bake(self.background_tiles);
    self.regenerateWallBoundingBoxes();
    self.is_dirty = false;
}

/// Recomputes merged wall segments from the current background tile grid.
pub fn regenerateWallBoundingBoxes(self: *Self) void {
    self.walls.clearRetainingCapacity();
    const allocator = self.backing_allocator orelse return;
    const generated = WallMesher.generateSegmentsFromTiles(
        allocator,
        self.background_tiles,
        self.width_tiles,
        self.height_tiles,
    ) catch return;
    defer allocator.free(generated);

    for (generated) |segment| {
        self.walls.append(segment) catch break;
    }
}

/// Resets the document to an empty walled arena of the given tile dimensions.
pub fn resetMapGrid(self: *Self, new_width_tiles: u32, new_height_tiles: u32) !void {
    const allocator = self.backing_allocator orelse return error.MissingAllocator;

    var fresh_arena = std.heap.ArenaAllocator.init(allocator);
    errdefer fresh_arena.deinit();

    const total_tile_count = new_width_tiles * new_height_tiles;
    const new_tiles = try fresh_arena.allocator().alloc(u8, total_tile_count);
    @memset(new_tiles, @intFromEnum(TerrainType.stone));

    if (self.map_arena) |*old_arena| {
        old_arena.deinit();
    }
    self.map_arena = fresh_arena;
    self.background_tiles = new_tiles;
    self.width_tiles = new_width_tiles;
    self.height_tiles = new_height_tiles;

    self.walls.clearRetainingCapacity();
    self.spawn_zones.clearRetainingCapacity();
    self.exit_door_positions.clearRetainingCapacity();

    const tile_size = MapTypes.DEFAULT_TILE_SIZE_PIXELS;
    self.player_spawn_position = lm.Vec2(
        @as(f32, @floatFromInt(self.width_tiles * tile_size)) / 2.0,
        @as(f32, @floatFromInt(self.height_tiles * tile_size)) / 2.0,
    );
    self.exit_door_positions.append(lm.Vec2(
        @as(f32, @floatFromInt(self.width_tiles * tile_size)) / 2.0,
        160.0,
    )) catch {};

    self.generatePerimeterWalls();
    self.is_dirty = true;
    self.status_message = "Reset to new map";
}

/// Steps a map dimension up or down aligned to DIMENSION_STEP_INCREMENT_TILES within bounds.
pub fn stepDimension(current_dimension_tiles: u32, step_direction: i32) u32 {
    if (step_direction > 0) {
        if (current_dimension_tiles >= MAX_MAP_DIMENSION_TILES) {
            return MAX_MAP_DIMENSION_TILES;
        }
        const aligned_step = (current_dimension_tiles / DIMENSION_STEP_INCREMENT_TILES + 1) * DIMENSION_STEP_INCREMENT_TILES;
        return std.math.clamp(aligned_step, MIN_MAP_DIMENSION_TILES, MAX_MAP_DIMENSION_TILES);
    }

    if (step_direction < 0) {
        if (current_dimension_tiles <= MIN_MAP_DIMENSION_TILES) {
            return MIN_MAP_DIMENSION_TILES;
        }
        const remainder = current_dimension_tiles % DIMENSION_STEP_INCREMENT_TILES;
        const aligned_step = if (remainder == 0)
            current_dimension_tiles - DIMENSION_STEP_INCREMENT_TILES
        else
            (current_dimension_tiles / DIMENSION_STEP_INCREMENT_TILES) * DIMENSION_STEP_INCREMENT_TILES;
        return std.math.clamp(aligned_step, MIN_MAP_DIMENSION_TILES, MAX_MAP_DIMENSION_TILES);
    }

    return std.math.clamp(current_dimension_tiles, MIN_MAP_DIMENSION_TILES, MAX_MAP_DIMENSION_TILES);
}

/// Clamps player spawn, exit doors, and spawn zones inside the current map pixel bounds.
pub fn clampEntitiesToBounds(self: *Self) void {
    const max_x_pixels = @as(f32, @floatFromInt(self.width_tiles)) * self.tile_size_pixels;
    const max_y_pixels = @as(f32, @floatFromInt(self.height_tiles)) * self.tile_size_pixels;
    const margin_pixels = self.tile_size_pixels;

    self.player_spawn_position.x = std.math.clamp(self.player_spawn_position.x, margin_pixels, max_x_pixels - margin_pixels);
    self.player_spawn_position.y = std.math.clamp(self.player_spawn_position.y, margin_pixels, max_y_pixels - margin_pixels);

    for (self.exit_door_positions.items()) |*door_position| {
        door_position.x = std.math.clamp(door_position.x, margin_pixels, max_x_pixels - margin_pixels);
        door_position.y = std.math.clamp(door_position.y, margin_pixels, max_y_pixels - margin_pixels);
    }

    for (self.spawn_zones.items()) |*zone| {
        const half_width_pixels = zone.width_pixels / 2.0;
        const half_height_pixels = zone.height_pixels / 2.0;
        zone.center_x_pixels = std.math.clamp(zone.center_x_pixels, half_width_pixels, max_x_pixels - half_width_pixels);
        zone.center_y_pixels = std.math.clamp(zone.center_y_pixels, half_height_pixels, max_y_pixels - half_height_pixels);
    }
}

fn copyOverlappingTiles(
    source_tiles: []const u8,
    source_width_tiles: u32,
    source_height_tiles: u32,
    destination_tiles: []u8,
    destination_width_tiles: u32,
    destination_height_tiles: u32,
) void {
    if (source_tiles.len == 0 or source_width_tiles == 0 or source_height_tiles == 0) return;

    const copy_columns_count = @min(source_width_tiles, destination_width_tiles);
    const copy_rows_count = @min(source_height_tiles, destination_height_tiles);

    var row_index: u32 = 0;
    while (row_index < copy_rows_count) : (row_index += 1) {
        const source_start_index = row_index * source_width_tiles;
        const source_end_index = source_start_index + copy_columns_count;
        const destination_start_index = row_index * destination_width_tiles;
        const destination_end_index = destination_start_index + copy_columns_count;

        @memcpy(
            destination_tiles[destination_start_index..destination_end_index],
            source_tiles[source_start_index..source_end_index],
        );
    }
}

/// Resizes the tile grid, preserving overlapping tiles and freeing the prior map arena.
pub fn resizeMapGrid(self: *Self, requested_width_tiles: u32, requested_height_tiles: u32) !void {
    const target_width_tiles = std.math.clamp(requested_width_tiles, MIN_MAP_DIMENSION_TILES, MAX_MAP_DIMENSION_TILES);
    const target_height_tiles = std.math.clamp(requested_height_tiles, MIN_MAP_DIMENSION_TILES, MAX_MAP_DIMENSION_TILES);

    if (target_width_tiles == self.width_tiles and target_height_tiles == self.height_tiles) {
        return;
    }

    const allocator = self.backing_allocator orelse return error.MissingAllocator;
    var fresh_arena = std.heap.ArenaAllocator.init(allocator);
    errdefer fresh_arena.deinit();

    const total_new_tiles = target_width_tiles * target_height_tiles;
    const new_background_tiles = try fresh_arena.allocator().alloc(u8, total_new_tiles);
    @memset(new_background_tiles, @intFromEnum(TerrainType.stone));

    copyOverlappingTiles(
        self.background_tiles,
        self.width_tiles,
        self.height_tiles,
        new_background_tiles,
        target_width_tiles,
        target_height_tiles,
    );

    if (self.map_arena) |*old_arena| {
        old_arena.deinit();
    }
    self.map_arena = fresh_arena;
    self.background_tiles = new_background_tiles;
    self.width_tiles = target_width_tiles;
    self.height_tiles = target_height_tiles;

    self.clampEntitiesToBounds();
    self.regenerateWallBoundingBoxes();
    self.is_dirty = true;
    self.status_message = std.fmt.bufPrint(
        &self.status_message_buffer,
        "Resized to {d}x{d} tiles",
        .{ self.width_tiles, self.height_tiles },
    ) catch "Map resized";
}

/// Fills all four outer border rows and columns of the map with `terrain`.
pub fn fillPerimeterTiles(self: *Self, terrain: TerrainType) void {
    if (self.width_tiles == 0 or self.height_tiles == 0) return;
    const terrain_value = @intFromEnum(terrain);

    for (0..self.width_tiles) |column_index| {
        self.background_tiles[column_index] = terrain_value;
        const bottom_row_index = (self.height_tiles - 1) * self.width_tiles + column_index;
        self.background_tiles[bottom_row_index] = terrain_value;
    }

    for (1..self.height_tiles - 1) |row_index| {
        self.background_tiles[row_index * self.width_tiles] = terrain_value;
        self.background_tiles[row_index * self.width_tiles + (self.width_tiles - 1)] = terrain_value;
    }

    self.is_dirty = true;
}

/// Fills the map perimeter with the currently selected wall terrain (defaulting to solid wall).
pub fn generatePerimeterWalls(self: *Self) void {
    const perimeter_terrain = if (self.selected_terrain.isWall()) self.selected_terrain else TerrainType.wall_top;
    self.fillPerimeterTiles(perimeter_terrain);
    self.status_message = "Perimeter walls generated";
}

/// Clears the map perimeter back to stone floor tiles.
pub fn clearPerimeterWalls(self: *Self) void {
    self.fillPerimeterTiles(.stone);
    self.status_message = "Perimeter walls cleared";
}

/// Returns the map-local pixel position of the center of the given tile coordinate.
pub fn tileCenterPixels(self: *const Self, column_index: u32, row_index: u32) lm.Vector2 {
    return lm.Vec2(
        (@as(f32, @floatFromInt(column_index)) + 0.5) * self.tile_size_pixels,
        (@as(f32, @floatFromInt(row_index)) + 0.5) * self.tile_size_pixels,
    );
}

/// Returns the world-space top-left pixel origin used to center the map at (0, 0).
pub fn getTopLeftPosition(self: *const Self) lm.Vector2 {
    const total_width_pixels = @as(f32, @floatFromInt(self.width_tiles)) * self.tile_size_pixels;
    const total_height_pixels = @as(f32, @floatFromInt(self.height_tiles)) * self.tile_size_pixels;
    return lm.Vec2(-total_width_pixels / 2.0, -total_height_pixels / 2.0);
}

/// Switches the active sidebar category and selects its default tool when defined.
pub fn selectCategory(self: *Self, category: EditorCategory) void {
    self.current_category = category;
    const category_spec = category.spec();
    if (category_spec.default_tool) |default_tool| {
        self.current_tool = default_tool;
    }
    if (category_spec.default_terrain) |default_terrain| {
        self.selected_terrain = default_terrain;
    }
    self.status_message = category_spec.status_message;
}

/// Paints a single tile if within map bounds and marks the document dirty on change.
pub fn paintTile(self: *Self, column_index: u32, row_index: u32, terrain_value: u8) void {
    if (column_index >= self.width_tiles or row_index >= self.height_tiles) return;
    const tile_index = row_index * self.width_tiles + column_index;
    if (self.background_tiles[tile_index] != terrain_value) {
        self.background_tiles[tile_index] = terrain_value;
        self.is_dirty = true;
    }
}

/// Paints a square brush footprint centered on the target tile.
pub fn paintBrush(self: *Self, center_column: u32, center_row: u32, brush_width_tiles: u32) void {
    const terrain_value = @intFromEnum(self.selected_terrain);
    const half_width_tiles = brush_width_tiles / 2;

    var row_offset: u32 = 0;
    while (row_offset < brush_width_tiles) : (row_offset += 1) {
        if (center_row + row_offset < half_width_tiles) continue;
        const target_row = center_row + row_offset - half_width_tiles;
        if (target_row >= self.height_tiles) continue;

        var column_offset: u32 = 0;
        while (column_offset < brush_width_tiles) : (column_offset += 1) {
            if (center_column + column_offset < half_width_tiles) continue;
            const target_column = center_column + column_offset - half_width_tiles;
            if (target_column >= self.width_tiles) continue;

            self.paintTile(target_column, target_row, terrain_value);
        }
    }
}

fn tryEnqueueFillNeighbor(
    self: *Self,
    queue: *lm.List(TileCoordinate),
    next_x_tiles: i32,
    next_y_tiles: i32,
    target_value: u8,
    replacement_value: u8,
) void {
    if (next_x_tiles < 0 or next_y_tiles < 0) return;
    const next_column = @as(u32, @intCast(next_x_tiles));
    const next_row = @as(u32, @intCast(next_y_tiles));

    if (next_column >= self.width_tiles or next_row >= self.height_tiles) return;
    const next_index = next_row * self.width_tiles + next_column;
    if (self.background_tiles[next_index] != target_value) return;

    self.background_tiles[next_index] = replacement_value;
    queue.append(.{ .column_index = next_column, .row_index = next_row }) catch {};
}

/// Performs a 4-connected flood fill starting from the specified tile coordinate.
pub fn bucketFill(self: *Self, start_column: u32, start_row: u32, replacement_value: u8) void {
    if (start_column >= self.width_tiles or start_row >= self.height_tiles) return;
    const start_index = start_row * self.width_tiles + start_column;
    const target_value = self.background_tiles[start_index];
    if (target_value == replacement_value) return;

    const allocator = self.backing_allocator orelse lm.allocators.generic();
    var queue = lm.List(TileCoordinate).init(allocator);
    defer queue.deinit();

    queue.append(.{ .column_index = start_column, .row_index = start_row }) catch return;
    self.background_tiles[start_index] = replacement_value;

    const cardinal_offsets = [4]struct { delta_x: i32, delta_y: i32 }{
        .{ .delta_x = 1, .delta_y = 0 },
        .{ .delta_x = -1, .delta_y = 0 },
        .{ .delta_x = 0, .delta_y = 1 },
        .{ .delta_x = 0, .delta_y = -1 },
    };

    while (queue.len() > 0) {
        const current_cell = queue.pop() orelse break;
        for (cardinal_offsets) |offset| {
            const next_x_tiles = @as(i32, @intCast(current_cell.column_index)) + offset.delta_x;
            const next_y_tiles = @as(i32, @intCast(current_cell.row_index)) + offset.delta_y;
            self.tryEnqueueFillNeighbor(&queue, next_x_tiles, next_y_tiles, target_value, replacement_value);
        }
    }

    self.is_dirty = true;
    self.status_message = "Flood fill completed";
}

/// Fills a rectangular tile region from `box_fill_start` to the release tile coordinate.
pub fn commitBoxFill(self: *Self, end_column: u32, end_row: u32) void {
    const start = self.box_fill_start orelse return;
    const min_column = @min(start.column_index, end_column);
    const max_column = @max(start.column_index, end_column);
    const min_row = @min(start.row_index, end_row);
    const max_row = @max(start.row_index, end_row);

    const terrain_value = @intFromEnum(self.selected_terrain);
    var fill_row_index = min_row;
    while (fill_row_index <= max_row) : (fill_row_index += 1) {
        var fill_column_index = min_column;
        while (fill_column_index <= max_column) : (fill_column_index += 1) {
            self.paintTile(fill_column_index, fill_row_index, terrain_value);
        }
    }
    self.box_fill_start = null;
    self.status_message = "Box fill completed";
}

/// Finds the topmost spawn zone containing `relative_position_pixels`.
pub fn findSpawnZoneIndexAtPosition(self: *const Self, relative_position_pixels: lm.Vector2) ?usize {
    var zone_index: usize = self.spawn_zones.len();
    while (zone_index > 0) {
        zone_index -= 1;
        const zone = self.spawn_zones.items()[zone_index];
        if (zone.contains(relative_position_pixels)) {
            return zone_index;
        }
    }
    return null;
}

/// Removes the spawn zone under `relative_position_pixels` if one exists.
pub fn removeSpawnZoneAt(self: *Self, relative_position_pixels: lm.Vector2) bool {
    const zone_index = self.findSpawnZoneIndexAtPosition(relative_position_pixels) orelse return false;
    _ = self.spawn_zones.orderedRemove(zone_index);
    self.is_dirty = true;
    self.status_message = "Spawn zone removed";
    return true;
}

/// Removes the spawn zone covering the center of the given tile coordinate.
pub fn removeSpawnZoneAtTile(self: *Self, column_index: u32, row_index: u32) bool {
    return self.removeSpawnZoneAt(self.tileCenterPixels(column_index, row_index));
}

/// Places a new spawn zone or updates an existing zone's target enemy archetype at the tile center.
pub fn placeSpawnZone(self: *Self, column_index: u32, row_index: u32) void {
    const center_pixels = self.tileCenterPixels(column_index, row_index);

    for (self.spawn_zones.items()) |*existing_zone| {
        if (existing_zone.contains(center_pixels)) {
            existing_zone.enemy_type = self.selected_spawn_enemy_type;
            self.status_message = "Spawn zone archetype updated";
            self.is_dirty = true;
            return;
        }
    }

    self.spawn_zones.append(SpawnZoneRecord{
        .center_x_pixels = center_pixels.x,
        .center_y_pixels = center_pixels.y,
        .width_pixels = DEFAULT_SPAWN_ZONE_SIZE_PIXELS,
        .height_pixels = DEFAULT_SPAWN_ZONE_SIZE_PIXELS,
        .enemy_type = self.selected_spawn_enemy_type,
    }) catch return;

    self.status_message = "Spawn zone (192x192) placed";
    self.is_dirty = true;
}

/// Finds an exit door marker within half a tile of `relative_position_pixels`.
pub fn findExitDoorIndexAtPosition(self: *const Self, relative_position_pixels: lm.Vector2) ?usize {
    const half_tile_pixels = self.tile_size_pixels * 0.5;
    const threshold_squared_pixels: f32 = half_tile_pixels * half_tile_pixels;
    for (self.exit_door_positions.items(), 0..) |position, door_index| {
        const delta_x_pixels = position.x - relative_position_pixels.x;
        const delta_y_pixels = position.y - relative_position_pixels.y;
        const distance_squared_pixels = delta_x_pixels * delta_x_pixels + delta_y_pixels * delta_y_pixels;
        if (distance_squared_pixels <= threshold_squared_pixels) {
            return door_index;
        }
    }
    return null;
}

/// Places an exit door at the tile center, or removes it if already present there.
pub fn toggleExitDoorAtTile(self: *Self, column_index: u32, row_index: u32) void {
    const target_position = self.tileCenterPixels(column_index, row_index);
    if (self.findExitDoorIndexAtPosition(target_position)) |existing_index| {
        _ = self.exit_door_positions.swapRemove(existing_index);
        self.status_message = "Exit door removed";
        return;
    }

    self.exit_door_positions.append(target_position) catch {
        self.status_message = "Failed to add exit door";
        return;
    };
    self.status_message = "Exit door placed";
}

/// Removes any exit door located at the given tile center.
pub fn eraseExitDoorAtTile(self: *Self, column_index: u32, row_index: u32) void {
    const target_position = self.tileCenterPixels(column_index, row_index);
    const existing_index = self.findExitDoorIndexAtPosition(target_position) orelse return;
    _ = self.exit_door_positions.swapRemove(existing_index);
    self.status_message = "Exit door erased";
}

/// Infers the room type from placed boss/mini-boss spawn zones, falling back to `selected_arena_category`.
pub fn detectCanvasRoomType(self: *const Self) RoomType {
    var detected_room_type: ?RoomType = null;
    for (self.spawn_zones.items()) |zone| {
        const enemy_type = zone.enemy_type orelse continue;
        switch (enemy_type) {
            .boss, .king, .queen => return .boss,
            .knight, .bishop, .mini_boss => detected_room_type = .mini_boss,
            else => {},
        }
    }
    return detected_room_type orelse self.selected_arena_category;
}

/// Builds a MapData payload backed by `allocator` for serialization or playtest override.
pub fn buildMapData(self: *const Self, allocator: std.mem.Allocator, fallback_name: []const u8) !MapData {
    var entities_list = lm.List(EntityRecord).init(allocator);
    try entities_list.append(.{
        .entity_type = "player_spawn",
        .position_x = self.player_spawn_position.x,
        .position_y = self.player_spawn_position.y,
    });

    for (self.exit_door_positions.items()) |door_position| {
        try entities_list.append(.{
            .entity_type = "exit_door",
            .position_x = door_position.x,
            .position_y = door_position.y,
        });
    }

    const active_name = if (self.map_name_length > 0)
        self.map_name_buffer[0..self.map_name_length]
    else
        fallback_name;

    return MapData{
        .version = 1,
        .name = try allocator.dupe(u8, active_name),
        .width_tiles = self.width_tiles,
        .height_tiles = self.height_tiles,
        .tile_size_pixels = MapTypes.DEFAULT_TILE_SIZE_PIXELS,
        .background_tiles = self.background_tiles,
        .walls = self.walls.items(),
        .spawn_zones = self.spawn_zones.items(),
        .entities = try entities_list.toOwnedSlice(),
    };
}

/// Serializes and saves the current canvas map to `assets/maps/<category>/<name>.json`.
pub fn confirmSaveMap(self: *Self) void {
    if (self.map_name_length == 0) {
        self.status_message = "Map name cannot be empty";
        return;
    }

    const backing_allocator = self.backing_allocator orelse return;
    var save_arena = std.heap.ArenaAllocator.init(backing_allocator);
    defer save_arena.deinit();
    const arena_allocator = save_arena.allocator();

    const map_data = self.buildMapData(arena_allocator, "custom_map") catch {
        self.status_message = "Failed to build map data";
        return;
    };

    const path_string = std.fmt.allocPrint(
        arena_allocator,
        "maps/{s}/{s}.json",
        .{ self.selected_arena_category.directoryCategory(), map_data.name },
    ) catch return;

    MapSerializer.saveToFile(arena_allocator, path_string, map_data) catch |save_error| {
        std.log.err("Failed to save map to {s}: {any}", .{ path_string, save_error });
        self.status_message = "Failed to save map";
        return;
    };

    self.is_dirty = false;
    self.show_save_popup = false;
    self.status_message = "Map saved successfully";
}

/// Launches playtest mode for a bundled or saved map asset path.
pub fn playtestMap(self: *Self, map_path: []const u8, room_type: RoomType) void {
    _ = self;
    MapLoader.setInMemoryMapOverride(null);
    RoomManager.startPlaytest(map_path, room_type);
    lm.loadScene("demo_map") catch |load_error| {
        std.log.err("Failed to load demo_map scene for playtest: {any}", .{load_error});
    };
}

/// Launches playtest mode directly from the current canvas via an in-memory MapLoader override.
pub fn playtestCurrentCanvas(self: *Self) void {
    self.regenerateWallBoundingBoxes();

    const backing_allocator = self.backing_allocator orelse lm.allocators.generic();
    var build_arena = std.heap.ArenaAllocator.init(backing_allocator);
    defer build_arena.deinit();

    const map_data = self.buildMapData(build_arena.allocator(), "playtest_canvas") catch {
        self.status_message = "Failed to prepare playtest map";
        return;
    };

    MapLoader.setInMemoryMapOverride(map_data);
    const room_type = self.detectCanvasRoomType();
    RoomManager.startPlaytest("in_memory_playtest", room_type);
    lm.loadScene("demo_map") catch |load_error| {
        std.log.err("Failed to load demo_map scene for playtest: {any}", .{load_error});
    };
}

fn inferCategoryFromPath(path: []const u8) ?RoomType {
    inline for (std.enums.values(RoomType)) |room_type| {
        if (room_type != .tutorial) {
            const directory_segment = "/" ++ @tagName(room_type) ++ "/";
            if (std.mem.indexOf(u8, path, directory_segment) != null) {
                return room_type;
            }
        }
    }
    return null;
}

/// Loads a map file from disk into the editor document, replacing the per-map arena cleanly.
pub fn loadMapFromPath(self: *Self, path: []const u8) void {
    const allocator = self.backing_allocator orelse return;

    var fresh_arena = std.heap.ArenaAllocator.init(allocator);
    errdefer fresh_arena.deinit();

    const loaded_data = MapSerializer.loadFromFile(fresh_arena.allocator(), path) catch |load_error| {
        std.log.err("Failed to load map {s}: {any}", .{ path, load_error });
        self.status_message = "Failed to load map";
        return;
    };

    const name_length = @min(loaded_data.name.len, self.map_name_buffer.len);
    @memcpy(self.map_name_buffer[0..name_length], loaded_data.name[0..name_length]);
    self.map_name_length = name_length;

    if (inferCategoryFromPath(path)) |inferred_category| {
        self.selected_arena_category = inferred_category;
    }

    if (self.map_arena) |*old_arena| {
        old_arena.deinit();
    }
    self.map_arena = fresh_arena;
    self.width_tiles = loaded_data.width_tiles;
    self.height_tiles = loaded_data.height_tiles;
    self.background_tiles = loaded_data.background_tiles;

    MapLoader.applyWallSegmentsToTiles(
        self.background_tiles,
        self.width_tiles,
        self.height_tiles,
        loaded_data.walls,
    );

    self.regenerateWallBoundingBoxes();

    self.spawn_zones.clearRetainingCapacity();
    for (loaded_data.spawn_zones) |zone| {
        self.spawn_zones.append(zone) catch break;
    }

    self.exit_door_positions.clearRetainingCapacity();
    for (loaded_data.entities) |entity_record| {
        if (std.mem.eql(u8, entity_record.entity_type, "player_spawn")) {
            self.player_spawn_position = lm.Vec2(entity_record.position_x, entity_record.position_y);
        } else if (std.mem.eql(u8, entity_record.entity_type, "exit_door")) {
            self.exit_door_positions.append(lm.Vec2(entity_record.position_x, entity_record.position_y)) catch break;
        }
    }

    self.is_dirty = true;
    self.status_message = "Map loaded";
}

test "MapEditorDocument generatePerimeterWalls and clearPerimeterWalls" {
    var document = Self{};
    document.width_tiles = 4;
    document.height_tiles = 4;
    const total_tile_count: usize = 16;

    var tiles: [total_tile_count]u8 = @splat(0);
    document.background_tiles = &tiles;

    document.generatePerimeterWalls();

    const wall_value = @intFromEnum(TerrainType.wall_top);
    try std.testing.expectEqual(wall_value, document.background_tiles[0]);
    try std.testing.expectEqual(wall_value, document.background_tiles[3]);
    try std.testing.expectEqual(wall_value, document.background_tiles[12]);
    try std.testing.expectEqual(wall_value, document.background_tiles[15]);
    try std.testing.expectEqual(@as(u8, 0), document.background_tiles[5]);

    document.clearPerimeterWalls();
    try std.testing.expectEqual(@as(u8, 0), document.background_tiles[0]);
    try std.testing.expectEqual(@as(u8, 0), document.background_tiles[15]);

    document.selected_terrain = .royale_wall_top;
    document.generatePerimeterWalls();
    const royale_wall_value = @intFromEnum(TerrainType.royale_wall_top);
    try std.testing.expectEqual(royale_wall_value, document.background_tiles[0]);
    try std.testing.expectEqual(royale_wall_value, document.background_tiles[3]);
    try std.testing.expectEqual(royale_wall_value, document.background_tiles[12]);
    try std.testing.expectEqual(royale_wall_value, document.background_tiles[15]);
}

test "MapEditorDocument removeSpawnZoneAt targeted deletion" {
    var document = Self{};
    document.spawn_zones = lm.List(SpawnZoneRecord).init(std.testing.allocator);
    defer document.spawn_zones.deinit();

    try document.spawn_zones.append(.{
        .center_x_pixels = 300.0,
        .center_y_pixels = 300.0,
        .width_pixels = 192.0,
        .height_pixels = 192.0,
    });
    try document.spawn_zones.append(.{
        .center_x_pixels = 800.0,
        .center_y_pixels = 600.0,
        .width_pixels = 192.0,
        .height_pixels = 192.0,
    });

    try std.testing.expectEqual(@as(usize, 2), document.spawn_zones.len());

    try std.testing.expectEqual(false, document.removeSpawnZoneAt(lm.Vec2(50.0, 50.0)));
    try std.testing.expectEqual(@as(usize, 2), document.spawn_zones.len());

    try std.testing.expectEqual(true, document.removeSpawnZoneAt(lm.Vec2(320.0, 280.0)));
    try std.testing.expectEqual(@as(usize, 1), document.spawn_zones.len());
    try std.testing.expectEqual(@as(f32, 800.0), document.spawn_zones.items()[0].center_x_pixels);

    try std.testing.expectEqual(true, document.removeSpawnZoneAtTile(12, 9));
    try std.testing.expectEqual(@as(usize, 0), document.spawn_zones.len());
}

test "MapEditorDocument placeSpawnZone sets and updates archetype" {
    var document = Self{};
    document.spawn_zones = lm.List(SpawnZoneRecord).init(std.testing.allocator);
    defer document.spawn_zones.deinit();

    document.selected_spawn_enemy_type = .ranged;
    document.placeSpawnZone(2, 2);

    try std.testing.expectEqual(@as(usize, 1), document.spawn_zones.len());
    try std.testing.expectEqual(EnemyType.ranged, document.spawn_zones.items()[0].enemy_type.?);

    document.selected_spawn_enemy_type = .tank;
    document.placeSpawnZone(2, 2);

    try std.testing.expectEqual(@as(usize, 1), document.spawn_zones.len());
    try std.testing.expectEqual(EnemyType.tank, document.spawn_zones.items()[0].enemy_type.?);
}

test "MapEditorDocument detectCanvasRoomType detects boss and miniboss zones" {
    var document = Self{};
    document.spawn_zones = lm.List(SpawnZoneRecord).init(std.testing.allocator);
    defer document.spawn_zones.deinit();

    document.selected_arena_category = .normal;
    try std.testing.expectEqual(RoomType.normal, document.detectCanvasRoomType());

    try document.spawn_zones.append(.{
        .center_x_pixels = 0,
        .center_y_pixels = 0,
        .width_pixels = 64,
        .height_pixels = 64,
        .enemy_type = .knight,
    });
    try std.testing.expectEqual(RoomType.mini_boss, document.detectCanvasRoomType());

    try document.spawn_zones.append(.{
        .center_x_pixels = 0,
        .center_y_pixels = 0,
        .width_pixels = 64,
        .height_pixels = 64,
        .enemy_type = .queen,
    });
    try std.testing.expectEqual(RoomType.boss, document.detectCanvasRoomType());
}

test "MapEditorDocument stepDimension stepping within bounds and increment of 16" {
    try std.testing.expectEqual(@as(u32, 32), stepDimension(32, -1));
    try std.testing.expectEqual(@as(u32, 48), stepDimension(32, 1));
    try std.testing.expectEqual(@as(u32, 64), stepDimension(48, 1));
    try std.testing.expectEqual(@as(u32, 128), stepDimension(112, 1));
    try std.testing.expectEqual(@as(u32, 128), stepDimension(128, 1));
    try std.testing.expectEqual(@as(u32, 112), stepDimension(128, -1));

    try std.testing.expectEqual(@as(u32, 32), stepDimension(24, 1));
    try std.testing.expectEqual(@as(u32, 32), stepDimension(24, -1));
    try std.testing.expectEqual(@as(u32, 48), stepDimension(40, 1));
    try std.testing.expectEqual(@as(u32, 32), stepDimension(40, -1));
}

test "MapEditorDocument resizeMapGrid copies tiles, frees old arena, and clamps entities" {
    var document = Self{};
    try document.init(std.testing.allocator);
    defer document.deinit();

    const test_wall_value = @intFromEnum(TerrainType.wall_top);
    document.background_tiles[5 * 32 + 5] = test_wall_value;
    document.player_spawn_position = lm.Vec2(1000.0, 1000.0);

    try document.spawn_zones.append(.{
        .center_x_pixels = 1500.0,
        .center_y_pixels = 1500.0,
        .width_pixels = 192.0,
        .height_pixels = 192.0,
    });
    try document.exit_door_positions.append(lm.Vec2(1800.0, 1800.0));

    try document.resizeMapGrid(48, 48);

    try std.testing.expectEqual(@as(u32, 48), document.width_tiles);
    try std.testing.expectEqual(@as(u32, 48), document.height_tiles);
    try std.testing.expectEqual(test_wall_value, document.background_tiles[5 * 48 + 5]);
    try std.testing.expectEqual(@intFromEnum(TerrainType.stone), document.background_tiles[35 * 48 + 35]);

    try std.testing.expectEqual(@as(f32, 1000.0), document.player_spawn_position.x);
    try std.testing.expectEqual(@as(f32, 1000.0), document.player_spawn_position.y);
    try std.testing.expectEqual(@as(f32, 1500.0), document.spawn_zones.items()[0].center_x_pixels);
    try std.testing.expectEqual(@as(f32, 1800.0), document.exit_door_positions.items()[1].x);

    document.player_spawn_position = lm.Vec2(2900.0, 2900.0);
    document.spawn_zones.items()[0].center_x_pixels = 2800.0;
    document.spawn_zones.items()[0].center_y_pixels = 2800.0;
    document.exit_door_positions.items()[1] = lm.Vec2(2900.0, 2900.0);

    try document.resizeMapGrid(32, 32);

    const max_pixel_boundary: f32 = 32.0 * 64.0;
    try std.testing.expect(document.player_spawn_position.x <= max_pixel_boundary - 64.0);
    try std.testing.expect(document.player_spawn_position.y <= max_pixel_boundary - 64.0);
    try std.testing.expect(document.exit_door_positions.items()[1].x <= max_pixel_boundary - 64.0);
    try std.testing.expect(document.spawn_zones.items()[0].center_x_pixels <= max_pixel_boundary - 96.0);
}
