const std = @import("std");
const lm = @import("loom");
const rl = lm.deps.rl;
const ui = lm.ui;
const clay = lm.deps.clay;

const MapTypes = @import("MapTypes.zig");
const TerrainType = MapTypes.TerrainType;
const EnemyType = @import("../../components/enemy/EnemyType.zig").EnemyType;
const MapRegistry = @import("MapRegistry.zig");
const RoomType = @import("../RoomType.zig").RoomType;
const MapEditorDocument = @import("MapEditorDocument.zig");
const EditorCategory = MapEditorDocument.EditorCategory;
const EditorTool = MapEditorDocument.EditorTool;

pub const SIDEBAR_WIDTH_PIXELS: f32 = 320.0;

const SidebarButtonStyle = struct {
    padding: clay.Padding = .axes(6, 10),
    sizing: clay.Sizing = .{ .w = .grow },
    alignment: clay.ChildAlignment = .{},
    background_color: clay.Color,
    text_color: clay.Color,
    border: clay.BorderElementConfig = .{},
    corner_radius_pixels: f32 = 4.0,
    font_size: u16 = 12,
    letter_spacing: u16 = 1,
    is_disabled: bool = false,
};

fn drawSidebarButton(
    element_id: clay.ElementId,
    label: []const u8,
    style: SidebarButtonStyle,
) bool {
    var was_clicked = false;
    clay.UI()(.{
        .id = element_id,
        .layout = .{
            .padding = style.padding,
            .sizing = style.sizing,
            .child_alignment = style.alignment,
        },
        .background_color = style.background_color,
        .border = style.border,
        .corner_radius = .all(style.corner_radius_pixels),
    })({
        if (!style.is_disabled and clay.hovered() and lm.mouse.getButtonDown(.left)) {
            was_clicked = true;
        }
        ui.text(label, .{
            .color = style.text_color,
            .font_size = style.font_size,
            .letter_spacing = style.letter_spacing,
        });
    });
    return was_clicked;
}

/// Renders the editor sidebar and optional save modal overlay.
pub fn draw(
    document: *MapEditorDocument,
    active_camera: ?*lm.Camera,
    window_size_pixels: lm.Vector2,
) void {
    ui.new(.{
        .id = .ID("editor-root"),
        .floating = .{
            .attach_to = .to_root,
            .attach_points = .{ .element = .left_top, .parent = .left_top },
        },
        .layout = .{
            .sizing = .{ .w = .fixed(SIDEBAR_WIDTH_PIXELS), .h = .fixed(window_size_pixels.y) },
            .direction = .top_to_bottom,
            .padding = .all(14),
            .child_gap = 10,
        },
        .background_color = ui.color(16, 18, 26, 245),
        .border = .{ .color = ui.color(60, 68, 88, 200), .width = .outside(1) },
    })({
        drawHeader(document);
        drawCategoryTabs(document);
        drawActiveCategoryPanel(document);
        drawZoomControls(active_camera);
        drawStatusBar(document.status_message);
    });

    if (document.show_save_popup) {
        handleSavePopupInput(document);
        drawSavePopup(document, window_size_pixels);
    }
}

fn drawSectionLabel(label: []const u8) void {
    ui.text(label, .{
        .color = ui.color(160, 175, 200, 255),
        .font_size = 11,
        .letter_spacing = 1,
    });
}

fn drawActiveCategoryPanel(document: *MapEditorDocument) void {
    switch (document.current_category) {
        .terrain => drawTerrainCategory(document),
        .spawners => drawSpawnersCategory(document),
        .entities => drawEntitiesCategory(document),
        .map_size => drawSizeCategory(document),
        .file_management => drawFileCategory(document),
    }
}

fn drawHeader(document: *MapEditorDocument) void {
    ui.new(.{
        .id = .ID("editor-header-bar"),
        .layout = .{
            .direction = .left_to_right,
            .sizing = .{ .w = .grow },
            .child_alignment = .{ .y = .center },
            .child_gap = 8,
        },
    })({
        ui.new(.{
            .id = .ID("editor-title-wrap"),
            .layout = .{ .sizing = .{ .w = .grow } },
        })({
            ui.text("MAP EDITOR", .{
                .color = ui.color(240, 200, 100, 255),
                .font_size = 18,
                .letter_spacing = 2,
            });
        });

        if (drawSidebarButton(.ID("header-test-canvas-btn"), "Play |>", .{
            .padding = .axes(4, 8),
            .sizing = .{},
            .background_color = ui.color(45, 140, 75, 230),
            .text_color = ui.color(255, 255, 255, 255),
            .font_size = 11,
        })) {
            document.playtestCurrentCanvas();
        }
    });
}

fn drawCategoryTabs(document: *MapEditorDocument) void {
    ui.new(.{
        .id = .ID("category-tabs"),
        .layout = .{
            .direction = .left_to_right,
            .child_gap = 4,
            .child_alignment = .{ .y = .center },
        },
    })({
        inline for (std.enums.values(EditorCategory)) |category| {
            const is_active = (document.current_category == category);
            if (drawSidebarButton(.IDI("cat-btn-", @intFromEnum(category)), category.spec().tab_label, .{
                .padding = .axes(4, 6),
                .sizing = .{},
                .alignment = .{ .x = .center, .y = .center },
                .background_color = if (is_active) ui.color(240, 200, 100, 220) else ui.color(30, 36, 48, 200),
                .text_color = if (is_active) ui.color(10, 12, 16, 255) else ui.color(190, 200, 220, 255),
                .font_size = 10,
            })) {
                document.selectCategory(category);
            }
        }
    });
}

fn drawTerrainOption(document: *MapEditorDocument, terrain: TerrainType) void {
    const is_selected = (document.selected_terrain == terrain);
    if (drawSidebarButton(.IDI("terrain-opt-", @intFromEnum(terrain)), terrain.displayName(), .{
        .padding = .axes(6, 10),
        .alignment = .{ .x = .center },
        .background_color = if (is_selected) ui.color(70, 130, 220, 240) else ui.color(35, 42, 56, 200),
        .text_color = ui.color(255, 255, 255, 255),
        .font_size = 11,
    })) {
        document.selected_terrain = terrain;
        document.status_message = "Tile selected";
    }
}

fn drawTerrainRow(document: *MapEditorDocument, row_index: usize) void {
    const terrain_index = row_index * 2;
    ui.new(.{
        .id = .IDI("terrain-row-", lm.tou32(row_index)),
        .layout = .{ .direction = .left_to_right, .child_gap = 6, .sizing = .{ .w = .grow } },
    })({
        if (TerrainType.fromInt(terrain_index)) |terrain_one| {
            drawTerrainOption(document, terrain_one);
        }
        if (TerrainType.fromInt(terrain_index + 1)) |terrain_two| {
            drawTerrainOption(document, terrain_two);
        }
    });
}

fn drawToolButton(document: *MapEditorDocument, tool: EditorTool) void {
    const is_active = (document.current_tool == tool);
    if (drawSidebarButton(.IDI("tool-btn-", @intFromEnum(tool)), tool.spec().label, .{
        .background_color = if (is_active) ui.color(240, 180, 70, 220) else ui.color(28, 34, 46, 200),
        .text_color = if (is_active) ui.color(10, 12, 16, 255) else ui.color(200, 210, 230, 255),
    })) {
        document.current_tool = tool;
        document.status_message = "Tool changed";
    }
}

fn drawCategoryTools(document: *MapEditorDocument, comptime category: EditorCategory) void {
    inline for (std.enums.values(EditorTool)) |tool| {
        if (comptime tool.spec().category == category) {
            drawToolButton(document, tool);
        }
    }
}

fn drawBoundaryActionButtons(
    document: *MapEditorDocument,
    generate_button_id: clay.ElementId,
    clear_button_id: clay.ElementId,
) void {
    drawSectionLabel("BOUNDARY ACTIONS:");

    if (drawSidebarButton(generate_button_id, "Generate Perimeter Walls", .{
        .background_color = ui.color(45, 55, 75, 220),
        .text_color = ui.color(220, 230, 245, 255),
    })) {
        document.generatePerimeterWalls();
    }

    if (drawSidebarButton(clear_button_id, "Clear Perimeter Walls", .{
        .background_color = ui.color(75, 35, 40, 220),
        .text_color = ui.color(255, 180, 180, 255),
    })) {
        document.clearPerimeterWalls();
    }
}

fn drawTerrainCategory(document: *MapEditorDocument) void {
    ui.new(.{
        .id = .ID("terrain-panel"),
        .layout = .{ .direction = .top_to_bottom, .child_gap = 8 },
    })({
        drawSectionLabel("SELECT TILE:");

        const rows_count = @divCeil(TerrainType.count, 2);
        for (0..rows_count) |row_index| {
            drawTerrainRow(document, row_index);
        }

        drawSectionLabel("PAINT TOOLS:");
        drawCategoryTools(document, .terrain);
        drawBoundaryActionButtons(document, .ID("gen-boundary-btn"), .ID("clear-boundary-btn"));
    });
}

fn drawArchetypeButton(document: *MapEditorDocument, maybe_enemy_type: ?EnemyType, label_text: []const u8) void {
    const is_selected = (document.selected_spawn_enemy_type == maybe_enemy_type);
    const outline_color = EnemyType.editorOutlineColor(maybe_enemy_type);
    const background_color = if (is_selected)
        ui.color(outline_color.r, outline_color.g, outline_color.b, 220)
    else
        ui.color(32, 38, 52, 200);

    const element_id = if (maybe_enemy_type) |enemy_type|
        clay.ElementId.IDI("spawn-archetype-", @intFromEnum(enemy_type))
    else
        clay.ElementId.ID("spawn-archetype-all");

    if (drawSidebarButton(element_id, label_text, .{
        .padding = .axes(5, 8),
        .background_color = background_color,
        .text_color = if (is_selected) ui.color(10, 15, 20, 255) else ui.color(220, 230, 245, 255),
        .font_size = 11,
    })) {
        document.selected_spawn_enemy_type = maybe_enemy_type;
        document.current_tool = .spawn_zone;
        document.status_message = "Target archetype selected";
    }
}

fn drawSpawnersCategory(document: *MapEditorDocument) void {
    ui.new(.{
        .id = .ID("spawners-panel"),
        .layout = .{ .direction = .top_to_bottom, .child_gap = 6 },
    })({
        drawCategoryTools(document, .spawners);

        ui.text("Target Archetype:", .{
            .color = ui.color(180, 200, 225, 255),
            .font_size = 11,
            .letter_spacing = 1,
        });

        drawArchetypeButton(document, null, "All (Any Enemy)");
        inline for (std.enums.values(EnemyType)) |enemy_type| {
            drawArchetypeButton(document, enemy_type, enemy_type.displayName());
        }

        if (drawSidebarButton(.ID("clear-spawners-btn"), "Clear All Spawn Zones", .{
            .background_color = ui.color(75, 35, 40, 220),
            .text_color = ui.color(255, 180, 180, 255),
        })) {
            document.spawn_zones.clearRetainingCapacity();
            document.status_message = "All spawn zones cleared";
        }
    });
}

fn drawEntitiesCategory(document: *MapEditorDocument) void {
    ui.new(.{
        .id = .ID("entities-panel"),
        .layout = .{ .direction = .top_to_bottom, .child_gap = 8 },
    })({
        drawCategoryTools(document, .entities);
    });
}

fn drawDimensionStepButton(
    document: *MapEditorDocument,
    element_id: clay.ElementId,
    label: []const u8,
    width_step_direction: i32,
    height_step_direction: i32,
) void {
    const is_width_disabled = (width_step_direction < 0 and document.width_tiles <= MapEditorDocument.MIN_MAP_DIMENSION_TILES) or
        (width_step_direction > 0 and document.width_tiles >= MapEditorDocument.MAX_MAP_DIMENSION_TILES);
    const is_height_disabled = (height_step_direction < 0 and document.height_tiles <= MapEditorDocument.MIN_MAP_DIMENSION_TILES) or
        (height_step_direction > 0 and document.height_tiles >= MapEditorDocument.MAX_MAP_DIMENSION_TILES);

    const is_disabled = if (width_step_direction != 0 and height_step_direction != 0)
        (is_width_disabled and is_height_disabled)
    else if (width_step_direction != 0)
        is_width_disabled
    else
        is_height_disabled;

    if (drawSidebarButton(element_id, label, .{
        .padding = .axes(6, 8),
        .alignment = .{ .x = .center, .y = .center },
        .background_color = if (is_disabled) ui.color(30, 34, 44, 150) else ui.color(45, 55, 75, 220),
        .text_color = if (is_disabled) ui.color(100, 110, 130, 180) else ui.color(220, 230, 245, 255),
        .font_size = 11,
        .is_disabled = is_disabled,
    })) {
        const new_width_tiles = if (width_step_direction != 0)
            MapEditorDocument.stepDimension(document.width_tiles, width_step_direction)
        else
            document.width_tiles;
        const new_height_tiles = if (height_step_direction != 0)
            MapEditorDocument.stepDimension(document.height_tiles, height_step_direction)
        else
            document.height_tiles;

        document.resizeMapGrid(new_width_tiles, new_height_tiles) catch |resize_error| {
            std.log.err("Failed to resize map grid: {any}", .{resize_error});
            document.status_message = "Resize failed (out of memory)";
        };
    }
}

fn drawSizePresetButton(
    document: *MapEditorDocument,
    comptime dimension_tiles: u32,
) void {
    const label = comptime blk: {
        const base = std.fmt.comptimePrint("{d} x {d}", .{ dimension_tiles, dimension_tiles });
        if (dimension_tiles == MapEditorDocument.MIN_MAP_DIMENSION_TILES) break :blk base ++ " (Min)";
        if (dimension_tiles == MapEditorDocument.MAX_MAP_DIMENSION_TILES) break :blk base ++ " (Max)";
        break :blk base;
    };

    const is_current = (document.width_tiles == dimension_tiles and document.height_tiles == dimension_tiles);
    if (drawSidebarButton(.IDI("size-preset-button-", dimension_tiles), label, .{
        .padding = .axes(5, 8),
        .alignment = .{ .x = .center, .y = .center },
        .background_color = if (is_current) ui.color(240, 200, 100, 220) else ui.color(35, 42, 58, 200),
        .text_color = if (is_current) ui.color(10, 12, 16, 255) else ui.color(200, 215, 235, 255),
        .font_size = 11,
        .is_disabled = is_current,
    })) {
        document.resizeMapGrid(dimension_tiles, dimension_tiles) catch |resize_error| {
            std.log.err("Failed to resize map grid: {any}", .{resize_error});
            document.status_message = "Resize failed (out of memory)";
        };
    }
}

const DimensionStepRow = struct {
    row_id: []const u8,
    decrease_id: []const u8,
    decrease_label: []const u8,
    increase_id: []const u8,
    increase_label: []const u8,
    width_direction: i32,
    height_direction: i32,
};

const DIMENSION_STEP_ROWS = [_]DimensionStepRow{
    .{
        .row_id = "size-width-controls-row",
        .decrease_id = "size-width-decrease-button",
        .decrease_label = "Width -16",
        .increase_id = "size-width-increase-button",
        .increase_label = "Width +16",
        .width_direction = 1,
        .height_direction = 0,
    },
    .{
        .row_id = "size-height-controls-row",
        .decrease_id = "size-height-decrease-button",
        .decrease_label = "Height -16",
        .increase_id = "size-height-increase-button",
        .increase_label = "Height +16",
        .width_direction = 0,
        .height_direction = 1,
    },
    .{
        .row_id = "size-uniform-controls-row",
        .decrease_id = "size-both-decrease-button",
        .decrease_label = "Both -16",
        .increase_id = "size-both-increase-button",
        .increase_label = "Both +16",
        .width_direction = 1,
        .height_direction = 1,
    },
};

const SQUARE_PRESET_SIZES = blk: {
    const count = ((MapEditorDocument.MAX_MAP_DIMENSION_TILES - MapEditorDocument.MIN_MAP_DIMENSION_TILES) /
        MapEditorDocument.DIMENSION_STEP_INCREMENT_TILES) + 1;
    var sizes: [count]u32 = undefined;
    for (&sizes, 0..) |*slot, index| {
        slot.* = MapEditorDocument.MIN_MAP_DIMENSION_TILES +
            @as(u32, @intCast(index)) * MapEditorDocument.DIMENSION_STEP_INCREMENT_TILES;
    }
    break :blk sizes;
};

fn drawSquarePresetPairRow(
    document: *MapEditorDocument,
    comptime row_index: usize,
    comptime first_size: u32,
    comptime maybe_second_size: ?u32,
) void {
    ui.new(.{
        .id = .IDI("size-presets-row-", @intCast(row_index)),
        .layout = .{ .direction = .left_to_right, .child_gap = 6, .sizing = .{ .w = .grow } },
    })({
        drawSizePresetButton(document, first_size);
        if (maybe_second_size) |second_size| {
            drawSizePresetButton(document, second_size);
        }
    });
}

fn drawSizeInfoCard(document: *const MapEditorDocument) void {
    const tile_size = MapTypes.DEFAULT_TILE_SIZE_PIXELS;
    ui.new(.{
        .id = .ID("size-info-card"),
        .layout = .{
            .direction = .top_to_bottom,
            .padding = .all(8),
            .child_gap = 4,
            .sizing = .{ .w = .grow },
        },
        .background_color = ui.color(24, 28, 40, 220),
        .corner_radius = .all(4),
    })({
        ui.textFmt("{d} x {d} Tiles", .{ document.width_tiles, document.height_tiles }, .{
            .color = ui.color(240, 200, 100, 255),
            .font_size = 14,
            .letter_spacing = 1,
        });

        ui.textFmt("{d} x {d} Pixels", .{ document.width_tiles * tile_size, document.height_tiles * tile_size }, .{
            .color = ui.color(170, 185, 210, 255),
            .font_size = 11,
        });
    });
}

fn drawSizeCategory(document: *MapEditorDocument) void {
    ui.new(.{
        .id = .ID("size-panel"),
        .layout = .{ .direction = .top_to_bottom, .child_gap = 8 },
    })({
        drawSectionLabel("CURRENT DIMENSIONS:");
        drawSizeInfoCard(document);

        drawSectionLabel("ADJUST DIMENSIONS (STEP 16):");
        inline for (DIMENSION_STEP_ROWS) |row| {
            ui.new(.{
                .id = .ID(row.row_id),
                .layout = .{ .direction = .left_to_right, .child_gap = 6, .sizing = .{ .w = .grow } },
            })({
                drawDimensionStepButton(document, .ID(row.decrease_id), row.decrease_label, -row.width_direction, -row.height_direction);
                drawDimensionStepButton(document, .ID(row.increase_id), row.increase_label, row.width_direction, row.height_direction);
            });
        }

        drawSectionLabel("SQUARE PRESETS:");
        const pair_count = @divCeil(SQUARE_PRESET_SIZES.len, 2);
        inline for (0..pair_count) |pair_index| {
            const first_index = pair_index * 2;
            const second_index = first_index + 1;
            const second_size: ?u32 = if (second_index < SQUARE_PRESET_SIZES.len) SQUARE_PRESET_SIZES[second_index] else null;
            drawSquarePresetPairRow(document, pair_index, SQUARE_PRESET_SIZES[first_index], second_size);
        }

        drawBoundaryActionButtons(document, .ID("size-gen-boundary-button"), .ID("size-clear-boundary-button"));
    });
}

const PresetMapEntry = struct {
    row_id: []const u8,
    load_button_id: []const u8,
    play_button_id: []const u8,
    load_label: []const u8,
    room_type: RoomType,
};

const PRESET_MAP_ENTRIES = [_]PresetMapEntry{
    .{
        .row_id = "row-normal-arena",
        .load_button_id = "load-normal-btn",
        .play_button_id = "play-normal-btn",
        .load_label = "Load Normal Arena",
        .room_type = .normal,
    },
    .{
        .row_id = "row-miniboss-arena",
        .load_button_id = "load-miniboss-btn",
        .play_button_id = "play-miniboss-btn",
        .load_label = "Load Mini-Boss Arena",
        .room_type = .mini_boss,
    },
    .{
        .row_id = "row-boss-arena",
        .load_button_id = "load-boss-btn",
        .play_button_id = "play-boss-btn",
        .load_label = "Load Boss Arena",
        .room_type = .boss,
    },
    .{
        .row_id = "row-tutorial-arena",
        .load_button_id = "load-tutorial-btn",
        .play_button_id = "play-tutorial-btn",
        .load_label = "Load Tutorial Map",
        .room_type = .tutorial,
    },
};

fn drawFileCategory(document: *MapEditorDocument) void {
    ui.new(.{
        .id = .ID("file-panel"),
        .layout = .{ .direction = .top_to_bottom, .child_gap = 8 },
    })({
        drawToolbarActionButtons(document);

        inline for (PRESET_MAP_ENTRIES) |preset| {
            const map_path = MapRegistry.getDefaultMapPath(preset.room_type);
            const playtest_room_type: RoomType = if (preset.room_type == .tutorial) .normal else preset.room_type;
            drawPresetMapRow(
                document,
                .ID(preset.row_id),
                .ID(preset.load_button_id),
                .ID(preset.play_button_id),
                map_path,
                preset.load_label,
                playtest_room_type,
            );
        }

        drawCustomMapButtons(document);
        drawExitButton();
    });
}

fn drawToolbarActionButtons(document: *MapEditorDocument) void {
    ui.new(.{
        .id = .ID("file-actions-row"),
        .layout = .{
            .direction = .left_to_right,
            .sizing = .{ .w = .grow },
            .child_gap = 6,
        },
    })({
        if (drawSidebarButton(.ID("test-canvas-btn"), "Test Canvas |>", .{
            .background_color = ui.color(45, 130, 75, 230),
            .text_color = ui.color(255, 255, 255, 255),
        })) {
            document.playtestCurrentCanvas();
        }

        if (drawSidebarButton(.ID("save-map-btn"), "Save Map...", .{
            .background_color = ui.color(40, 100, 60, 230),
            .text_color = ui.color(255, 255, 255, 255),
        })) {
            document.show_save_popup = true;
        }
    });
}

fn drawPresetMapRow(
    document: *MapEditorDocument,
    row_id: clay.ElementId,
    load_button_id: clay.ElementId,
    play_button_id: clay.ElementId,
    map_path: []const u8,
    label_text: []const u8,
    room_type: RoomType,
) void {
    ui.new(.{
        .id = row_id,
        .layout = .{
            .direction = .left_to_right,
            .sizing = .{ .w = .grow },
            .child_gap = 6,
            .child_alignment = .{ .y = .center },
        },
    })({
        if (drawSidebarButton(load_button_id, label_text, .{
            .background_color = ui.color(35, 45, 65, 220),
            .text_color = ui.color(200, 215, 235, 255),
        })) {
            document.loadMapFromPath(map_path);
        }

        drawPlayButton(document, play_button_id, map_path, room_type);
    });
}

fn drawPlayButton(
    document: *MapEditorDocument,
    element_id: clay.ElementId,
    map_path: []const u8,
    room_type: RoomType,
) void {
    if (drawSidebarButton(element_id, "Play |>", .{
        .padding = .axes(6, 8),
        .sizing = .{},
        .background_color = ui.color(45, 130, 75, 230),
        .text_color = ui.color(255, 255, 255, 255),
        .font_size = 11,
    })) {
        document.playtestMap(map_path, room_type);
    }
}

fn drawExitButton() void {
    if (drawSidebarButton(.ID("exit-menu-btn"), "Exit to Main Menu", .{
        .background_color = ui.color(80, 35, 40, 230),
        .text_color = ui.color(255, 200, 200, 255),
    })) {
        lm.loadScene("main_menu") catch |load_error| {
            std.log.err("Failed to return to main_menu: {any}", .{load_error});
        };
    }
}

fn drawCustomMapButtons(document: *MapEditorDocument) void {
    var found_any_custom_maps = false;
    const categories = [_]RoomType{ .normal, .mini_boss, .boss };
    var global_index: usize = 0;

    for (categories) |category| {
        drawCategoryCustomMaps(document, category, &global_index, &found_any_custom_maps);
    }

    if (!found_any_custom_maps) {
        ui.text("No custom maps saved yet", .{
            .color = ui.color(130, 145, 170, 200),
            .font_size = 10,
            .letter_spacing = 1,
        });
    }
}

fn drawCategoryCustomMaps(
    document: *MapEditorDocument,
    category: RoomType,
    global_index: *usize,
    found_any: *bool,
) void {
    const available_maps = MapRegistry.getAvailableMapsAlloc(lm.allocators.arena(), category) catch &.{};
    for (available_maps) |map_path| {
        const file_basename = std.fs.path.basename(map_path);
        const is_default_map = std.mem.eql(u8, file_basename, "arena_normal.json") or
            std.mem.eql(u8, file_basename, "arena_boss.json");
        if (is_default_map) continue;

        found_any.* = true;
        drawSingleCustomMapButton(document, category, map_path, file_basename, global_index.*);
        global_index.* += 1;
    }
}

fn drawSingleCustomMapButton(
    document: *MapEditorDocument,
    category: RoomType,
    map_path: []const u8,
    file_basename: []const u8,
    button_index: usize,
) void {
    ui.new(.{
        .id = .IDI("custom-map-row-", @intCast(button_index)),
        .layout = .{
            .direction = .left_to_right,
            .sizing = .{ .w = .grow },
            .child_gap = 6,
            .child_alignment = .{ .y = .center },
        },
    })({
        const label_text = std.fmt.allocPrint(
            lm.allocators.arena(),
            "Open [{s}] {s}",
            .{ category.directoryCategory(), file_basename },
        ) catch "Open Map";

        if (drawSidebarButton(.IDI("load-custom-map-btn-", @intCast(button_index)), label_text, .{
            .background_color = ui.color(45, 55, 80, 220),
            .text_color = ui.color(210, 225, 245, 255),
            .font_size = 11,
        })) {
            document.loadMapFromPath(map_path);
        }

        drawPlayButton(document, .IDI("play-custom-btn-", @intCast(button_index)), map_path, category);
    });
}

fn drawZoomControls(maybe_camera: ?*lm.Camera) void {
    const active_camera = maybe_camera orelse return;
    const zoom_percent: u32 = @intFromFloat(active_camera.zoom * 100.0);

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
        if (drawSidebarButton(.ID("zoom-out-btn"), " - ", .{
            .padding = .axes(6, 6),
            .sizing = .{},
            .background_color = ui.color(40, 50, 70, 220),
            .text_color = ui.color(220, 230, 255, 255),
            .corner_radius_pixels = 3.0,
        })) {
            active_camera.zoom = std.math.clamp(active_camera.zoom / 1.2, 0.15, 4.0);
        }

        ui.new(.{
            .id = .ID("zoom-label"),
            .layout = .{ .sizing = .{ .w = .grow }, .child_alignment = .{ .x = .center } },
        })({
            ui.textFmt("Zoom: {d}%", .{zoom_percent}, .{
                .color = ui.color(200, 215, 235, 255),
                .font_size = 11,
                .letter_spacing = 1,
            });
        });

        if (drawSidebarButton(.ID("zoom-in-btn"), " + ", .{
            .padding = .axes(6, 6),
            .sizing = .{},
            .background_color = ui.color(40, 50, 70, 220),
            .text_color = ui.color(220, 230, 255, 255),
            .corner_radius_pixels = 3.0,
        })) {
            active_camera.zoom = std.math.clamp(active_camera.zoom * 1.2, 0.15, 4.0);
        }

        if (drawSidebarButton(.ID("zoom-reset-btn"), "Reset", .{
            .padding = .axes(6, 6),
            .sizing = .{},
            .background_color = ui.color(50, 40, 60, 220),
            .text_color = ui.color(240, 200, 150, 255),
            .corner_radius_pixels = 3.0,
            .font_size = 11,
        })) {
            active_camera.target = .init(0, 0);
            active_camera.zoom = 0.65;
        }
    });
}

fn drawStatusBar(status_message: []const u8) void {
    ui.new(.{
        .id = .ID("editor-status-bar"),
        .layout = .{ .sizing = .{ .w = .grow }, .padding = .all(6) },
        .background_color = ui.color(10, 12, 18, 255),
        .corner_radius = .all(4),
    })({
        ui.text(status_message, .{
            .color = ui.color(240, 200, 100, 255),
            .font_size = 11,
            .letter_spacing = 1,
        });
    });
}

fn appendSavePopupCharacter(document: *MapEditorDocument, char_code: i32) void {
    if (document.map_name_length >= document.map_name_buffer.len - 1) return;
    if (char_code < 32 or char_code > 126) return;

    const char_byte: u8 = @intCast(char_code);
    const is_valid_character = std.ascii.isAlphanumeric(char_byte) or char_byte == '_' or char_byte == '-';
    if (!is_valid_character) return;

    document.map_name_buffer[document.map_name_length] = char_byte;
    document.map_name_length += 1;
}

fn handleSavePopupInput(document: *MapEditorDocument) void {
    var char_code = rl.getCharPressed();
    while (char_code > 0) : (char_code = rl.getCharPressed()) {
        appendSavePopupCharacter(document, char_code);
    }

    const backspace_pressed = lm.keyboard.getKeyDown(rl.KeyboardKey.backspace) or
        lm.keyboard.getKeyDownRepeat(rl.KeyboardKey.backspace);
    if (backspace_pressed and document.map_name_length > 0) {
        document.map_name_length -= 1;
    }

    if (lm.keyboard.getKeyDown(rl.KeyboardKey.enter)) {
        document.confirmSaveMap();
    } else if (lm.keyboard.getKeyDown(rl.KeyboardKey.escape)) {
        document.show_save_popup = false;
    }
}

fn drawCategoryChoiceButton(document: *MapEditorDocument, category: RoomType) void {
    const is_selected = (document.selected_arena_category == category);
    if (drawSidebarButton(.IDI("save-cat-opt-", @intFromEnum(category)), category.displayName(), .{
        .alignment = .{ .x = .center },
        .background_color = if (is_selected) ui.color(70, 130, 220, 240) else ui.color(32, 38, 52, 200),
        .text_color = if (is_selected) ui.color(255, 255, 255, 255) else ui.color(180, 195, 215, 255),
        .border = .{
            .color = if (is_selected) ui.color(120, 180, 255, 255) else ui.color(50, 60, 80, 160),
            .width = .outside(1),
        },
        .font_size = 11,
    })) {
        document.selected_arena_category = category;
    }
}

fn drawSavePopupActions(document: *MapEditorDocument) void {
    ui.new(.{
        .id = .ID("save-modal-actions"),
        .layout = .{
            .direction = .left_to_right,
            .child_gap = 10,
            .sizing = .{ .w = .grow },
        },
    })({
        if (drawSidebarButton(.ID("modal-cancel-btn"), "Cancel", .{
            .padding = .axes(8, 14),
            .alignment = .{ .x = .center },
            .background_color = ui.color(55, 60, 75, 220),
            .text_color = ui.color(220, 230, 245, 255),
        })) {
            document.show_save_popup = false;
        }

        const has_name = document.map_name_length > 0;
        if (drawSidebarButton(.ID("modal-confirm-save-btn"), "Save Map", .{
            .padding = .axes(8, 14),
            .alignment = .{ .x = .center },
            .background_color = if (has_name) ui.color(40, 140, 70, 240) else ui.color(30, 60, 40, 160),
            .text_color = ui.color(255, 255, 255, 255),
            .is_disabled = !has_name,
        })) {
            document.confirmSaveMap();
        }
    });
}

fn drawSaveNameInputBox(document: *const MapEditorDocument) void {
    const current_name = document.map_name_buffer[0..document.map_name_length];
    clay.UI()(.{
        .id = .ID("save-name-input-box"),
        .layout = .{ .padding = .axes(10, 12), .sizing = .{ .w = .grow } },
        .background_color = ui.color(10, 14, 22, 255),
        .border = .{ .color = ui.color(70, 130, 220, 220), .width = .outside(1) },
        .corner_radius = .all(4),
    })({
        if (document.map_name_length > 0) {
            ui.textFmt("{s}_", .{current_name}, .{
                .color = ui.color(255, 255, 255, 255),
                .font_size = 13,
                .letter_spacing = 1,
            });
        } else {
            ui.text("Type map name...", .{
                .color = ui.color(120, 130, 150, 255),
                .font_size = 13,
                .letter_spacing = 1,
            });
        }
    });
}

fn drawSaveCategoryButtons(document: *MapEditorDocument) void {
    ui.new(.{
        .id = .ID("save-category-buttons"),
        .layout = .{ .direction = .left_to_right, .child_gap = 8, .sizing = .{ .w = .grow } },
    })({
        inline for (std.enums.values(RoomType)) |room_type| {
            if (room_type != .tutorial) {
                drawCategoryChoiceButton(document, room_type);
            }
        }
    });
}

fn drawSavePopupCard(document: *MapEditorDocument) void {
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

        drawSaveNameInputBox(document);

        ui.text("SELECT ARENA CATEGORY:", .{
            .color = ui.color(170, 185, 210, 255),
            .font_size = 11,
            .letter_spacing = 1,
        });

        drawSaveCategoryButtons(document);

        const current_name = document.map_name_buffer[0..document.map_name_length];
        const preview_name = if (document.map_name_length > 0) current_name else "...";
        ui.textFmt(
            "Destination: assets/maps/{s}/{s}.json",
            .{ document.selected_arena_category.directoryCategory(), preview_name },
            .{
                .color = ui.color(140, 160, 190, 255),
                .font_size = 11,
                .letter_spacing = 1,
            },
        );

        drawSavePopupActions(document);
    });
}

fn drawSavePopup(document: *MapEditorDocument, window_size_pixels: lm.Vector2) void {
    ui.new(.{
        .id = .ID("save-modal-backdrop"),
        .floating = .{
            .attach_to = .to_root,
            .attach_points = .{ .element = .left_top, .parent = .left_top },
            .z_index = 100,
        },
        .layout = .{
            .sizing = .{ .w = .fixed(window_size_pixels.x), .h = .fixed(window_size_pixels.y) },
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center, .y = .center },
        },
        .background_color = ui.color(6, 8, 14, 210),
    })({
        drawSavePopupCard(document);
    });
}
