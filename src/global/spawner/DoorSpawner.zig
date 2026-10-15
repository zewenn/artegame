const std = @import("std");
const lm = @import("loom");

const prefabs = @import("../../prefabs/prefabs.zig");
const Door = @import("../../components/world/Door.zig");
const BoonCategory = @import("../boons/BoonCategory.zig");
const MapLoader = @import("../map/MapLoader.zig");
const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const RoomManager = @import("../RoomManager.zig");
const RoomType = RoomManager.RoomType;

const Self = @This();

pub fn spawnCombatDoors(
    current_room_number: u32,
    player_stats: ?Stats,
    player_attack: ?Attack,
) !void {
    try spawnRoomDoors(current_room_number, player_stats, player_attack, false);
}

pub fn spawnReplenishDoors(
    current_room_number: u32,
    player_stats: ?Stats,
    player_attack: ?Attack,
) !void {
    try spawnRoomDoors(current_room_number, player_stats, player_attack, true);
}

pub fn spawnRoomDoors(
    current_room_number: u32,
    player_stats: ?Stats,
    player_attack: ?Attack,
    is_open: bool,
) !void {
    cleanupDoors();

    const next_room_number = current_room_number + 1;
    const next_room_type = RoomType.fromRoomNumber(next_room_number);
    const editor_door_positions = MapLoader.getExitDoorPositions();

    if (RoomManager.isPlaytestMode()) {
        const door_count = @max(@as(usize, 1), editor_door_positions.len);
        for (0..door_count) |door_index| {
            try spawnSpecialDoor(door_index, editor_door_positions, .{
                .door_index = door_index,
                .category_id = "Map Editor",
                .title = "Map Editor",
                .icon = "ui/icons/empty_icon.png",
                .reward_kind = .boon_category,
                .is_open = is_open,
            });
        }
        return;
    }

    if (current_room_number == 0) {
        try spawnSpecialDoor(0, editor_door_positions, .{
            .door_index = 0,
            .category_id = "normal",
            .title = "Room 1",
            .icon = "ui/icons/empty_icon.png",
            .reward_kind = .boon_category,
            .is_open = is_open,
        });
        return;
    }

    if (next_room_type == .boss) {
        try spawnSpecialDoor(0, editor_door_positions, .{
            .door_index = 0,
            .category_id = "Boss",
            .title = "Boss Room",
            .icon = "ui/icons/goliath_icon.png",
            .reward_kind = .boss,
            .is_open = is_open,
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
            .is_open = is_open,
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
            .is_open = is_open,
        });
        return;
    }

    try spawnNormalRoomDoors(editor_door_positions, player_stats, player_attack, is_open);
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
    is_open: bool,
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
            .is_open = is_open,
        });
        try lm.summoning.entity(door_entity);
    }
}

pub fn openAllDoors() void {
    const scene = lm.activeScene() orelse return;
    for (scene.entities.items()) |entity| {
        openDoorEntity(entity);
    }
}

fn openDoorEntity(entity: *lm.Entity) void {
    if (!std.mem.startsWith(u8, entity.id, "exit-door")) return;
    const door = entity.getComponent(Door) orelse return;
    door.setOpenState(true);
}

pub fn hasDoorsInScene() bool {
    const scene = lm.activeScene() orelse return false;
    for (scene.entities.items()) |entity| {
        if (std.mem.startsWith(u8, entity.id, "exit-door")) return true;
    }
    return false;
}

pub fn cleanupDoors() void {
    const scene = lm.activeScene() orelse return;
    for (scene.entities.items()) |entity| {
        if (std.mem.startsWith(u8, entity.id, "exit-door")) {
            lm.removeEntity(.{ .ptr = entity });
        }
    }
}
