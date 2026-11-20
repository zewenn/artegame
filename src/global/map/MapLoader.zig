const std = @import("std");
const lm = @import("loom");
const MapTypes = @import("MapTypes.zig");
const MapData = MapTypes.MapData;
const SpawnZoneRecord = MapTypes.SpawnZoneRecord;
const MapRenderer = @import("MapRenderer.zig");
const WallMesher = @import("WallMesher.zig");
const MapSerializer = @import("MapSerializer.zig");

/// Loom behaviour rendering the baked map background texture at the lowest Z-layer.
pub const MapBackgroundBehaviour = struct {
    const BehaviourSelf = @This();

    renderer: ?*MapRenderer = null,
    transform: ?*lm.Transform = null,

    pub fn Start(self: *BehaviourSelf, entity: *lm.Entity) !void {
        self.transform = entity.getComponent(lm.Transform);
    }

    pub fn Update(self: *BehaviourSelf, entity: *lm.Entity) !void {
        const active_renderer = self.renderer orelse return;
        const texture = active_renderer.getTexture() orelse return;
        const transform = self.transform orelse return;

        try lm.display.addRenderer(.{
            .renderer = .{ .texture = .{
                .texture = texture,
                .transform = transform.*,
                .tint = lm.deps.rl.Color.white,
                .fill_color = null,
                .entity = entity,
            } },
            .index = lm.toisize(transform.position.z),
        });
    }
};

var global_renderer: MapRenderer = MapRenderer.init();
var wall_entities: lm.List(*lm.Entity) = undefined;
var is_initialized: bool = false;
var active_arena: ?std.heap.ArenaAllocator = null;
var override_arena: ?std.heap.ArenaAllocator = null;

var active_spawn_zones: []SpawnZoneRecord = &.{};
var active_player_spawn: lm.Vector2 = .init(0, 0);
var active_exit_door: lm.Vector2 = .init(128, -200);
var active_exit_doors: []lm.Vector2 = &.{};
var active_map_top_left_pixels: lm.Vector2 = .init(0, 0);
var active_map_width_pixels: f32 = 2200.0;
var active_map_height_pixels: f32 = 1040.0;
var in_memory_map_override: ?MapData = null;

/// Sets or clears an in-memory map override (deep-cloned) for editor playtesting.
pub fn setInMemoryMapOverride(maybe_data: ?MapData) void {
    if (override_arena) |*arena| {
        arena.deinit();
        override_arena = null;
    }
    in_memory_map_override = null;

    const source_data = maybe_data orelse return;
    var next_arena = std.heap.ArenaAllocator.init(lm.allocators.generic());
    const cloned_data = source_data.clone(next_arena.allocator()) catch |clone_error| {
        std.log.err("Failed to clone in-memory map override: {any}", .{clone_error});
        next_arena.deinit();
        return;
    };

    override_arena = next_arena;
    in_memory_map_override = cloned_data;
}

/// Initializes the global map loader state if not already initialized.
pub fn init() void {
    if (is_initialized) return;
    wall_entities = lm.List(*lm.Entity).init(lm.allocators.generic());
    global_renderer = MapRenderer.init();
    is_initialized = true;
}

/// Returns the world-space spawn zones of the currently loaded map.
pub fn getSpawnZones() []const SpawnZoneRecord {
    return active_spawn_zones;
}

/// Returns the world-space player spawn position of the currently loaded map.
pub fn getPlayerSpawnPosition() lm.Vector2 {
    return active_player_spawn;
}

/// Returns the primary world-space exit door position of the currently loaded map.
pub fn getExitDoorPosition() lm.Vector2 {
    if (active_exit_doors.len > 0) {
        return active_exit_doors[0];
    }
    return active_exit_door;
}

/// Returns all world-space exit door positions of the currently loaded map.
pub fn getExitDoorPositions() []const lm.Vector2 {
    return active_exit_doors;
}

/// Returns the world-space min/max pixel bounding box of the currently loaded map.
pub fn getMapBounds() struct { min: lm.Vector2, max: lm.Vector2 } {
    return .{
        .min = active_map_top_left_pixels,
        .max = lm.Vec2(
            active_map_top_left_pixels.x + active_map_width_pixels,
            active_map_top_left_pixels.y + active_map_height_pixels,
        ),
    };
}

/// Despawns active map wall/background entities and releases map arena memory and baked textures.
pub fn unload() void {
    if (is_initialized) {
        for (wall_entities.items()) |entity| {
            lm.removeEntity(.{ .ptr = entity });
        }
        wall_entities.clearRetainingCapacity();
    }

    if (active_arena) |*arena| {
        arena.deinit();
        active_arena = null;
    }

    active_spawn_zones = &.{};
    active_exit_doors = &.{};
    global_renderer.deinit();
}

fn fillWallSegmentTiles(
    background_tiles: []u8,
    width_tiles: u32,
    height_tiles: u32,
    wall: MapTypes.WallSegment,
) void {
    const wall_value: u8 = @intFromEnum(wall.wall_type.terrainType());
    const bounds = wall.tileBounds();

    var row_index = bounds.min_y;
    while (row_index <= bounds.max_y and row_index < height_tiles) : (row_index += 1) {
        var column_index = bounds.min_x;
        while (column_index <= bounds.max_x and column_index < width_tiles) : (column_index += 1) {
            background_tiles[row_index * width_tiles + column_index] = wall_value;
        }
    }
}

/// Paints rectangular wall segments back onto the flat terrain tile grid.
pub fn applyWallSegmentsToTiles(
    background_tiles: []u8,
    width_tiles: u32,
    height_tiles: u32,
    walls: []const MapTypes.WallSegment,
) void {
    for (walls) |wall| {
        fillWallSegmentTiles(background_tiles, width_tiles, height_tiles, wall);
    }
}

fn spawnWallColliders(
    arena_allocator: std.mem.Allocator,
    map_data: MapData,
    top_left_x_pixels: f32,
    top_left_y_pixels: f32,
) !void {
    const tile_size_pixels = @as(f32, @floatFromInt(map_data.tile_size_pixels));
    const wall_colliders = try WallMesher.meshGridFromTiles(
        arena_allocator,
        map_data.background_tiles,
        map_data.width_tiles,
        map_data.height_tiles,
        tile_size_pixels,
    );

    for (wall_colliders, 0..) |collider, wall_index| {
        const world_center_x_pixels = top_left_x_pixels + collider.center_position.x;
        const world_center_y_pixels = top_left_y_pixels + collider.center_position.y;

        const world_collider = WallMesher.WallCollider{
            .center_position = lm.Vec2(world_center_x_pixels, world_center_y_pixels),
            .scale = collider.scale,
            .wall_type = collider.wall_type,
        };

        var identifier_buffer: [32]u8 = undefined;
        const wall_identifier = try std.fmt.bufPrint(&identifier_buffer, "wall_{d}", .{wall_index});

        const wall_entity = try world_collider.createEntity(wall_identifier);
        try wall_entities.append(wall_entity);
        try lm.summoning.entity(wall_entity);
    }
}

fn loadSpawnZonesWorldSpace(
    arena_allocator: std.mem.Allocator,
    source_zones: []const SpawnZoneRecord,
    top_left_x_pixels: f32,
    top_left_y_pixels: f32,
) ![]SpawnZoneRecord {
    const converted_spawn_zones = try arena_allocator.alloc(SpawnZoneRecord, source_zones.len);
    for (source_zones, 0..) |zone, zone_index| {
        converted_spawn_zones[zone_index] = SpawnZoneRecord{
            .center_x_pixels = top_left_x_pixels + zone.center_x_pixels,
            .center_y_pixels = top_left_y_pixels + zone.center_y_pixels,
            .width_pixels = zone.width_pixels,
            .height_pixels = zone.height_pixels,
            .enemy_type = zone.enemy_type,
        };
    }
    return converted_spawn_zones;
}

fn loadEntityMarkers(
    arena_allocator: std.mem.Allocator,
    entities: []const MapTypes.EntityRecord,
    top_left_x_pixels: f32,
    top_left_y_pixels: f32,
) !void {
    active_player_spawn = .init(0, 0);
    active_exit_door = .init(0, top_left_y_pixels + 128);

    var exit_door_list = lm.List(lm.Vector2).init(arena_allocator);

    for (entities) |entity_record| {
        const entity_world_x_pixels = top_left_x_pixels + entity_record.position_x;
        const entity_world_y_pixels = top_left_y_pixels + entity_record.position_y;
        const world_position = lm.Vec2(entity_world_x_pixels, entity_world_y_pixels);

        if (std.mem.eql(u8, entity_record.entity_type, "player_spawn")) {
            active_player_spawn = world_position;
        } else if (std.mem.eql(u8, entity_record.entity_type, "exit_door")) {
            active_exit_door = world_position;
            try exit_door_list.append(world_position);
        }
    }

    active_exit_doors = exit_door_list.items();
}

/// Loads a map from the active override or disk, bakes its terrain, and summons colliders and background.
pub fn loadAndInstantiate(relative_map_path: []const u8) !void {
    init();
    unload();

    var arena = std.heap.ArenaAllocator.init(lm.allocators.generic());
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const map_data = if (in_memory_map_override) |override_data|
        try override_data.clone(arena_allocator)
    else
        try MapSerializer.loadFromFile(arena_allocator, relative_map_path);
    active_arena = arena;

    const tile_size_pixels = @as(f32, @floatFromInt(map_data.tile_size_pixels));
    const width_pixels = @as(f32, @floatFromInt(map_data.width_tiles)) * tile_size_pixels;
    const height_pixels = @as(f32, @floatFromInt(map_data.height_tiles)) * tile_size_pixels;

    const top_left_x_pixels = -width_pixels / 2.0;
    const top_left_y_pixels = -height_pixels / 2.0;
    active_map_top_left_pixels = lm.Vec2(top_left_x_pixels, top_left_y_pixels);
    active_map_width_pixels = width_pixels;
    active_map_height_pixels = height_pixels;

    applyWallSegmentsToTiles(
        map_data.background_tiles,
        map_data.width_tiles,
        map_data.height_tiles,
        map_data.walls,
    );

    try global_renderer.configureDimensions(map_data.width_tiles, map_data.height_tiles, tile_size_pixels);
    try global_renderer.bake(map_data.background_tiles);

    try spawnWallColliders(arena_allocator, map_data, top_left_x_pixels, top_left_y_pixels);
    active_spawn_zones = try loadSpawnZonesWorldSpace(
        arena_allocator,
        map_data.spawn_zones,
        top_left_x_pixels,
        top_left_y_pixels,
    );
    try loadEntityMarkers(arena_allocator, map_data.entities, top_left_x_pixels, top_left_y_pixels);

    const half_tile_pixels = tile_size_pixels * 0.5;
    const background_entity = try lm.makeEntity("map_background", .{
        lm.Transform{
            .position = lm.Vec3(half_tile_pixels, half_tile_pixels, -2000),
            .scale = lm.Vec2(width_pixels, height_pixels),
        },
        MapBackgroundBehaviour{
            .renderer = &global_renderer,
        },
    });
    try wall_entities.append(background_entity);
    try lm.summoning.entity(background_entity);
}
