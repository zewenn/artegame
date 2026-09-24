const std = @import("std");
const lm = @import("loom");

const prefabs = @import("../../prefabs/prefabs.zig");
const Door = @import("../../components/world/Door.zig");
const BoonCategory = @import("../boons/BoonCategory.zig");
const MapLoader = @import("../map/MapLoader.zig");
const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const RoomType = @import("../RoomManager.zig").RoomType;

const Self = @This();

pub fn spawnReplenishDoors(
    current_room_number: u32,
    player_stats: ?Stats,
    player_attack: ?Attack,
) !void {
    cleanupDoors();

    const next_room_number = current_room_number + 1;
    const next_room_type = RoomType.fromRoomNumber(next_room_number);
    const editor_door_positions = MapLoader.getExitDoorPositions();

    if (next_room_type == .boss) {
        try spawnSpecialDoor(0, editor_door_positions, .{
            .door_index = 0,
            .category_id = "Boss",
            .title = "Boss Room",
            .icon = "ui/icons/goliath_icon.png",
            .reward_kind = .boss,
            .is_open = true,
        });
        return;
    }

    if (next_room_type == .mini_boss) {
        try spawnSpecialDoor(0, editor_door_positions, .{
            .door_index = 0,
            .category_id = "Mini-Boss",
            .title = "Mini-Boss",
            .icon = "ui/icons/goliath_icon.png",
            .reward_kind = .mini_boss,
            .is_open = true,
        });
        return;
    }

    if (next_room_type == .tutorial) {
        try spawnSpecialDoor(0, editor_door_positions, .{
            .door_index = 0,
            .category_id = "Tutorial",
            .title = "Tutorial",
            .icon = "ui/icons/empty_icon.png",
            .reward_kind = .boon_category,
            .is_open = true,
        });
        return;
    }

    try spawnNormalRoomDoors(editor_door_positions, player_stats, player_attack);
}

fn spawnSpecialDoor(
    door_index: usize,
    editor_door_positions: []const lm.Vector2,
    config: Door.DoorConfig,
) !void {
    const door_position = if (editor_door_positions.len > door_index)
        editor_door_positions[door_index]
    else
        MapLoader.getExitDoorPosition();

    const door_entity = try prefabs.ExitDoor(door_position, config);
    try lm.summoning.entity(door_entity);
}

fn spawnNormalRoomDoors(
    editor_door_positions: []const lm.Vector2,
    maybe_stats: ?Stats,
    maybe_attack: ?Attack,
) !void {
    var category_buffer: [BoonCategory.all_categories.len]BoonCategory = undefined;
    var eligible_categories: []const BoonCategory = &.{};

    if (maybe_stats) |stats| {
        if (maybe_attack) |attack| {
            eligible_categories = BoonCategory.selectEligibleCategories(stats, attack, &category_buffer);
        }
    }

    if (eligible_categories.len == 0) {
        eligible_categories = &BoonCategory.all_categories;
    }

    var shuffled_categories: [BoonCategory.all_categories.len]BoonCategory = undefined;
    const category_count = eligible_categories.len;
    @memcpy(shuffled_categories[0..category_count], eligible_categories);

    var remaining_count = category_count;
    while (remaining_count > 1) {
        const random_index = lm.random.intRangeLessThan(usize, 0, remaining_count);
        remaining_count -= 1;
        const temporary_category = shuffled_categories[remaining_count];
        shuffled_categories[remaining_count] = shuffled_categories[random_index];
        shuffled_categories[random_index] = temporary_category;
    }

    const available_positions_count = if (editor_door_positions.len > 0)
        editor_door_positions.len
    else
        1;

    const doors_to_spawn_count = @min(available_positions_count, @min(3, category_count));

    for (0..doors_to_spawn_count) |door_index| {
        const chosen_category = shuffled_categories[door_index];
        const door_position = if (editor_door_positions.len > door_index)
            editor_door_positions[door_index]
        else
            MapLoader.getExitDoorPosition();

        const door_entity = try prefabs.ExitDoor(door_position, .{
            .door_index = door_index,
            .category_id = chosen_category.id,
            .title = chosen_category.name,
            .icon = chosen_category.icon,
            .reward_kind = .boon_category,
            .is_open = true,
        });
        try lm.summoning.entity(door_entity);
    }
}

pub fn cleanupDoors() void {
    const scene = lm.activeScene() orelse return;
    for (scene.entities.items()) |entity| {
        if (std.mem.startsWith(u8, entity.id, "exit-door")) {
            lm.removeEntity(.{ .ptr = entity });
        }
    }
}

test "DoorSpawner room rules determine correct room types and door constraints" {
    const tutorial_room_type = RoomType.fromRoomNumber(0);
    try std.testing.expectEqual(RoomType.tutorial, tutorial_room_type);

    const normal_room_type = RoomType.fromRoomNumber(1);
    try std.testing.expectEqual(RoomType.normal, normal_room_type);

    const mini_boss_room_type = RoomType.fromRoomNumber(5);
    try std.testing.expectEqual(RoomType.mini_boss, mini_boss_room_type);

    const boss_room_type = RoomType.fromRoomNumber(15);
    try std.testing.expectEqual(RoomType.boss, boss_room_type);

    const editor_positions = [_]lm.Vector2{
        .init(100, 100),
        .init(200, 200),
        .init(300, 300),
    };
    const max_doors_to_spawn = @min(editor_positions.len, @min(3, BoonCategory.all_categories.len));
    try std.testing.expectEqual(@as(usize, 3), max_doors_to_spawn);
}
