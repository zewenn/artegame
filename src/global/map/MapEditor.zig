const std = @import("std");
const lm = @import("loom");
const rl = lm.deps.rl;

const MapLoader = @import("MapLoader.zig");
const MapEditorDocument = @import("MapEditorDocument.zig");
const MapEditorOverlay = @import("MapEditorOverlay.zig");
const MapEditorSidebar = @import("MapEditorSidebar.zig");

const Self = @This();

var active_editor_instance: ?*Self = null;

pub const EditorCategory = MapEditorDocument.EditorCategory;
pub const EditorTool = MapEditorDocument.EditorTool;

camera: ?*lm.Camera = null,
document: MapEditorDocument = .{},
pan_drag_start_pixels: ?lm.Vector2 = null,
initial_camera_target_pixels: lm.Vector2 = .init(0, 0),

/// Initializes the active map editor document and clears any prior playtest override.
pub fn Awake(self: *Self) !void {
    active_editor_instance = self;
    MapLoader.setInMemoryMapOverride(null);
    try self.document.init(lm.allocators.generic());
}

/// Binds the main camera for custom canvas rendering and centers it beside the sidebar.
pub fn Start(self: *Self) void {
    const scene = lm.activeScene() orelse return;
    const active_camera = scene.getCameraById("main") orelse return;
    self.camera = active_camera;

    active_camera.draw_mode = .custom;
    active_camera.draw_fn = &drawCanvasCustom;
    active_camera.target = .init(0, 0);
    const window_size_pixels = lm.window.size.get();
    active_camera.offset = lm.Vec2(
        MapEditorSidebar.SIDEBAR_WIDTH_PIXELS + (window_size_pixels.x - MapEditorSidebar.SIDEBAR_WIDTH_PIXELS) / 2.0,
        window_size_pixels.y / 2.0,
    );
    active_camera.zoom = 0.65;
    active_camera.camera.offset = active_camera.offset;
    active_camera.camera.target = active_camera.target;
    active_camera.camera.zoom = active_camera.zoom;
}

/// Updates dirty visuals, camera navigation, canvas mouse tools, and sidebar UI each frame.
pub fn Update(self: *Self) !void {
    try self.document.syncDirtyVisuals();

    self.handleCameraControls();
    self.handleCanvasInteraction();

    const window_size_pixels = lm.window.size.get();
    MapEditorSidebar.draw(&self.document, self.camera, window_size_pixels);
}

/// Clears the active editor singleton and frees all document resources.
pub fn End(self: *Self) void {
    if (active_editor_instance == self) {
        active_editor_instance = null;
    }
    self.document.deinit();
}

/// Custom camera draw callback rendering the baked map canvas and world-space overlays.
pub fn drawCanvasCustom() anyerror!void {
    const self = active_editor_instance orelse return;
    const top_left_pixels = self.document.getTopLeftPosition();
    self.document.renderer.drawDirect(top_left_pixels);
    MapEditorOverlay.drawCanvasOverlays(&self.document, top_left_pixels, self.getRelativeMousePosition());
}

fn updateCameraZoom(active_camera: *lm.Camera, delta_seconds: f32) void {
    const wheel_move = rl.getMouseWheelMove();
    if (wheel_move != 0.0) {
        const zoom_factor = std.math.pow(f32, 1.15, wheel_move);
        active_camera.zoom = std.math.clamp(active_camera.zoom * zoom_factor, 0.15, 4.0);
    }

    const is_zoom_in = lm.keyboard.getKey(.equal) or
        lm.keyboard.getKey(.kp_add) or
        lm.keyboard.getKey(.right_bracket) or
        lm.keyboard.getKey(.page_up);

    const is_zoom_out = lm.keyboard.getKey(.minus) or
        lm.keyboard.getKey(.kp_subtract) or
        lm.keyboard.getKey(.left_bracket) or
        lm.keyboard.getKey(.page_down);

    if (is_zoom_in) {
        const zoom_multiplier = 1.0 + (1.8 * delta_seconds);
        active_camera.zoom = std.math.clamp(active_camera.zoom * zoom_multiplier, 0.15, 4.0);
    }
    if (is_zoom_out) {
        const zoom_divisor = 1.0 + (1.8 * delta_seconds);
        active_camera.zoom = std.math.clamp(active_camera.zoom / zoom_divisor, 0.15, 4.0);
    }
}

fn updateCameraPan(self: *Self, active_camera: *lm.Camera, delta_seconds: f32) void {
    const pan_speed_pixels_per_second: f32 = 800.0 / active_camera.zoom;
    if (lm.keyboard.getKey(.w) or lm.keyboard.getKey(.up)) {
        active_camera.target.y -= pan_speed_pixels_per_second * delta_seconds;
    }
    if (lm.keyboard.getKey(.s) or lm.keyboard.getKey(.down)) {
        active_camera.target.y += pan_speed_pixels_per_second * delta_seconds;
    }
    if (lm.keyboard.getKey(.a) or lm.keyboard.getKey(.left)) {
        active_camera.target.x -= pan_speed_pixels_per_second * delta_seconds;
    }
    if (lm.keyboard.getKey(.d) or lm.keyboard.getKey(.right)) {
        active_camera.target.x += pan_speed_pixels_per_second * delta_seconds;
    }

    const is_pan_pressed = lm.mouse.getButtonDown(.right) or lm.mouse.getButtonDown(.middle);
    const is_pan_held = lm.mouse.getButton(.right) or lm.mouse.getButton(.middle);

    if (is_pan_pressed) {
        self.pan_drag_start_pixels = lm.mouse.getPosition();
        self.initial_camera_target_pixels = active_camera.target;
        return;
    }

    if (!is_pan_held) {
        self.pan_drag_start_pixels = null;
        return;
    }

    const drag_start_pixels = self.pan_drag_start_pixels orelse return;
    const current_mouse_pixels = lm.mouse.getPosition();
    const mouse_difference_pixels = current_mouse_pixels.subtract(drag_start_pixels);
    active_camera.target = self.initial_camera_target_pixels.subtract(
        mouse_difference_pixels.divide(.init(active_camera.zoom, active_camera.zoom)),
    );
}

fn handleCameraControls(self: *Self) void {
    if (self.document.show_save_popup) return;
    const active_camera = self.camera orelse return;

    const window_size_pixels = lm.window.size.get();
    active_camera.offset = lm.Vec2(
        MapEditorSidebar.SIDEBAR_WIDTH_PIXELS + (window_size_pixels.x - MapEditorSidebar.SIDEBAR_WIDTH_PIXELS) / 2.0,
        window_size_pixels.y / 2.0,
    );

    const delta_seconds = lm.time.deltaTime();
    updateCameraZoom(active_camera, delta_seconds);
    self.updateCameraPan(active_camera, delta_seconds);

    if (lm.keyboard.getKeyDown(.r) or lm.keyboard.getKeyDown(.f) or lm.keyboard.getKeyDown(.zero)) {
        active_camera.target = .init(0, 0);
        active_camera.zoom = 0.65;
        self.document.status_message = "Camera reset to center";
    }

    active_camera.camera.offset = active_camera.offset;
    active_camera.camera.target = active_camera.target;
    active_camera.camera.zoom = active_camera.zoom;
}

fn getRelativeMousePosition(self: *const Self) ?lm.Vector2 {
    const active_camera = self.camera orelse return null;
    const mouse_screen_pixels = lm.mouse.getPosition();
    if (mouse_screen_pixels.x < MapEditorSidebar.SIDEBAR_WIDTH_PIXELS) return null;

    const mouse_world_pixels = active_camera.screenToWorldPos(mouse_screen_pixels);
    const top_left_pixels = self.document.getTopLeftPosition();
    const relative_x_pixels = mouse_world_pixels.x - top_left_pixels.x;
    const relative_y_pixels = mouse_world_pixels.y - top_left_pixels.y;

    const canvas_width_pixels = @as(f32, @floatFromInt(self.document.width_tiles)) * self.document.tile_size_pixels;
    const canvas_height_pixels = @as(f32, @floatFromInt(self.document.height_tiles)) * self.document.tile_size_pixels;

    const is_inside_canvas = relative_x_pixels >= 0.0 and relative_y_pixels >= 0.0 and
        relative_x_pixels < canvas_width_pixels and relative_y_pixels < canvas_height_pixels;

    if (!is_inside_canvas) return null;
    return lm.Vec2(relative_x_pixels, relative_y_pixels);
}

fn getHoveredTile(self: *const Self) ?MapEditorDocument.TileCoordinate {
    const relative_position_pixels = self.getRelativeMousePosition() orelse return null;
    return .{
        .column_index = @intFromFloat(relative_position_pixels.x / self.document.tile_size_pixels),
        .row_index = @intFromFloat(relative_position_pixels.y / self.document.tile_size_pixels),
    };
}

fn handleCanvasInteraction(self: *Self) void {
    if (self.document.show_save_popup) return;
    if (self.document.current_category == .file_management) return;
    const hovered_tile = self.getHoveredTile() orelse return;

    if (lm.mouse.getButton(.left)) {
        self.applyToolAction(hovered_tile.column_index, hovered_tile.row_index);
    } else if (lm.mouse.getButtonUp(.left)) {
        self.document.commitBoxFill(hovered_tile.column_index, hovered_tile.row_index);
    }
}

fn applySpawnZoneErase(self: *Self, column_index: u32, row_index: u32) void {
    if (!lm.mouse.getButtonDown(.left)) return;
    if (self.getRelativeMousePosition()) |relative_position_pixels| {
        _ = self.document.removeSpawnZoneAt(relative_position_pixels);
    } else {
        _ = self.document.removeSpawnZoneAtTile(column_index, row_index);
    }
}

fn applyToolAction(self: *Self, column_index: u32, row_index: u32) void {
    const is_click_down = lm.mouse.getButtonDown(.left);

    switch (self.document.current_tool) {
        .brush_1x1, .brush_2x2, .brush_3x3 => {
            const brush_width_tiles = self.document.current_tool.spec().brush_width_tiles orelse 1;
            self.document.paintBrush(column_index, row_index, brush_width_tiles);
        },
        .eraser => self.document.paintTile(column_index, row_index, @intFromEnum(MapEditorDocument.EditorCategory.terrain.spec().default_terrain.?)),
        .spawn_zone_erase => self.applySpawnZoneErase(column_index, row_index),
        .box_fill => {
            if (self.document.box_fill_start == null) {
                self.document.box_fill_start = .{ .column_index = column_index, .row_index = row_index };
            }
        },
        .bucket_fill => {
            if (is_click_down) {
                self.document.bucketFill(column_index, row_index, @intFromEnum(self.document.selected_terrain));
            }
        },
        .spawn_zone => {
            if (is_click_down) {
                self.document.placeSpawnZone(column_index, row_index);
            }
        },
        .player_spawn => {
            self.document.player_spawn_position = self.document.tileCenterPixels(column_index, row_index);
            self.document.status_message = "Player spawn positioned";
        },
        .exit_door => {
            if (is_click_down) {
                self.document.toggleExitDoorAtTile(column_index, row_index);
            }
        },
        .exit_door_erase => {
            if (is_click_down) {
                self.document.eraseExitDoorAtTile(column_index, row_index);
            }
        },
    }
}
