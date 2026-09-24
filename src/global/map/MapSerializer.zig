const std = @import("std");
const lm = @import("loom");
const MapTypes = @import("MapTypes.zig");
const MapData = MapTypes.MapData;
const WallSegment = MapTypes.WallSegment;
const SpawnZoneRecord = MapTypes.SpawnZoneRecord;
const EntityRecord = MapTypes.EntityRecord;

pub fn serializeToJson(allocator: std.mem.Allocator, map_data: MapData) ![]const u8 {
    return try std.fmt.allocPrint(
        allocator,
        "{f}",
        .{std.json.fmt(map_data, .{ .whitespace = .indent_2 })},
    );
}

pub fn deserializeFromJson(allocator: std.mem.Allocator, json_content: []const u8) !MapData {
    const parsed = try std.json.parseFromSlice(
        MapData,
        allocator,
        json_content,
        .{
            .ignore_unknown_fields = true,
            .allocate = .alloc_always,
        },
    );
    return parsed.value;
}

pub fn resolveMapPathAlloc(allocator: std.mem.Allocator, relative_map_path: []const u8) ![]const u8 {
    const resolved_path = lm.assets.files.getFilePath(relative_map_path) catch {
        return try allocator.dupe(u8, relative_map_path);
    };
    return resolved_path;
}

pub fn saveToFile(allocator: std.mem.Allocator, relative_map_path: []const u8, map_data: MapData) !void {
    const io = lm.io.singleThreaded();
    const full_path = try resolveMapPathAlloc(allocator, relative_map_path);
    defer allocator.free(full_path);

    const json_string = try serializeToJson(allocator, map_data);
    defer allocator.free(json_string);

    if (std.fs.path.dirname(full_path)) |directory_path| {
        std.Io.Dir.cwd().createDirPath(io, directory_path) catch {};
    }

    var file = try std.Io.Dir.createFileAbsolute(io, full_path, .{});
    defer file.close(io);

    var write_buffer: [4096]u8 = undefined;
    var buffered_writer = file.writer(io, &write_buffer);
    var writer = &buffered_writer.interface;
    try writer.writeAll(json_string);
    try writer.flush();
}

pub fn loadFromFile(allocator: std.mem.Allocator, relative_map_path: []const u8) !MapData {
    const file_data = lm.assets.files.getData(relative_map_path) catch |err| blk: {
        if (std.mem.eql(u8, relative_map_path, "maps/arena_normal.json")) {
            break :blk try lm.assets.files.getData("maps/normal/arena_normal.json");
        } else if (std.mem.eql(u8, relative_map_path, "maps/arena_boss.json")) {
            break :blk try lm.assets.files.getData("maps/boss/arena_boss.json");
        }
        return err;
    };
    defer lm.allocators.generic().free(file_data);

    return try deserializeFromJson(allocator, file_data);
}

test "MapSerializer roundtrip JSON" {
    const testing_allocator = std.testing.allocator;

    var arena = std.heap.ArenaAllocator.init(testing_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const tiles = try arena_allocator.alloc(u8, 4);
    tiles[0] = 0;
    tiles[1] = 1;
    tiles[2] = 1;
    tiles[3] = 0;

    const walls = try arena_allocator.alloc(WallSegment, 2);
    walls[0] = .{ .start_x_tiles = 0, .start_y_tiles = 0, .end_x_tiles = 1, .end_y_tiles = 0, .wall_type = .solid };
    walls[1] = .{ .start_x_tiles = 0, .start_y_tiles = 1, .end_x_tiles = 1, .end_y_tiles = 1, .wall_type = .low };

    const spawn_zones = try arena_allocator.alloc(SpawnZoneRecord, 1);
    spawn_zones[0] = .{
        .center_x_pixels = 64.0,
        .center_y_pixels = 64.0,
        .width_pixels = 192.0,
        .height_pixels = 192.0,
    };

    const entities = try arena_allocator.alloc(EntityRecord, 1);
    entities[0] = .{
        .entity_type = "player_spawn",
        .position_x = 32.0,
        .position_y = 32.0,
    };

    const original_map = MapData{
        .version = 1,
        .name = "test_map",
        .width_tiles = 2,
        .height_tiles = 2,
        .tile_size_pixels = 64,
        .background_tiles = tiles,
        .walls = walls,
        .spawn_zones = spawn_zones,
        .entities = entities,
    };

    const json_string = try serializeToJson(arena_allocator, original_map);
    const parsed_map = try deserializeFromJson(arena_allocator, json_string);

    try std.testing.expectEqual(original_map.version, parsed_map.version);
    try std.testing.expectEqualStrings(original_map.name, parsed_map.name);
    try std.testing.expectEqual(original_map.width_tiles, parsed_map.width_tiles);
    try std.testing.expectEqual(original_map.height_tiles, parsed_map.height_tiles);
    try std.testing.expectEqual(original_map.background_tiles.len, parsed_map.background_tiles.len);
    try std.testing.expectEqual(original_map.walls.len, parsed_map.walls.len);
    try std.testing.expectEqual(MapTypes.WallType.solid, parsed_map.walls[0].wall_type);
    try std.testing.expectEqual(MapTypes.WallType.low, parsed_map.walls[1].wall_type);
    try std.testing.expectEqual(original_map.spawn_zones.len, parsed_map.spawn_zones.len);
    try std.testing.expectEqual(original_map.entities.len, parsed_map.entities.len);
}

test "MapSerializer deserializeFromJson supports integer array background_tiles" {
    const testing_allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(testing_allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    const sample_json =
        \\{
        \\  "version": 1,
        \\  "name": "array_test",
        \\  "width_tiles": 2,
        \\  "height_tiles": 2,
        \\  "tile_size_pixels": 64,
        \\  "background_tiles": [2, 3, 0, 1],
        \\  "walls": [],
        \\  "spawn_zones": [],
        \\  "entities": []
        \\}
    ;

    const parsed_map = try deserializeFromJson(arena_allocator, sample_json);
    try std.testing.expectEqual(@as(usize, 4), parsed_map.background_tiles.len);
    try std.testing.expectEqual(@as(u8, 2), parsed_map.background_tiles[0]);
    try std.testing.expectEqual(@as(u8, 3), parsed_map.background_tiles[1]);
    try std.testing.expectEqual(@as(u8, 0), parsed_map.background_tiles[2]);
    try std.testing.expectEqual(@as(u8, 1), parsed_map.background_tiles[3]);
}

test "MapSerializer verify all bundled map assets deserialize correctly" {
    const testing_allocator = std.testing.allocator;
    const io = lm.io.singleThreaded();

    const map_file_paths = [_][]const u8{
        "src/assets/maps/boss/arena_boss.json",
        "src/assets/maps/mini_boss/arena_normal.json",
        "src/assets/maps/normal/arena_normal.json",
        "src/assets/maps/tutorial.json",
    };

    for (map_file_paths) |map_path| {
        var arena = std.heap.ArenaAllocator.init(testing_allocator);
        defer arena.deinit();
        const arena_allocator = arena.allocator();

        var file = try std.Io.Dir.cwd().openFile(io, map_path, .{ .mode = .read_only });
        defer file.close(io);

        var buffer: [1024 * 256]u8 = undefined;
        const bytes_read = try file.readPositionalAll(io, &buffer, 0);
        const map_data = try deserializeFromJson(arena_allocator, buffer[0..bytes_read]);

        const expected_tile_count = map_data.width_tiles * map_data.height_tiles;
        try std.testing.expectEqual(expected_tile_count, map_data.background_tiles.len);
        try std.testing.expect(map_data.walls.len > 0);
    }
}
