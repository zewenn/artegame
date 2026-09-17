const std = @import("std");
const lm = @import("loom");
const MapTypes = @import("MapTypes.zig");
const MapData = MapTypes.MapData;
const SpawnZoneRecord = MapTypes.SpawnZoneRecord;
const MapRenderer = @import("MapRenderer.zig");
const WallMesher = @import("WallMesher.zig");
const MapSerializer = @import("MapSerializer.zig");
const prefabs = @import("../../prefabs/prefabs.zig");

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

        try lm.display.add(.{
            .texture = texture,
            .transform = transform.*,
            .display = .{
                .img_path = "map_background",
                .tint = lm.deps.rl.Color.white,
                .fill_color = null,
            },
            .entity = entity,
        });
    }
};

var global_renderer: MapRenderer = MapRenderer.init();
var wall_entities: lm.List(*lm.Entity) = undefined;
var is_initialized: bool = false;
var active_arena: ?std.heap.ArenaAllocator = null;

var active_spawn_zones: []SpawnZoneRecord = &.{};
var active_player_spawn: lm.Vector2 = .init(0, 0);
var active_exit_door: lm.Vector2 = .init(128, -200);
var active_map_top_left: lm.Vector2 = .init(0, 0);

pub fn init() void {
    if (is_initialized) return;
    wall_entities = lm.List(*lm.Entity).init(lm.allocators.generic());
    global_renderer = MapRenderer.init();
    is_initialized = true;
}

pub fn deinit() void {
    unload();
    if (is_initialized) {
        wall_entities.deinit();
        global_renderer.deinit();
        is_initialized = false;
    }
}

pub fn getSpawnZones() []const SpawnZoneRecord {
    return active_spawn_zones;
}

pub fn getPlayerSpawnPosition() lm.Vector2 {
    return active_player_spawn;
}

pub fn getExitDoorPosition() lm.Vector2 {
    return active_exit_door;
}

pub fn getMapTopLeft() lm.Vector2 {
    return active_map_top_left;
}

pub fn getRenderer() *MapRenderer {
    return &global_renderer;
}

/// Unloads active map entities, colliders, and textures.
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
    global_renderer.deinit();
}

/// Loads and instantiates a map layout into the active scene.
pub fn loadAndInstantiate(relative_map_path: []const u8) !void {
    init();
    unload();

    var arena = std.heap.ArenaAllocator.init(lm.allocators.generic());
    errdefer arena.deinit();
    const arena_allocator = arena.allocator();

    const map_data = try MapSerializer.loadFromFile(arena_allocator, relative_map_path);
    active_arena = arena;

    const width_pixels = @as(f32, @floatFromInt(map_data.width_tiles)) * @as(f32, @floatFromInt(map_data.tile_size_pixels));
    const height_pixels = @as(f32, @floatFromInt(map_data.height_tiles)) * @as(f32, @floatFromInt(map_data.tile_size_pixels));

    // Center map around origin (0, 0)
    const top_left_x = -width_pixels / 2.0;
    const top_left_y = -height_pixels / 2.0;
    active_map_top_left = lm.Vec2(top_left_x, top_left_y);

    // Bake background into single RenderTexture
    try global_renderer.configureDimensions(
        map_data.width_tiles,
        map_data.height_tiles,
        @as(f32, @floatFromInt(map_data.tile_size_pixels)),
    );
    try global_renderer.bake(map_data.background_tiles);

    // Generate 1D greedy meshed colliders for walls
    const tile_size = @as(f32, @floatFromInt(map_data.tile_size_pixels));
    const wall_colliders = try WallMesher.meshSegments(arena_allocator, map_data.walls, tile_size);

    for (wall_colliders, 0..) |collider, wall_index| {
        const world_center_x = top_left_x + collider.center_position.x;
        const world_center_y = top_left_y + collider.center_position.y;

        const world_collider = WallMesher.WallCollider{
            .center_position = lm.Vec2(world_center_x, world_center_y),
            .scale = collider.scale,
            .wall_type = collider.wall_type,
        };

        var identifier_buffer: [32]u8 = undefined;
        const wall_identifier = try std.fmt.bufPrint(&identifier_buffer, "wall_{d}", .{wall_index});

        const wall_entity = try world_collider.createEntity(wall_identifier);
        try wall_entities.append(wall_entity);
        try lm.summoning.entity(wall_entity);
    }

    // Process spawn zones (offset to world coordinates)
    const converted_spawn_zones = try arena_allocator.alloc(SpawnZoneRecord, map_data.spawn_zones.len);
    for (map_data.spawn_zones, 0..) |zone, zone_index| {
        converted_spawn_zones[zone_index] = SpawnZoneRecord{
            .center_x_pixels = top_left_x + zone.center_x_pixels,
            .center_y_pixels = top_left_y + zone.center_y_pixels,
            .width_pixels = zone.width_pixels,
            .height_pixels = zone.height_pixels,
        };
    }
    active_spawn_zones = converted_spawn_zones;

    // Process entity markers
    active_player_spawn = .init(0, 0);
    active_exit_door = .init(0, top_left_y + 128);

    for (map_data.entities) |entity_record| {
        const entity_world_x = top_left_x + entity_record.position_x;
        const entity_world_y = top_left_y + entity_record.position_y;

        if (std.mem.eql(u8, entity_record.entity_type, "player_spawn")) {
            active_player_spawn = lm.Vec2(entity_world_x, entity_world_y);
        } else if (std.mem.eql(u8, entity_record.entity_type, "exit_door")) {
            active_exit_door = lm.Vec2(entity_world_x, entity_world_y);
        }
    }

    const half_tile = @as(f32, @floatFromInt(map_data.tile_size_pixels)) * 0.5;
    const background_entity = try lm.makeEntity("map_background", .{
        lm.Transform{
            .position = lm.Vec3(half_tile, half_tile, -2000),
            .scale = lm.Vec2(width_pixels, height_pixels),
        },
        MapBackgroundBehaviour{
            .renderer = &global_renderer,
        },
    });
    try wall_entities.append(background_entity);
    try lm.summoning.entity(background_entity);
}
