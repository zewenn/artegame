const std = @import("std");
const lm = @import("loom");
const RoomType = @import("../RoomType.zig").RoomType;

/// Resolves a room category string (`@tagName` or `displayName`, case-insensitive) into a RoomType.
pub fn parseRoomType(category_name: []const u8) ?RoomType {
    inline for (std.enums.values(RoomType)) |room_type| {
        if (std.ascii.eqlIgnoreCase(category_name, @tagName(room_type)) or
            std.ascii.eqlIgnoreCase(category_name, room_type.displayName()))
        {
            return room_type;
        }
    }
    return null;
}

/// Returns the default bundled map path for a given room type.
pub fn getDefaultMapPath(room_type: RoomType) []const u8 {
    if (room_type == .mini_boss) return "maps/mini_boss/knight_arena.json";
    return room_type.defaultMapPath();
}

/// Scans the asset directory for maps belonging to the given room type, falling back to its default map.
pub fn getAvailableMapsAlloc(allocator: std.mem.Allocator, room_type: RoomType) ![]const []const u8 {
    var map_paths = lm.List([]const u8).init(allocator);
    errdefer {
        for (map_paths.items()) |path| allocator.free(path);
        map_paths.deinit();
    }

    const default_map = getDefaultMapPath(room_type);
    if (room_type == .tutorial) {
        try map_paths.append(try allocator.dupe(u8, default_map));
        return try map_paths.toOwnedSlice();
    }

    const category_directory = room_type.directoryCategory();

    const relative_directory_path = try std.fmt.allocPrint(allocator, "maps/{s}", .{category_directory});
    defer allocator.free(relative_directory_path);

    const resolved_directory_path = lm.assets.files.getFilePath(relative_directory_path) catch null;
    defer if (resolved_directory_path) |resolved_path| lm.allocators.generic().free(resolved_path);

    scanDirectoryForMaps(allocator, &map_paths, category_directory, resolved_directory_path);

    if (map_paths.len() == 0) {
        try map_paths.append(try allocator.dupe(u8, default_map));
    }

    return try map_paths.toOwnedSlice();
}

fn scanDirectoryForMaps(
    allocator: std.mem.Allocator,
    map_paths: *lm.List([]const u8),
    category_directory: []const u8,
    maybe_directory_path: ?[]const u8,
) void {
    const directory_path = maybe_directory_path orelse return;
    const io = lm.io.singleThreaded();

    var directory = std.Io.Dir.openDirAbsolute(io, directory_path, .{ .iterate = true }) catch return;
    defer directory.close(io);

    var iterator = directory.iterate();
    while (iterator.next(io) catch null) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".json")) continue;

        const relative_map_path = std.fmt.allocPrint(allocator, "maps/{s}/{s}", .{
            category_directory,
            entry.name,
        }) catch continue;

        map_paths.append(relative_map_path) catch {
            allocator.free(relative_map_path);
            continue;
        };
    }
}

/// Filters candidate map paths to exclude `previous_map_path` when alternatives exist.
pub fn filterCandidatesAvoidingPrevious(
    allocator: std.mem.Allocator,
    available_maps: []const []const u8,
    previous_map_path: []const u8,
) ![]const []const u8 {
    var candidates = lm.List([]const u8).init(allocator);
    defer candidates.deinit();

    for (available_maps) |map_path| {
        if (!std.mem.eql(u8, map_path, previous_map_path)) {
            try candidates.append(map_path);
        }
    }

    if (candidates.len() == 0) {
        return try allocator.dupe([]const u8, available_maps);
    }

    return try allocator.dupe([]const u8, candidates.items());
}

/// Picks a random map path for the room type, avoiding immediate repetition when multiple maps exist.
pub fn pickRandomMap(
    allocator: std.mem.Allocator,
    room_type: RoomType,
    previous_map_path: []const u8,
) ![]const u8 {
    const available_maps = try getAvailableMapsAlloc(allocator, room_type);
    defer {
        for (available_maps) |map_path| allocator.free(map_path);
        allocator.free(available_maps);
    }

    if (available_maps.len == 0) {
        return try allocator.dupe(u8, getDefaultMapPath(room_type));
    }

    if (available_maps.len == 1) {
        return try allocator.dupe(u8, available_maps[0]);
    }

    const candidates = try filterCandidatesAvoidingPrevious(allocator, available_maps, previous_map_path);
    defer allocator.free(candidates);

    const random_candidate_index = lm.random.intRangeLessThan(usize, 0, candidates.len);
    return try allocator.dupe(u8, candidates[random_candidate_index]);
}

test "parseRoomType matches tag names and display names case-insensitively" {
    try std.testing.expectEqual(@as(?RoomType, .normal), parseRoomType("normal"));
    try std.testing.expectEqual(@as(?RoomType, .mini_boss), parseRoomType("mini_boss"));
    try std.testing.expectEqual(@as(?RoomType, .mini_boss), parseRoomType("Mini-Boss"));
    try std.testing.expectEqual(@as(?RoomType, .boss), parseRoomType("Boss"));
    try std.testing.expectEqual(@as(?RoomType, .boss), parseRoomType("boss"));
    try std.testing.expectEqual(@as(?RoomType, .tutorial), parseRoomType("Tutorial"));
    try std.testing.expectEqual(@as(?RoomType, null), parseRoomType("unknown"));
}

test "getDefaultMapPath returns valid paths existing on disk for all room types" {
    try std.testing.expectEqualStrings("maps/normal/arena_normal.json", getDefaultMapPath(.normal));
    try std.testing.expectEqualStrings("maps/mini_boss/knight_arena.json", getDefaultMapPath(.mini_boss));
    try std.testing.expectEqualStrings("maps/boss/arena_boss.json", getDefaultMapPath(.boss));
    try std.testing.expectEqualStrings("maps/tutorial.json", getDefaultMapPath(.tutorial));

    const io = lm.io.singleThreaded();
    inline for (std.enums.values(RoomType)) |room_type| {
        const asset_path = try std.fmt.allocPrint(std.testing.allocator, "src/assets/{s}", .{getDefaultMapPath(room_type)});
        defer std.testing.allocator.free(asset_path);

        var file = try std.Io.Dir.cwd().openFile(io, asset_path, .{ .mode = .read_only });
        file.close(io);
    }
}

test "filterCandidatesAvoidingPrevious excludes previous map when alternatives exist" {
    const testing_allocator = std.testing.allocator;
    const dummy_maps = [_][]const u8{
        "maps/normal/map_1.json",
        "maps/normal/map_2.json",
        "maps/normal/map_3.json",
    };

    const filtered = try filterCandidatesAvoidingPrevious(testing_allocator, &dummy_maps, "maps/normal/map_1.json");
    defer testing_allocator.free(filtered);

    try std.testing.expectEqual(@as(usize, 2), filtered.len);
    try std.testing.expectEqualStrings("maps/normal/map_2.json", filtered[0]);
    try std.testing.expectEqualStrings("maps/normal/map_3.json", filtered[1]);

    const single_map = [_][]const u8{"maps/normal/map_1.json"};
    const fallback = try filterCandidatesAvoidingPrevious(testing_allocator, &single_map, "maps/normal/map_1.json");
    defer testing_allocator.free(fallback);

    try std.testing.expectEqual(@as(usize, 1), fallback.len);
    try std.testing.expectEqualStrings("maps/normal/map_1.json", fallback[0]);
}
