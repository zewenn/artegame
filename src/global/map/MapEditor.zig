const std = @import("std");
const lm = @import("loom");
const rl = lm.deps.rl;
const ui = lm.ui;
const clay = lm.deps.clay;

const MapTypes = @import("MapTypes.zig");
const TerrainType = MapTypes.TerrainType;
const WallType = MapTypes.WallType;
const WallSegment = MapTypes.WallSegment;
const SpawnZoneRecord = MapTypes.SpawnZoneRecord;
const EntityRecord = MapTypes.EntityRecord;
const MapData = MapTypes.MapData;
const MapRenderer = @import("MapRenderer.zig");
const WallMesher = @import("WallMesher.zig");
const MapSerializer = @import("MapSerializer.zig");
const MapLoader = @import("MapLoader.zig");

const Self = @This();

var active_editor_instance: ?*Self = null;

pub const EditorCategory = enum {
    terrain,
    spawners,
    entities,
    file_management,
};

pub const ArenaCategory = enum {
    normal,
    mini_boss,
    boss,

    pub fn directoryName(self: ArenaCategory) []const u8 {
        return switch (self) {
            .normal => "normal",
            .mini_boss => "mini_boss",
            .boss => "boss",
        };
    }

    pub fn displayName(self: ArenaCategory) []const u8 {
        return switch (self) {
            .normal => "Normal",
            .mini_boss => "Mini-Boss",
            .boss => "Boss",
        };
    }
};

pub const EditorTool = enum {
    brush_1x1,
    brush_2x2,
    brush_3x3,
    bucket_fill,
    box_fill,
    spawn_zone,
    spawn_zone_erase,
    player_spawn,
    exit_door,
    eraser,
};

// Global Behaviour fields
arena: ?std.heap.ArenaAllocator = null,
allocator: ?std.mem.Allocator = null,

camera: ?*lm.Camera = null,
renderer: MapRenderer = MapRenderer.init(),

width_tiles: u32 = 32,
height_tiles: u32 = 24,
tile_size_pixels: f32 = 64.0,

background_tiles: []u8 = &.{},
walls: lm.List(WallSegment) = undefined,
spawn_zones: lm.List(SpawnZoneRecord) = undefined,
player_spawn_position: lm.Vector2 = .init(1024, 768),
exit_door_position: lm.Vector2 = .init(1024, 160),

current_category: EditorCategory = .terrain,
current_tool: EditorTool = .brush_1x1,
selected_terrain: TerrainType = .stone,
selected_arena_category: ArenaCategory = .normal,
show_save_popup: bool = false,

box_fill_start: ?struct { column_index: u32, row_index: u32 } = null,

pan_drag_start: ?lm.Vector2 = null,
initial_camera_target: lm.Vector2 = .init(0, 0),

status_message: []const u8 = "Ready",
map_name_buffer: [64]u8 = undefined,
map_name_length: usize = 0,
display_name_buffer: [80]u8 = undefined,
preview_path_buffer: [128]u8 = undefined,
zoom_text_buffer: [32]u8 = undefined,
is_dirty: bool = true,

pub fn Awake(self: *Self) !void {
    active_editor_instance = self;
    self.arena = std.heap.ArenaAllocator.init(lm.allocators.generic());
    self.allocator = self.arena.?.allocator();

    self.walls = lm.List(WallSegment).init(lm.allocators.generic());
    self.spawn_zones = lm.List(SpawnZoneRecord).init(lm.allocators.generic());

    const initial_name = "custom_map";
    @memcpy(self.map_name_buffer[0..initial_name.len], initial_name);
    self.map_name_length = initial_name.len;

    try self.resetMapGrid(32, 24);
}

pub fn Start(self: *Self) void {
    self.camera = lm.activeScene().?.getCameraById("main");
    if (self.camera) |active_camera| {
        active_camera.draw_mode = .custom;
        active_camera.draw_fn = &drawCanvasCustom;
        active_camera.target = .init(0, 0);
        const window_size = lm.window.size.get();
        active_camera.offset = lm.Vec2(
            320.0 + (window_size.x - 320.0) / 2.0,
            window_size.y / 2.0,
        );
        active_camera.zoom = 0.65;
        active_camera.camera.offset = active_camera.offset;
        active_camera.camera.target = active_camera.target;
        active_camera.camera.zoom = active_camera.zoom;
    }
}

pub fn Update(self: *Self) !void {
    if (self.is_dirty) {
        try self.renderer.configureDimensions(self.width_tiles, self.height_tiles, self.tile_size_pixels);
        try self.renderer.bake(self.background_tiles);
        self.regenerateWallBoundingBoxes();
        self.is_dirty = false;
    }

    self.handleCameraControls();
    self.handleCanvasInteraction();

    const window_size = lm.window.size.get();
    self.drawEditorUi(window_size);
}

pub fn regenerateWallBoundingBoxes(self: *Self) void {
    self.walls.clearRetainingCapacity();
    const alloc = self.allocator orelse return;
    const generated = WallMesher.generateSegmentsFromTiles(alloc, self.background_tiles, self.width_tiles, self.height_tiles) catch return;
    defer alloc.free(generated);
    for (generated) |segment| {
        self.walls.append(segment) catch break;
    }
}

pub fn End(self: *Self) void {
    if (active_editor_instance == self) {
        active_editor_instance = null;
    }
    self.renderer.deinit();
    self.walls.deinit();
    self.spawn_zones.deinit();
    if (self.allocator) |alloc| {
        alloc.free(self.background_tiles);
    }
    if (self.arena) |*arena| {
        arena.deinit();
    }
    self.arena = null;
    self.allocator = null;
}

pub fn drawCanvasCustom() anyerror!void {
    const self = active_editor_instance orelse return;
    const top_left_position = self.getTopLeftPosition();
    self.renderer.drawDirect(top_left_position);
    self.drawCanvasOverlays(top_left_position);
}

// --------------------------------------------------------------------------------------------------
// Map Grid & Geometry Management
// --------------------------------------------------------------------------------------------------

pub fn resetMapGrid(self: *Self, new_width_tiles: u32, new_height_tiles: u32) !void {
    const alloc = self.allocator orelse return;
    if (self.background_tiles.len > 0) {
        alloc.free(self.background_tiles);
    }

    self.width_tiles = new_width_tiles;
    self.height_tiles = new_height_tiles;

    const total_tile_count = self.width_tiles * self.height_tiles;
    self.background_tiles = try alloc.alloc(u8, total_tile_count);
    @memset(self.background_tiles, @intFromEnum(TerrainType.stone));

    self.walls.clearRetainingCapacity();
    self.spawn_zones.clearRetainingCapacity();

    self.player_spawn_position = lm.Vec2(
        @as(f32, @floatFromInt(self.width_tiles * 64)) / 2.0,
        @as(f32, @floatFromInt(self.height_tiles * 64)) / 2.0,
    );
    self.exit_door_position = lm.Vec2(
        @as(f32, @floatFromInt(self.width_tiles * 64)) / 2.0,
        160.0,
    );

    self.generatePerimeterWalls();
    self.is_dirty = true;
    self.status_message = "Reset to new map";
}

pub fn generatePerimeterWalls(self: *Self) void {
    if (self.width_tiles == 0 or self.height_tiles == 0) return;
    const wall_value = @intFromEnum(TerrainType.wall_top);

    for (0..self.width_tiles) |column_index| {
        self.background_tiles[column_index] = wall_value;
        const bottom_row_index = (self.height_tiles - 1) * self.width_tiles + column_index;
        self.background_tiles[bottom_row_index] = wall_value;
    }

    for (1..self.height_tiles - 1) |row_index| {
        self.background_tiles[row_index * self.width_tiles] = wall_value;
        self.background_tiles[row_index * self.width_tiles + (self.width_tiles - 1)] = wall_value;
    }

    self.is_dirty = true;
    self.status_message = "Perimeter walls generated";
}

pub fn clearPerimeterWalls(self: *Self) void {
    if (self.width_tiles == 0 or self.height_tiles == 0) return;
    const stone_value = @intFromEnum(TerrainType.stone);

    for (0..self.width_tiles) |column_index| {
        self.background_tiles[column_index] = stone_value;
        const bottom_row_index = (self.height_tiles - 1) * self.width_tiles + column_index;
        self.background_tiles[bottom_row_index] = stone_value;
    }

    for (1..self.height_tiles - 1) |row_index| {
        self.background_tiles[row_index * self.width_tiles] = stone_value;
        self.background_tiles[row_index * self.width_tiles + (self.width_tiles - 1)] = stone_value;
    }

    self.is_dirty = true;
    self.status_message = "Perimeter walls cleared";
}

pub fn getTopLeftPosition(self: *Self) lm.Vector2 {
    const total_width_pixels = @as(f32, @floatFromInt(self.width_tiles)) * self.tile_size_pixels;
    const total_height_pixels = @as(f32, @floatFromInt(self.height_tiles)) * self.tile_size_pixels;
    return lm.Vec2(-total_width_pixels / 2.0, -total_height_pixels / 2.0);
}

pub fn findSpawnZoneIndexAtPosition(self: *Self, relative_position: lm.Vector2) ?usize {
    var zone_index: usize = self.spawn_zones.len();
    while (zone_index > 0) {
        zone_index -= 1;
        const zone = self.spawn_zones.items()[zone_index];
        if (zone.contains(relative_position)) {
            return zone_index;
        }
    }
    return null;
}

pub fn removeSpawnZoneAt(self: *Self, relative_position: lm.Vector2) bool {
    const zone_index = self.findSpawnZoneIndexAtPosition(relative_position) orelse return false;
    _ = self.spawn_zones.orderedRemove(zone_index);
    self.is_dirty = true;
    self.status_message = "Spawn zone removed";
    return true;
}

pub fn removeSpawnZoneAtTile(self: *Self, column_index: u32, row_index: u32) bool {
    const tile_center_x = (@as(f32, @floatFromInt(column_index)) + 0.5) * self.tile_size_pixels;
    const tile_center_y = (@as(f32, @floatFromInt(row_index)) + 0.5) * self.tile_size_pixels;
    return self.removeSpawnZoneAt(lm.Vec2(tile_center_x, tile_center_y));
}

fn getRelativeMousePosition(self: *Self) ?lm.Vector2 {
    const active_camera = self.camera orelse return null;
    const mouse_screen = lm.mouse.getPosition();
    if (mouse_screen.x < 320.0) return null;

    const mouse_world = active_camera.screenToWorldPos(mouse_screen);
    const top_left = self.getTopLeftPosition();
    const relative_x = mouse_world.x - top_left.x;
    const relative_y = mouse_world.y - top_left.y;

    const canvas_width_pixels = @as(f32, @floatFromInt(self.width_tiles)) * self.tile_size_pixels;
    const canvas_height_pixels = @as(f32, @floatFromInt(self.height_tiles)) * self.tile_size_pixels;

    const is_inside_canvas = relative_x >= 0.0 and relative_y >= 0.0 and
        relative_x < canvas_width_pixels and relative_y < canvas_height_pixels;

    if (!is_inside_canvas) return null;

    return lm.Vec2(relative_x, relative_y);
}

fn getHoveredTile(self: *Self) ?struct { column_index: u32, row_index: u32 } {
    const relative_position = self.getRelativeMousePosition() orelse return null;
    return .{
        .column_index = @intFromFloat(relative_position.x / self.tile_size_pixels),
        .row_index = @intFromFloat(relative_position.y / self.tile_size_pixels),
    };
}

// --------------------------------------------------------------------------------------------------
// Camera & Interaction
// --------------------------------------------------------------------------------------------------

fn handleCameraControls(self: *Self) void {
    if (self.show_save_popup) return;
    const active_camera = self.camera orelse return;
    const window_size = lm.window.size.get();
    active_camera.offset = lm.Vec2(
        320.0 + (window_size.x - 320.0) / 2.0,
        window_size.y / 2.0,
    );

    const delta_time = lm.time.deltaTime();

    // Mouse wheel zoom (exponential scaling)
    const wheel_move = rl.getMouseWheelMove();
    if (wheel_move != 0.0) {
        const zoom_factor = std.math.pow(f32, 1.15, wheel_move);
        active_camera.zoom = std.math.clamp(active_camera.zoom * zoom_factor, 0.15, 4.0);
    }

    // Keyboard zoom controls: Equal/Plus, Minus, Keypad Plus/Minus, Brackets, PageUp/Down
    const is_zoom_in = lm.keyboard.getKey(.equal) or
        lm.keyboard.getKey(.kp_add) or
        lm.keyboard.getKey(.right_bracket) or
        lm.keyboard.getKey(.page_up);

    const is_zoom_out = lm.keyboard.getKey(.minus) or
        lm.keyboard.getKey(.kp_subtract) or
        lm.keyboard.getKey(.left_bracket) or
        lm.keyboard.getKey(.page_down);

    if (is_zoom_in) {
        const zoom_multiplier = 1.0 + (1.8 * delta_time);
        active_camera.zoom = std.math.clamp(active_camera.zoom * zoom_multiplier, 0.15, 4.0);
    }
    if (is_zoom_out) {
        const zoom_divisor = 1.0 + (1.8 * delta_time);
        active_camera.zoom = std.math.clamp(active_camera.zoom / zoom_divisor, 0.15, 4.0);
    }

    // Keyboard WASD and Arrow key camera panning
    const pan_speed: f32 = 800.0 / active_camera.zoom;
    if (lm.keyboard.getKey(.w) or lm.keyboard.getKey(.up)) {
        active_camera.target.y -= pan_speed * delta_time;
    }
    if (lm.keyboard.getKey(.s) or lm.keyboard.getKey(.down)) {
        active_camera.target.y += pan_speed * delta_time;
    }
    if (lm.keyboard.getKey(.a) or lm.keyboard.getKey(.left)) {
        active_camera.target.x -= pan_speed * delta_time;
    }
    if (lm.keyboard.getKey(.d) or lm.keyboard.getKey(.right)) {
        active_camera.target.x += pan_speed * delta_time;
    }

    // Reset camera focus with R, F, or 0
    if (lm.keyboard.getKeyDown(.r) or lm.keyboard.getKeyDown(.f) or lm.keyboard.getKeyDown(.zero)) {
        active_camera.target = .init(0, 0);
        active_camera.zoom = 0.65;
        self.status_message = "Camera reset to center";
    }

    // Pan via middle mouse or right mouse drag
    const is_pan_pressed = lm.mouse.getButtonDown(.right) or lm.mouse.getButtonDown(.middle);
    const is_pan_held = lm.mouse.getButton(.right) or lm.mouse.getButton(.middle);

    if (is_pan_pressed) {
        self.pan_drag_start = lm.mouse.getPosition();
        self.initial_camera_target = active_camera.target;
    } else if (is_pan_held) {
        if (self.pan_drag_start) |drag_start| {
            const current_mouse = lm.mouse.getPosition();
            const mouse_difference = current_mouse.subtract(drag_start);
            active_camera.target = self.initial_camera_target.subtract(
                mouse_difference.divide(.init(active_camera.zoom, active_camera.zoom)),
            );
        }
    } else {
        self.pan_drag_start = null;
    }

    // Keep internal raylib Camera2D state synchronized
    active_camera.camera.offset = active_camera.offset;
    active_camera.camera.target = active_camera.target;
    active_camera.camera.zoom = active_camera.zoom;
}

fn handleCanvasInteraction(self: *Self) void {
    if (self.show_save_popup) return;
    if (self.current_category == .file_management) return;
    const hovered_tile = self.getHoveredTile() orelse return;

    if (lm.mouse.getButton(.left)) {
        self.applyToolAction(hovered_tile.column_index, hovered_tile.row_index);
    } else if (lm.mouse.getButtonUp(.left)) {
        self.commitToolAction(hovered_tile.column_index, hovered_tile.row_index);
    }
}

fn applyToolAction(self: *Self, column_index: u32, row_index: u32) void {
    switch (self.current_tool) {
        .brush_1x1 => self.paintBrush(column_index, row_index, 1),
        .brush_2x2 => self.paintBrush(column_index, row_index, 2),
        .brush_3x3 => self.paintBrush(column_index, row_index, 3),
        .eraser => self.paintTile(column_index, row_index, @intFromEnum(TerrainType.stone)),
        .spawn_zone_erase => {
            if (lm.mouse.getButtonDown(.left)) {
                if (self.getRelativeMousePosition()) |relative_position| {
                    _ = self.removeSpawnZoneAt(relative_position);
                } else {
                    _ = self.removeSpawnZoneAtTile(column_index, row_index);
                }
            }
        },
        .box_fill => {
            if (self.box_fill_start == null) {
                self.box_fill_start = .{ .column_index = column_index, .row_index = row_index };
            }
        },
        .bucket_fill => {
            if (lm.mouse.getButtonDown(.left)) {
                self.bucketFill(column_index, row_index, @intFromEnum(self.selected_terrain));
            }
        },
        .spawn_zone => {
            if (lm.mouse.getButtonDown(.left)) {
                self.placeSpawnZone(column_index, row_index);
            }
        },
        .player_spawn => {
            const snapped_x = (@as(f32, @floatFromInt(column_index)) + 0.5) * self.tile_size_pixels;
            const snapped_y = (@as(f32, @floatFromInt(row_index)) + 0.5) * self.tile_size_pixels;
            self.player_spawn_position = lm.Vec2(snapped_x, snapped_y);
            self.status_message = "Player spawn positioned";
        },
        .exit_door => {
            const snapped_x = (@as(f32, @floatFromInt(column_index)) + 0.5) * self.tile_size_pixels;
            const snapped_y = (@as(f32, @floatFromInt(row_index)) + 0.5) * self.tile_size_pixels;
            self.exit_door_position = lm.Vec2(snapped_x, snapped_y);
            self.status_message = "Exit door positioned";
        },
    }
}

fn commitToolAction(self: *Self, column_index: u32, row_index: u32) void {

    if (self.box_fill_start) |start| {
        const min_column = @min(start.column_index, column_index);
        const max_column = @max(start.column_index, column_index);
        const min_row = @min(start.row_index, row_index);
        const max_row = @max(start.row_index, row_index);

        var fill_row_index = min_row;
        while (fill_row_index <= max_row) : (fill_row_index += 1) {
            var fill_column_index = min_column;
            while (fill_column_index <= max_column) : (fill_column_index += 1) {
                self.paintTile(fill_column_index, fill_row_index, @intFromEnum(self.selected_terrain));
            }
        }
        self.box_fill_start = null;
        self.status_message = "Box fill completed";
    }
}

fn paintBrush(self: *Self, center_column: u32, center_row: u32, radius: u32) void {
    const terrain_value = @intFromEnum(self.selected_terrain);
    const half_radius = radius / 2;

    var row_offset: u32 = 0;
    while (row_offset < radius) : (row_offset += 1) {
        if (center_row + row_offset < half_radius) continue;
        const target_row = center_row + row_offset - half_radius;
        if (target_row >= self.height_tiles) continue;

        var column_offset: u32 = 0;
        while (column_offset < radius) : (column_offset += 1) {
            if (center_column + column_offset < half_radius) continue;
            const target_column = center_column + column_offset - half_radius;
            if (target_column >= self.width_tiles) continue;

            self.paintTile(target_column, target_row, terrain_value);
        }
    }
}

fn paintTile(self: *Self, column_index: u32, row_index: u32, terrain_value: u8) void {
    if (column_index >= self.width_tiles or row_index >= self.height_tiles) return;
    const tile_index = row_index * self.width_tiles + column_index;
    if (self.background_tiles[tile_index] != terrain_value) {
        self.background_tiles[tile_index] = terrain_value;
        self.is_dirty = true;
    }
}

fn bucketFill(self: *Self, start_column: u32, start_row: u32, replacement_value: u8) void {
    if (start_column >= self.width_tiles or start_row >= self.height_tiles) return;
    const start_index = start_row * self.width_tiles + start_column;
    const target_value = self.background_tiles[start_index];
    if (target_value == replacement_value) return;

    var queue = lm.List(struct { column_index: u32, row_index: u32 }).init(lm.allocators.generic());
    defer queue.deinit();

    queue.append(.{ .column_index = start_column, .row_index = start_row }) catch return;
    self.background_tiles[start_index] = replacement_value;

    while (queue.len() > 0) {
        const current_cell = queue.pop() orelse break;

        const directions = [4]struct { dx: i32, dy: i32 }{
            .{ .dx = 1, .dy = 0 },
            .{ .dx = -1, .dy = 0 },
            .{ .dx = 0, .dy = 1 },
            .{ .dx = 0, .dy = -1 },
        };

        for (directions) |direction| {
            const next_x = @as(i32, @intCast(current_cell.column_index)) + direction.dx;
            const next_y = @as(i32, @intCast(current_cell.row_index)) + direction.dy;

            if (next_x < 0 or next_y < 0) continue;
            const next_column = @as(u32, @intCast(next_x));
            const next_row = @as(u32, @intCast(next_y));

            if (next_column >= self.width_tiles or next_row >= self.height_tiles) continue;
            const next_index = next_row * self.width_tiles + next_column;

            if (self.background_tiles[next_index] == target_value) {
                self.background_tiles[next_index] = replacement_value;
                queue.append(.{ .column_index = next_column, .row_index = next_row }) catch return;
            }
        }
    }

    self.is_dirty = true;
    self.status_message = "Flood fill completed";
}

fn placeSpawnZone(self: *Self, column_index: u32, row_index: u32) void {
    const center_x = (@as(f32, @floatFromInt(column_index)) + 0.5) * self.tile_size_pixels;
    const center_y = (@as(f32, @floatFromInt(row_index)) + 0.5) * self.tile_size_pixels;

    self.spawn_zones.append(SpawnZoneRecord{
        .center_x_pixels = center_x,
        .center_y_pixels = center_y,
        .width_pixels = 192.0,
        .height_pixels = 192.0,
    }) catch return;

    self.status_message = "Spawn zone (192x192) placed";
}

// --------------------------------------------------------------------------------------------------
// Canvas Overlays & Visual Helpers
// --------------------------------------------------------------------------------------------------

fn drawCanvasOverlays(self: *Self, top_left: lm.Vector2) void {
    // 1. Grid lines overlay
    var col_index: u32 = 0;
    while (col_index <= self.width_tiles) : (col_index += 1) {
        const x_coord = top_left.x + @as(f32, @floatFromInt(col_index)) * self.tile_size_pixels;
        rl.drawLineEx(
            lm.Vec2(x_coord, top_left.y),
            lm.Vec2(x_coord, top_left.y + @as(f32, @floatFromInt(self.height_tiles)) * self.tile_size_pixels),
            1.0,
            rl.Color{ .r = 255, .g = 255, .b = 255, .a = 30 },
        );
    }

    var r_index: u32 = 0;
    while (r_index <= self.height_tiles) : (r_index += 1) {
        const y_coord = top_left.y + @as(f32, @floatFromInt(r_index)) * self.tile_size_pixels;
        rl.drawLineEx(
            lm.Vec2(top_left.x, y_coord),
            lm.Vec2(top_left.x + @as(f32, @floatFromInt(self.width_tiles)) * self.tile_size_pixels, y_coord),
            1.0,
            rl.Color{ .r = 255, .g = 255, .b = 255, .a = 30 },
        );
    }

    // 2. Wall segments overlay
    for (self.walls.items()) |wall| {
        const min_column = @min(wall.start_x_tiles, wall.end_x_tiles);
        const max_column = @max(wall.start_x_tiles, wall.end_x_tiles);
        const min_row = @min(wall.start_y_tiles, wall.end_y_tiles);
        const max_row = @max(wall.start_y_tiles, wall.end_y_tiles);

        const width_pixels = @as(f32, @floatFromInt(max_column - min_column + 1)) * self.tile_size_pixels;
        const height_pixels = @as(f32, @floatFromInt(max_row - min_row + 1)) * self.tile_size_pixels;

        const rect_x = top_left.x + @as(f32, @floatFromInt(min_column)) * self.tile_size_pixels;
        const rect_y = top_left.y + @as(f32, @floatFromInt(min_row)) * self.tile_size_pixels + WallMesher.wall_collider_vertical_offset_pixels;

        const wall_outline_color = switch (wall.wall_type) {
            .solid => rl.Color.lime,
            .low => rl.Color.sky_blue,
        };

        rl.drawRectangleLinesEx(
            lm.Rect(rect_x, rect_y, width_pixels, height_pixels),
            3.0,
            wall_outline_color,
        );
    }

    if (self.current_tool == .spawn_zone_erase) {
        self.drawSpawnZoneRemovalHighlight(top_left);
    }

    // 3. Spawn zones overlay (192x192 areas)
    for (self.spawn_zones.items(), 0..) |zone, zone_index| {
        _ = zone_index;
        const zone_x = top_left.x + zone.center_x_pixels - (zone.width_pixels / 2.0);
        const zone_y = top_left.y + zone.center_y_pixels - (zone.height_pixels / 2.0);

        rl.drawRectangleRec(
            lm.Rect(zone_x, zone_y, zone.width_pixels, zone.height_pixels),
            rl.Color{ .r = 230, .g = 40, .b = 40, .a = 60 },
        );
        rl.drawRectangleLinesEx(
            lm.Rect(zone_x, zone_y, zone.width_pixels, zone.height_pixels),
            2.0,
            rl.Color{ .r = 255, .g = 80, .b = 80, .a = 220 },
        );
    }

    // 4. Player spawn and Exit door markers
    const player_world_x = top_left.x + self.player_spawn_position.x;
    const player_world_y = top_left.y + self.player_spawn_position.y;
    rl.drawCircleV(lm.Vec2(player_world_x, player_world_y), 24.0, rl.Color.gold);
    rl.drawCircleLinesV(lm.Vec2(player_world_x, player_world_y), 26.0, rl.Color.white);

    const door_world_x = top_left.x + self.exit_door_position.x;
    const door_world_y = top_left.y + self.exit_door_position.y;
    rl.drawRectangleV(lm.Vec2(door_world_x - 32, door_world_y - 32), lm.Vec2(64, 64), rl.Color.sky_blue);
    rl.drawRectangleLinesEx(lm.Rect(door_world_x - 32, door_world_y - 32, 64, 64), 2.0, rl.Color.white);
}

// --------------------------------------------------------------------------------------------------
// Clay Side-Menu UI
// --------------------------------------------------------------------------------------------------

fn drawEditorUi(self: *Self, window_size: lm.Vector2) void {
    ui.new(.{
        .id = .ID("editor-root"),
        .floating = .{
            .attach_to = .to_root,
            .attach_points = .{ .element = .left_top, .parent = .left_top },
        },
        .layout = .{
            .sizing = .{ .w = .fixed(320.0), .h = .fixed(window_size.y) },
            .direction = .top_to_bottom,
            .padding = .all(14),
            .child_gap = 10,
        },
        .background_color = ui.color(16, 18, 26, 245),
        .border = .{ .color = ui.color(60, 68, 88, 200), .width = .outside(1) },
    })({
        // Title banner
        ui.new(.{
            .id = .ID("editor-header"),
            .layout = .{ .sizing = .{ .w = .grow }, .child_alignment = .{ .x = .center } },
        })({
            ui.text("MAP EDITOR", .{
                .color = ui.color(240, 200, 100, 255),
                .font_size = 18,
                .letter_spacing = 2,
            });
        });

        // Category Tab Switcher
        self.drawCategoryTabs();

        // Selected Category Content
        switch (self.current_category) {
            .terrain => self.drawTerrainCategory(),
            .spawners => self.drawSpawnersCategory(),
            .entities => self.drawEntitiesCategory(),
            .file_management => self.drawFileCategory(),
        }

        // Zoom controls
        self.drawZoomControls();

        // Status bar footer
        self.drawStatusBar();
    });

    if (self.show_save_popup) {
        self.handleSavePopupInput();
        self.drawSavePopup(window_size);
    }
}

fn drawCategoryTabs(self: *Self) void {
    ui.new(.{
        .id = .ID("category-tabs"),
        .layout = .{
            .direction = .left_to_right,
            .child_gap = 4,
            .child_alignment = .{ .y = .center },
        },
    })({
        self.drawCategoryButton(.terrain, "TILES");
        self.drawCategoryButton(.spawners, "SPAWN");
        self.drawCategoryButton(.entities, "ENTITY");
        self.drawCategoryButton(.file_management, "FILE");
    });
}

pub fn selectCategory(self: *Self, category: EditorCategory) void {
    self.current_category = category;
    switch (category) {
        .terrain => {
            self.current_tool = .brush_1x1;
            self.selected_terrain = .stone;
            self.status_message = "Switched to Terrain panel";
        },
        .spawners => {
            self.current_tool = .spawn_zone;
            self.status_message = "Switched to Spawners panel";
        },
        .entities => {
            self.current_tool = .player_spawn;
            self.status_message = "Switched to Entities panel";
        },
        .file_management => {
            self.status_message = "Switched to File panel";
        },
    }
}

fn drawCategoryButton(self: *Self, category: EditorCategory, label: []const u8) void {
    const is_active = (self.current_category == category);
    clay.UI()(.{
        .id = .IDI("cat-btn-", @intFromEnum(category)),
        .layout = .{
            .padding = .axes(4, 8),
            .child_alignment = .{ .x = .center, .y = .center },
        },
        .background_color = if (is_active) ui.color(240, 200, 100, 220) else ui.color(30, 36, 48, 200),
        .corner_radius = .all(4),
    })({
        if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
            self.selectCategory(category);
        }

        ui.text(label, .{
            .color = if (is_active) ui.color(10, 12, 16, 255) else ui.color(190, 200, 220, 255),
            .font_size = 10,
            .letter_spacing = 1,
        });
    });
}

fn drawTerrainCategory(self: *Self) void {
    ui.new(.{
        .id = .ID("terrain-panel"),
        .layout = .{ .direction = .top_to_bottom, .child_gap = 8 },
    })({
        ui.text("SELECT TILE:", .{
            .color = ui.color(160, 175, 200, 255),
            .font_size = 11,
            .letter_spacing = 1,
        });

        ui.new(.{
            .id = .ID("terrain-row-1"),
            .layout = .{ .direction = .left_to_right, .child_gap = 6, .sizing = .{ .w = .grow } },
        })({
            self.drawTerrainOption(.stone, "Stone");
            self.drawTerrainOption(.carpet, "Carpet");
        });

        ui.new(.{
            .id = .ID("terrain-row-2"),
            .layout = .{ .direction = .left_to_right, .child_gap = 6, .sizing = .{ .w = .grow } },
        })({
            self.drawTerrainOption(.wall_top, "Solid Wall");
            self.drawTerrainOption(.wall_low_top, "Low Wall");
        });

        ui.text("PAINT TOOLS:", .{
            .color = ui.color(160, 175, 200, 255),
            .font_size = 11,
            .letter_spacing = 1,
        });

        self.drawToolButton(.brush_1x1, "Brush 1x1");
        self.drawToolButton(.brush_2x2, "Brush 2x2");
        self.drawToolButton(.brush_3x3, "Brush 3x3");
        self.drawToolButton(.bucket_fill, "Bucket / Flood Fill");
        self.drawToolButton(.box_fill, "Rectangle Fill");
        self.drawToolButton(.eraser, "Eraser (Clear to Stone)");

        ui.text("BOUNDARY ACTIONS:", .{
            .color = ui.color(160, 175, 200, 255),
            .font_size = 11,
            .letter_spacing = 1,
        });

        clay.UI()(.{
            .id = .ID("gen-boundary-btn"),
            .layout = .{ .padding = .axes(6, 10), .sizing = .{ .w = .grow } },
            .background_color = ui.color(45, 55, 75, 220),
            .corner_radius = .all(4),
        })({
            if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
                self.generatePerimeterWalls();
            }
            ui.text("Generate Perimeter Walls", .{
                .color = ui.color(220, 230, 245, 255),
                .font_size = 12,
                .letter_spacing = 1,
            });
        });

        clay.UI()(.{
            .id = .ID("clear-boundary-btn"),
            .layout = .{ .padding = .axes(6, 10), .sizing = .{ .w = .grow } },
            .background_color = ui.color(75, 35, 40, 220),
            .corner_radius = .all(4),
        })({
            if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
                self.clearPerimeterWalls();
            }
            ui.text("Clear Perimeter Walls", .{
                .color = ui.color(255, 180, 180, 255),
                .font_size = 12,
                .letter_spacing = 1,
            });
        });
    });
}

fn capitalizedEnumFieldName(comptime EnumType: type, target_index: usize) []const u8 {
    const static_names = comptime blk: {
        const enum_fields = @typeInfo(EnumType).@"enum".fields;
        var names: [enum_fields.len][]const u8 = undefined;
        for (enum_fields, 0..) |field, field_index| {
            var character_buffer: [field.name.len]u8 = undefined;
            @memcpy(&character_buffer, field.name);
            if (character_buffer.len > 0) {
                character_buffer[0] = std.ascii.toUpper(character_buffer[0]);
            }
            const constant_slice = character_buffer;
            names[field_index] = &constant_slice;
        }
        break :blk names;
    };
    return if (target_index < static_names.len) static_names[target_index] else "";
}

fn drawTerrainOption(self: *Self, terrain: TerrainType, label: []const u8) void {
    const is_selected = (self.selected_terrain == terrain);
    clay.UI()(.{
        .id = .IDI("terrain-opt-", @intFromEnum(terrain)),
        .layout = .{ .padding = .axes(6, 10), .sizing = .{ .w = .grow }, .child_alignment = .{ .x = .center } },
        .background_color = if (is_selected) ui.color(70, 130, 220, 240) else ui.color(35, 42, 56, 200),
        .corner_radius = .all(4),
    })({
        if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
            self.selected_terrain = terrain;
            self.status_message = "Tile selected";
        }
        ui.text(label, .{
            .color = ui.color(255, 255, 255, 255),
            .font_size = 11,
            .letter_spacing = 1,
        });
    });
}

fn drawToolButton(self: *Self, tool: EditorTool, label: []const u8) void {
    const is_active = (self.current_tool == tool);
    clay.UI()(.{
        .id = .IDI("tool-btn-", @intFromEnum(tool)),
        .layout = .{ .padding = .axes(6, 10), .sizing = .{ .w = .grow } },
        .background_color = if (is_active) ui.color(240, 180, 70, 220) else ui.color(28, 34, 46, 200),
        .corner_radius = .all(4),
    })({
        if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
            self.current_tool = tool;
            self.status_message = "Tool changed";
        }
        ui.text(label, .{
            .color = if (is_active) ui.color(10, 12, 16, 255) else ui.color(200, 210, 230, 255),
            .font_size = 12,
            .letter_spacing = 1,
        });
    });
}

fn drawSpawnersCategory(self: *Self) void {
    ui.new(.{
        .id = .ID("spawners-panel"),
        .layout = .{ .direction = .top_to_bottom, .child_gap = 8 },
    })({
        self.drawToolButton(.spawn_zone, "Place Spawn Zone (192x192)");
        self.drawToolButton(.spawn_zone_erase, "Remove Spawn Zone Tool");

        clay.UI()(.{
            .id = .ID("clear-spawners-btn"),
            .layout = .{ .padding = .axes(6, 10), .sizing = .{ .w = .grow } },
            .background_color = ui.color(75, 35, 40, 220),
            .corner_radius = .all(4),
        })({
            if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
                self.spawn_zones.clearRetainingCapacity();
                self.status_message = "All spawn zones cleared";
            }
            ui.text("Clear All Spawn Zones", .{
                .color = ui.color(255, 180, 180, 255),
                .font_size = 12,
                .letter_spacing = 1,
            });
        });
    });
}

fn drawEntitiesCategory(self: *Self) void {
    ui.new(.{
        .id = .ID("entities-panel"),
        .layout = .{ .direction = .top_to_bottom, .child_gap = 8 },
    })({
        self.drawToolButton(.player_spawn, "Set Player Spawn Position");
        self.drawToolButton(.exit_door, "Set Exit Door Position");
    });
}

fn drawFileCategory(self: *Self) void {
    ui.new(.{
        .id = .ID("file-panel"),
        .layout = .{ .direction = .top_to_bottom, .child_gap = 8 },
    })({
        clay.UI()(.{
            .id = .ID("save-map-btn"),
            .layout = .{ .padding = .axes(6, 10), .sizing = .{ .w = .grow } },
            .background_color = ui.color(40, 120, 60, 230),
            .corner_radius = .all(4),
        })({
            if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
                self.show_save_popup = true;
            }
            ui.text("Save Map...", .{
                .color = ui.color(255, 255, 255, 255),
                .font_size = 12,
                .letter_spacing = 1,
            });
        });

        clay.UI()(.{
            .id = .ID("load-normal-btn"),
            .layout = .{ .padding = .axes(6, 10), .sizing = .{ .w = .grow } },
            .background_color = ui.color(35, 45, 65, 220),
            .corner_radius = .all(4),
        })({
            if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
                self.loadMapFromPath("maps/normal/arena_normal.json");
            }
            ui.text("Load Normal Arena", .{
                .color = ui.color(200, 215, 235, 255),
                .font_size = 12,
                .letter_spacing = 1,
            });
        });

        clay.UI()(.{
            .id = .ID("load-miniboss-btn"),
            .layout = .{ .padding = .axes(6, 10), .sizing = .{ .w = .grow } },
            .background_color = ui.color(35, 45, 65, 220),
            .corner_radius = .all(4),
        })({
            if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
                self.loadMapFromPath("maps/mini_boss/arena_normal.json");
            }
            ui.text("Load Mini-Boss Arena", .{
                .color = ui.color(200, 215, 235, 255),
                .font_size = 12,
                .letter_spacing = 1,
            });
        });

        clay.UI()(.{
            .id = .ID("load-boss-btn"),
            .layout = .{ .padding = .axes(6, 10), .sizing = .{ .w = .grow } },
            .background_color = ui.color(35, 45, 65, 220),
            .corner_radius = .all(4),
        })({
            if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
                self.loadMapFromPath("maps/boss/arena_boss.json");
            }
            ui.text("Load Boss Arena", .{
                .color = ui.color(200, 215, 235, 255),
                .font_size = 12,
                .letter_spacing = 1,
            });
        });

        clay.UI()(.{
            .id = .ID("load-tutorial-btn"),
            .layout = .{ .padding = .axes(6, 10), .sizing = .{ .w = .grow } },
            .background_color = ui.color(35, 45, 65, 220),
            .corner_radius = .all(4),
        })({
            if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
                self.loadMapFromPath("maps/tutorial.json");
            }
            ui.text("Load Tutorial Map", .{
                .color = ui.color(200, 215, 235, 255),
                .font_size = 12,
                .letter_spacing = 1,
            });
        });

        clay.UI()(.{
            .id = .ID("exit-menu-btn"),
            .layout = .{ .padding = .axes(6, 10), .sizing = .{ .w = .grow } },
            .background_color = ui.color(80, 35, 40, 230),
            .corner_radius = .all(4),
        })({
            if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
                lm.loadScene("main_menu") catch |err| {
                    std.log.err("Failed to return to main_menu: {any}", .{err});
                };
            }
            ui.text("Exit to Main Menu", .{
                .color = ui.color(255, 200, 200, 255),
                .font_size = 12,
                .letter_spacing = 1,
            });
        });
    });
}

fn drawZoomControls(self: *Self) void {
    const active_camera = self.camera orelse return;
    const zoom_percent: u32 = @intFromFloat(active_camera.zoom * 100.0);

    const zoom_text = std.fmt.bufPrint(&self.zoom_text_buffer, "Zoom: {d}%", .{zoom_percent}) catch "Zoom: 100%";

    ui.new(.{
        .id = .ID("zoom-controls-bar"),
        .layout = .{
            .sizing = .{ .w = .grow },
            .direction = .left_to_right,
            .child_gap = 6,
            .child_alignment = .{ .y = .center },
            .padding = .axes(4, 4),
        },
        .background_color = ui.color(24, 28, 40, 220),
        .corner_radius = .all(4),
    })({
        clay.UI()(.{
            .id = .ID("zoom-out-btn"),
            .layout = .{ .padding = .axes(6, 6) },
            .background_color = ui.color(40, 50, 70, 220),
            .corner_radius = .all(3),
        })({
            if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
                active_camera.zoom = std.math.clamp(active_camera.zoom / 1.2, 0.15, 4.0);
            }
            ui.text(" - ", .{
                .color = ui.color(220, 230, 255, 255),
                .font_size = 12,
                .letter_spacing = 1,
            });
        });

        ui.new(.{
            .id = .ID("zoom-label"),
            .layout = .{ .sizing = .{ .w = .grow }, .child_alignment = .{ .x = .center } },
        })({
            ui.text(zoom_text, .{
                .color = ui.color(200, 215, 235, 255),
                .font_size = 11,
                .letter_spacing = 1,
            });
        });

        clay.UI()(.{
            .id = .ID("zoom-in-btn"),
            .layout = .{ .padding = .axes(6, 6) },
            .background_color = ui.color(40, 50, 70, 220),
            .corner_radius = .all(3),
        })({
            if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
                active_camera.zoom = std.math.clamp(active_camera.zoom * 1.2, 0.15, 4.0);
            }
            ui.text(" + ", .{
                .color = ui.color(220, 230, 255, 255),
                .font_size = 12,
                .letter_spacing = 1,
            });
        });

        clay.UI()(.{
            .id = .ID("zoom-reset-btn"),
            .layout = .{ .padding = .axes(6, 6) },
            .background_color = ui.color(50, 40, 60, 220),
            .corner_radius = .all(3),
        })({
            if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
                active_camera.target = .init(0, 0);
                active_camera.zoom = 0.65;
            }
            ui.text("Reset", .{
                .color = ui.color(240, 200, 150, 255),
                .font_size = 11,
                .letter_spacing = 1,
            });
        });
    });
}

fn drawStatusBar(self: *Self) void {
    ui.new(.{
        .id = .ID("editor-status-bar"),
        .layout = .{ .sizing = .{ .w = .grow }, .padding = .all(6) },
        .background_color = ui.color(10, 12, 18, 255),
        .corner_radius = .all(4),
    })({
        ui.text(self.status_message, .{
            .color = ui.color(240, 200, 100, 255),
            .font_size = 11,
            .letter_spacing = 1,
        });
    });
}

pub fn confirmSaveMap(self: *Self) void {
    if (self.map_name_length == 0) {
        self.status_message = "Map name cannot be empty";
        return;
    }

    const alloc = self.allocator orelse return;

    var entities_list = lm.List(EntityRecord).init(alloc);
    defer entities_list.deinit();

    entities_list.append(EntityRecord{
        .entity_type = "player_spawn",
        .position_x = self.player_spawn_position.x,
        .position_y = self.player_spawn_position.y,
    }) catch return;

    entities_list.append(EntityRecord{
        .entity_type = "exit_door",
        .position_x = self.exit_door_position.x,
        .position_y = self.exit_door_position.y,
    }) catch return;

    const map_name = self.map_name_buffer[0..self.map_name_length];
    const map_data = MapData{
        .version = 1,
        .name = map_name,
        .width_tiles = self.width_tiles,
        .height_tiles = self.height_tiles,
        .tile_size_pixels = 64,
        .background_tiles = self.background_tiles,
        .walls = self.walls.items(),
        .spawn_zones = self.spawn_zones.items(),
        .entities = entities_list.items(),
    };

    var path_buffer: [128]u8 = undefined;
    const path_string = std.fmt.bufPrint(
        &path_buffer,
        "maps/{s}/{s}.json",
        .{ self.selected_arena_category.directoryName(), map_name },
    ) catch return;

    MapSerializer.saveToFile(alloc, path_string, map_data) catch |err| {
        std.log.err("Failed to save map to {s}: {any}", .{ path_string, err });
        self.status_message = "Failed to save map";
        return;
    };

    self.is_dirty = false;
    self.show_save_popup = false;
    self.status_message = "Map saved successfully";
}

fn handleSavePopupInput(self: *Self) void {
    var char_code = rl.getCharPressed();
    while (char_code > 0) : (char_code = rl.getCharPressed()) {
        if (self.map_name_length >= self.map_name_buffer.len - 1) break;
        if (char_code >= 32 and char_code <= 126) {
            const char_byte: u8 = @intCast(char_code);
            const is_valid_character = std.ascii.isAlphanumeric(char_byte) or char_byte == '_' or char_byte == '-';
            if (is_valid_character) {
                self.map_name_buffer[self.map_name_length] = char_byte;
                self.map_name_length += 1;
            }
        }
    }

    if (lm.keyboard.getKeyDown(rl.KeyboardKey.backspace) or lm.keyboard.getKeyDownRepeat(rl.KeyboardKey.backspace)) {
        if (self.map_name_length > 0) {
            self.map_name_length -= 1;
        }
    }

    if (lm.keyboard.getKeyDown(rl.KeyboardKey.enter)) {
        self.confirmSaveMap();
    } else if (lm.keyboard.getKeyDown(rl.KeyboardKey.escape)) {
        self.show_save_popup = false;
    }
}

fn drawCategoryChoiceButton(self: *Self, category: ArenaCategory) void {
    const is_selected = (self.selected_arena_category == category);
    clay.UI()(.{
        .id = .IDI("save-cat-opt-", @intFromEnum(category)),
        .layout = .{
            .padding = .axes(6, 10),
            .sizing = .{ .w = .grow },
            .child_alignment = .{ .x = .center },
        },
        .background_color = if (is_selected) ui.color(70, 130, 220, 240) else ui.color(32, 38, 52, 200),
        .border = .{
            .color = if (is_selected) ui.color(120, 180, 255, 255) else ui.color(50, 60, 80, 160),
            .width = .outside(1),
        },
        .corner_radius = .all(4),
    })({
        if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
            self.selected_arena_category = category;
        }
        ui.text(category.displayName(), .{
            .color = if (is_selected) ui.color(255, 255, 255, 255) else ui.color(180, 195, 215, 255),
            .font_size = 11,
            .letter_spacing = 1,
        });
    });
}

fn drawSavePopup(self: *Self, window_size: lm.Vector2) void {
    ui.new(.{
        .id = .ID("save-modal-backdrop"),
        .floating = .{
            .attach_to = .to_root,
            .attach_points = .{ .element = .left_top, .parent = .left_top },
            .z_index = 100,
        },
        .layout = .{
            .sizing = .{ .w = .fixed(window_size.x), .h = .fixed(window_size.y) },
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center, .y = .center },
        },
        .background_color = ui.color(6, 8, 14, 210),
    })({
        ui.new(.{
            .id = .ID("save-modal-card"),
            .layout = .{
                .sizing = .{ .w = .fixed(440.0) },
                .direction = .top_to_bottom,
                .padding = .all(20),
                .child_gap = 14,
            },
            .background_color = ui.color(20, 24, 34, 255),
            .border = .{ .color = ui.color(80, 100, 135, 240), .width = .outside(2) },
            .corner_radius = .all(8),
        })({
            ui.new(.{
                .id = .ID("save-modal-header"),
                .layout = .{ .sizing = .{ .w = .grow }, .child_alignment = .{ .x = .center } },
            })({
                ui.text("SAVE ARENA MAP", .{
                    .color = ui.color(240, 200, 100, 255),
                    .font_size = 16,
                    .letter_spacing = 2,
                });
            });

            ui.text("MAP NAME (alphanumeric, -, _):", .{
                .color = ui.color(170, 185, 210, 255),
                .font_size = 11,
                .letter_spacing = 1,
            });

            const current_name = self.map_name_buffer[0..self.map_name_length];
            const display_name = std.fmt.bufPrint(&self.display_name_buffer, "{s}_", .{current_name}) catch current_name;

            clay.UI()(.{
                .id = .ID("save-name-input-box"),
                .layout = .{ .padding = .axes(10, 12), .sizing = .{ .w = .grow } },
                .background_color = ui.color(10, 14, 22, 255),
                .border = .{ .color = ui.color(70, 130, 220, 220), .width = .outside(1) },
                .corner_radius = .all(4),
            })({
                ui.text(if (self.map_name_length > 0) display_name else "Type map name...", .{
                    .color = if (self.map_name_length > 0) ui.color(255, 255, 255, 255) else ui.color(120, 130, 150, 255),
                    .font_size = 13,
                    .letter_spacing = 1,
                });
            });

            ui.text("SELECT ARENA CATEGORY:", .{
                .color = ui.color(170, 185, 210, 255),
                .font_size = 11,
                .letter_spacing = 1,
            });

            ui.new(.{
                .id = .ID("save-category-buttons"),
                .layout = .{ .direction = .left_to_right, .child_gap = 8, .sizing = .{ .w = .grow } },
            })({
                self.drawCategoryChoiceButton(.normal);
                self.drawCategoryChoiceButton(.mini_boss);
                self.drawCategoryChoiceButton(.boss);
            });

            const preview_path = std.fmt.bufPrint(
                &self.preview_path_buffer,
                "Destination: assets/maps/{s}/{s}.json",
                .{ self.selected_arena_category.directoryName(), if (self.map_name_length > 0) current_name else "..." },
            ) catch "";

            ui.text(preview_path, .{
                .color = ui.color(140, 160, 190, 255),
                .font_size = 11,
                .letter_spacing = 1,
            });

            ui.new(.{
                .id = .ID("save-modal-actions"),
                .layout = .{
                    .direction = .left_to_right,
                    .child_gap = 10,
                    .sizing = .{ .w = .grow },
                },
            })({
                clay.UI()(.{
                    .id = .ID("modal-cancel-btn"),
                    .layout = .{
                        .padding = .axes(8, 14),
                        .sizing = .{ .w = .grow },
                        .child_alignment = .{ .x = .center },
                    },
                    .background_color = ui.color(55, 60, 75, 220),
                    .corner_radius = .all(4),
                })({
                    if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
                        self.show_save_popup = false;
                    }
                    ui.text("Cancel", .{
                        .color = ui.color(220, 230, 245, 255),
                        .font_size = 12,
                        .letter_spacing = 1,
                    });
                });

                clay.UI()(.{
                    .id = .ID("modal-confirm-save-btn"),
                    .layout = .{
                        .padding = .axes(8, 14),
                        .sizing = .{ .w = .grow },
                        .child_alignment = .{ .x = .center },
                    },
                    .background_color = if (self.map_name_length > 0) ui.color(40, 140, 70, 240) else ui.color(30, 60, 40, 160),
                    .corner_radius = .all(4),
                })({
                    if (self.map_name_length > 0 and clay.hovered() and lm.mouse.getButtonDown(.left)) {
                        self.confirmSaveMap();
                    }
                    ui.text("Save Map", .{
                        .color = ui.color(255, 255, 255, 255),
                        .font_size = 12,
                        .letter_spacing = 1,
                    });
                });
            });
        });
    });
}

fn loadMapFromPath(self: *Self, path: []const u8) void {
    const alloc = self.allocator orelse return;

    const loaded_data = MapSerializer.loadFromFile(alloc, path) catch |err| {
        std.log.err("Failed to load map {s}: {any}", .{ path, err });
        self.status_message = "Failed to load map";
        return;
    };

    const name = loaded_data.name;
    const name_len = @min(name.len, self.map_name_buffer.len);
    @memcpy(self.map_name_buffer[0..name_len], name[0..name_len]);
    self.map_name_length = name_len;

    if (std.mem.indexOf(u8, path, "mini_boss") != null) {
        self.selected_arena_category = .mini_boss;
    } else if (std.mem.indexOf(u8, path, "boss") != null) {
        self.selected_arena_category = .boss;
    } else if (std.mem.indexOf(u8, path, "normal") != null) {
        self.selected_arena_category = .normal;
    }

    self.width_tiles = loaded_data.width_tiles;
    self.height_tiles = loaded_data.height_tiles;

    if (self.background_tiles.len > 0) {
        alloc.free(self.background_tiles);
    }
    self.background_tiles = alloc.dupe(u8, loaded_data.background_tiles) catch return;

    for (loaded_data.walls) |wall| {
        const wall_value: u8 = switch (wall.wall_type) {
            .solid => @intFromEnum(TerrainType.wall_top),
            .low => @intFromEnum(TerrainType.wall_low_top),
        };
        const min_column = @min(wall.start_x_tiles, wall.end_x_tiles);
        const max_column = @max(wall.start_x_tiles, wall.end_x_tiles);
        const min_row = @min(wall.start_y_tiles, wall.end_y_tiles);
        const max_row = @max(wall.start_y_tiles, wall.end_y_tiles);

        var row_index = min_row;
        while (row_index <= max_row and row_index < self.height_tiles) : (row_index += 1) {
            var column_index = min_column;
            while (column_index <= max_column and column_index < self.width_tiles) : (column_index += 1) {
                self.background_tiles[row_index * self.width_tiles + column_index] = wall_value;
            }
        }
    }

    self.regenerateWallBoundingBoxes();

    self.spawn_zones.clearRetainingCapacity();
    for (loaded_data.spawn_zones) |zone| {
        self.spawn_zones.append(zone) catch break;
    }

    for (loaded_data.entities) |entity_record| {
        if (std.mem.eql(u8, entity_record.entity_type, "player_spawn")) {
            self.player_spawn_position = lm.Vec2(entity_record.position_x, entity_record.position_y);
        } else if (std.mem.eql(u8, entity_record.entity_type, "exit_door")) {
            self.exit_door_position = lm.Vec2(entity_record.position_x, entity_record.position_y);
        }
    }

    self.is_dirty = true;
    self.status_message = "Map loaded";
}

fn drawSpawnZoneRemovalHighlight(self: *Self, top_left: lm.Vector2) void {
    const relative_position = self.getRelativeMousePosition() orelse return;
    const zone_index = self.findSpawnZoneIndexAtPosition(relative_position) orelse return;
    const zone = self.spawn_zones.items()[zone_index];

    const zone_x = top_left.x + zone.center_x_pixels - (zone.width_pixels / 2.0);
    const zone_y = top_left.y + zone.center_y_pixels - (zone.height_pixels / 2.0);

    rl.drawRectangleRec(
        lm.Rect(zone_x, zone_y, zone.width_pixels, zone.height_pixels),
        rl.Color{ .r = 255, .g = 40, .b = 40, .a = 120 },
    );
    rl.drawRectangleLinesEx(
        lm.Rect(zone_x, zone_y, zone.width_pixels, zone.height_pixels),
        3.0,
        rl.Color.red,
    );
}

test "MapEditor generatePerimeterWalls and clearPerimeterWalls" {
    var editor = Self{};
    editor.width_tiles = 4;
    editor.height_tiles = 4;
    const total_tile_count: usize = 16;

    var tiles: [total_tile_count]u8 = [_]u8{0} ** total_tile_count;
    editor.background_tiles = &tiles;

    editor.generatePerimeterWalls();

    // Top and bottom row should be wall_top (2)
    try std.testing.expectEqual(@as(u8, 2), editor.background_tiles[0]);
    try std.testing.expectEqual(@as(u8, 2), editor.background_tiles[3]);
    try std.testing.expectEqual(@as(u8, 2), editor.background_tiles[12]);
    try std.testing.expectEqual(@as(u8, 2), editor.background_tiles[15]);
    // Center tiles should still be stone (0)
    try std.testing.expectEqual(@as(u8, 0), editor.background_tiles[5]);

    editor.clearPerimeterWalls();
    try std.testing.expectEqual(@as(u8, 0), editor.background_tiles[0]);
    try std.testing.expectEqual(@as(u8, 0), editor.background_tiles[15]);
}

test "MapEditor removeSpawnZoneAt targeted deletion" {
    var editor = Self{};
    editor.spawn_zones = lm.List(SpawnZoneRecord).init(std.testing.allocator);
    defer editor.spawn_zones.deinit();

    try editor.spawn_zones.append(.{
        .center_x_pixels = 300.0,
        .center_y_pixels = 300.0,
        .width_pixels = 192.0,
        .height_pixels = 192.0,
    });
    try editor.spawn_zones.append(.{
        .center_x_pixels = 800.0,
        .center_y_pixels = 600.0,
        .width_pixels = 192.0,
        .height_pixels = 192.0,
    });

    try std.testing.expectEqual(@as(usize, 2), editor.spawn_zones.len());

    // 1. Removing at non-overlapping point returns false
    const removed_empty = editor.removeSpawnZoneAt(lm.Vec2(50.0, 50.0));
    try std.testing.expectEqual(false, removed_empty);
    try std.testing.expectEqual(@as(usize, 2), editor.spawn_zones.len());

    // 2. Removing within first zone bounds (e.g. 320, 280, inside 300 +- 96) succeeds
    const removed_first = editor.removeSpawnZoneAt(lm.Vec2(320.0, 280.0));
    try std.testing.expectEqual(true, removed_first);
    try std.testing.expectEqual(@as(usize, 1), editor.spawn_zones.len());
    try std.testing.expectEqual(@as(f32, 800.0), editor.spawn_zones.items()[0].center_x_pixels);

    // 3. Removing second zone via removeSpawnZoneAtTile succeeds
    const removed_second = editor.removeSpawnZoneAtTile(12, 9);
    try std.testing.expectEqual(true, removed_second);
    try std.testing.expectEqual(@as(usize, 0), editor.spawn_zones.len());
}

test "MapEditor selectCategory automatically selects first tool and first asset" {
    var editor = Self{};

    editor.selectCategory(.spawners);
    try std.testing.expectEqual(EditorCategory.spawners, editor.current_category);
    try std.testing.expectEqual(EditorTool.spawn_zone, editor.current_tool);

    editor.selectCategory(.entities);
    try std.testing.expectEqual(EditorCategory.entities, editor.current_category);
    try std.testing.expectEqual(EditorTool.player_spawn, editor.current_tool);

    editor.selectCategory(.terrain);
    try std.testing.expectEqual(EditorCategory.terrain, editor.current_category);
    try std.testing.expectEqual(EditorTool.brush_1x1, editor.current_tool);
    try std.testing.expectEqual(TerrainType.stone, editor.selected_terrain);
}

test "MapEditor ArenaCategory directory and display mappings" {
    try std.testing.expectEqualStrings("normal", ArenaCategory.normal.directoryName());
    try std.testing.expectEqualStrings("mini_boss", ArenaCategory.mini_boss.directoryName());
    try std.testing.expectEqualStrings("boss", ArenaCategory.boss.directoryName());

    try std.testing.expectEqualStrings("Normal", ArenaCategory.normal.displayName());
    try std.testing.expectEqualStrings("Mini-Boss", ArenaCategory.mini_boss.displayName());
    try std.testing.expectEqualStrings("Boss", ArenaCategory.boss.displayName());
}

