const std = @import("std");
const lm = @import("loom");

pub fn getDefaultMapPath(arena_category: []const u8) []const u8 {
    if (std.mem.eql(u8, arena_category, "boss")) {
        return "maps/boss/arena_boss.json";
    }
    if (std.mem.eql(u8, arena_category, "mini_boss") or std.mem.eql(u8, arena_category, "Mini-Boss")) {
        return "maps/mini_boss/arena_normal.json";
    }
    if (std.mem.eql(u8, arena_category, "tutorial") or std.mem.eql(u8, arena_category, "Tutorial")) {
        return "maps/tutorial.json";
    }
    return "maps/normal/arena_normal.json";
}

pub fn getAvailableMapsAlloc(allocator: std.mem.Allocator, arena_category: []const u8) ![]const []const u8 {
    var map_paths = lm.List([]const u8).init(allocator);
    errdefer {
        for (map_paths.items()) |path| allocator.free(path);
        map_paths.deinit();
    }

    const default_map = getDefaultMapPath(arena_category);
    if (std.mem.eql(u8, arena_category, "tutorial") or std.mem.eql(u8, arena_category, "Tutorial")) {
        try map_paths.append(try allocator.dupe(u8, default_map));
        return try map_paths.toOwnedSlice();
    }

    const category_directory = if (std.mem.eql(u8, arena_category, "mini_boss") or std.mem.eql(u8, arena_category, "Mini-Boss"))
        "mini_boss"
    else if (std.mem.eql(u8, arena_category, "boss") or std.mem.eql(u8, arena_category, "Boss"))
        "boss"
    else
        "normal";

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

    var directory = std.Io.Dir.openDirAbsolute(io, directory_path, .{ .iterate = true }) catch {
        return;
    };
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

pub fn pickRandomMap(
    allocator: std.mem.Allocator,
    arena_category: []const u8,
    previous_map_path: []const u8,
) ![]const u8 {
    const available_maps = try getAvailableMapsAlloc(allocator, arena_category);
    defer {
        for (available_maps) |map_path| allocator.free(map_path);
        allocator.free(available_maps);
    }

    if (available_maps.len == 0) {
        return try allocator.dupe(u8, getDefaultMapPath(arena_category));
    }

    if (available_maps.len == 1) {
        return try allocator.dupe(u8, available_maps[0]);
    }

    var candidate_count: usize = 0;
    for (available_maps) |map_path| {
        if (!std.mem.eql(u8, map_path, previous_map_path)) {
            candidate_count += 1;
        }
    }

    if (candidate_count == 0) {
        const random_index = lm.random.intRangeLessThan(usize, 0, available_maps.len);
        return try allocator.dupe(u8, available_maps[random_index]);
    }

    const random_candidate_index = lm.random.intRangeLessThan(usize, 0, candidate_count);
    var current_candidate_index: usize = 0;

    for (available_maps) |map_path| {
        if (std.mem.eql(u8, map_path, previous_map_path)) continue;

        if (current_candidate_index == random_candidate_index) {
            return try allocator.dupe(u8, map_path);
        }
        current_candidate_index += 1;
    }

    return try allocator.dupe(u8, available_maps[0]);
}

test "getDefaultMapPath returns valid paths for categories" {
    try std.testing.expectEqualStrings("maps/normal/arena_normal.json", getDefaultMapPath("normal"));
    try std.testing.expectEqualStrings("maps/mini_boss/arena_normal.json", getDefaultMapPath("mini_boss"));
    try std.testing.expectEqualStrings("maps/boss/arena_boss.json", getDefaultMapPath("boss"));
    try std.testing.expectEqualStrings("maps/tutorial.json", getDefaultMapPath("tutorial"));
}

test "pickRandomMap avoids repeating previous map when multiple candidates exist" {
    const testing_allocator = std.testing.allocator;

    const dummy_maps = [_][]const u8{
        "maps/normal/map_1.json",
        "maps/normal/map_2.json",
    };

    const previous = "maps/normal/map_1.json";
    var filtered_count: usize = 0;
    var picked_candidate: []const u8 = "";

    for (dummy_maps) |map_path| {
        if (!std.mem.eql(u8, map_path, previous)) {
            filtered_count += 1;
            picked_candidate = map_path;
        }
    }

    try std.testing.expectEqual(@as(usize, 1), filtered_count);
    try std.testing.expectEqualStrings("maps/normal/map_2.json", picked_candidate);

    const duped = try testing_allocator.dupe(u8, picked_candidate);
    defer testing_allocator.free(duped);
    try std.testing.expectEqualStrings("maps/normal/map_2.json", duped);
}
