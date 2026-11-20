const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const Boon = @import("Boon.zig");
const boons = @import("boons.zig");
const BoonCategory = @import("BoonCategory.zig");
const RoomManager = @import("../RoomManager.zig");

/// Offered boon entry along with whether it has been purchased in the current room.
pub const BoonSlot = struct {
    boon: Boon,
    is_purchased: bool = false,
};

var current_slots: [3]?BoonSlot = [_]?BoonSlot{ null, null, null };
var active_slots_buffer: [3]BoonSlot = undefined;
var has_rolled: bool = false;
var current_category: ?[]const u8 = null;

fn collectAvailableBoonIndices(
    boon_slice: []const Boon,
    stats: *const Stats,
    attack: *const Attack,
    destination_indices: []usize,
) usize {
    var available_count: usize = 0;
    for (boon_slice, 0..) |boon, boon_index| {
        if (boon.isAvailable(stats, attack)) {
            destination_indices[available_count] = boon_index;
            available_count += 1;
        }
    }
    return available_count;
}

/// Rolls up to three distinct eligible boons from `category_id`, falling back to all boons when empty.
pub fn rerollCategory(stats: Stats, attack: Attack, category_id: []const u8) void {
    current_category = category_id;

    var candidate_boons: []const Boon = boons.all_boons;
    if (BoonCategory.getCategoryById(category_id)) |category| {
        candidate_boons = category.boons;
    }

    var valid_indices: [boons.all_boons.len]usize = undefined;
    var valid_count = collectAvailableBoonIndices(candidate_boons, &stats, &attack, &valid_indices);

    if (valid_count == 0 and candidate_boons.len != boons.all_boons.len) {
        candidate_boons = boons.all_boons;
        valid_count = collectAvailableBoonIndices(candidate_boons, &stats, &attack, &valid_indices);
    }

    const draw_count = @min(3, valid_count);
    for (0..draw_count) |slot_index| {
        const pick_index = lm.random.intRangeLessThan(usize, slot_index, valid_count);
        const chosen_boon_index = valid_indices[pick_index];
        valid_indices[pick_index] = valid_indices[slot_index];
        valid_indices[slot_index] = chosen_boon_index;

        current_slots[slot_index] = .{
            .boon = candidate_boons[chosen_boon_index],
            .is_purchased = false,
        };
    }
    for (draw_count..3) |slot_index| {
        current_slots[slot_index] = null;
    }
    has_rolled = true;
}

/// Rerolls the active boon pool using the current category or the active room's category.
pub fn reroll(stats: Stats, attack: Attack) void {
    if (current_category) |category_id| {
        rerollCategory(stats, attack, category_id);
        return;
    }
    const room_category = RoomManager.getRoomCategory();
    rerollCategory(stats, attack, room_category);
}

/// Returns the active offered boon slots, rolling an initial set if needed.
pub fn getSlots(stats: Stats, attack: Attack) []const BoonSlot {
    if (!has_rolled) {
        reroll(stats, attack);
    }

    var count: usize = 0;
    for (current_slots) |maybe_slot| {
        const slot = maybe_slot orelse continue;
        active_slots_buffer[count] = slot;
        count += 1;
    }
    return active_slots_buffer[0..count];
}

/// Marks the matching offered boon slot as purchased.
pub fn consumeBoon(boon: Boon) void {
    for (&current_slots) |*maybe_slot| {
        const slot = &(maybe_slot.* orelse continue);
        if (slot.boon.equals(boon)) {
            slot.is_purchased = true;
            break;
        }
    }
}

/// Clears all rolled boon slots and the cached category selection.
pub fn reset() void {
    current_slots = [_]?BoonSlot{ null, null, null };
    has_rolled = false;
    current_category = null;
}

fn containsBoon(boon_list: []const Boon, target_boon: Boon) bool {
    for (boon_list) |candidate_boon| {
        if (candidate_boon.equals(target_boon)) return true;
    }
    return false;
}

test "BoonPool rolls 3 distinct valid boons and handles consumption & reroll" {
    reset();

    const stats = Stats{ .team = .player };
    const attack = Attack{};

    const initial_slots = getSlots(stats, attack);
    try std.testing.expectEqual(@as(usize, 3), initial_slots.len);

    try std.testing.expect(!initial_slots[0].boon.equals(initial_slots[1].boon));
    try std.testing.expect(!initial_slots[0].boon.equals(initial_slots[2].boon));
    try std.testing.expect(!initial_slots[1].boon.equals(initial_slots[2].boon));

    for (initial_slots) |slot| {
        try std.testing.expect(!slot.is_purchased);
        try std.testing.expect(slot.boon.isAvailable(&stats, &attack));
    }

    const first_boon = initial_slots[0].boon;
    consumeBoon(first_boon);

    const slots_after_one = getSlots(stats, attack);
    try std.testing.expectEqual(@as(usize, 3), slots_after_one.len);
    try std.testing.expect(slots_after_one[0].is_purchased);
    try std.testing.expect(!slots_after_one[1].is_purchased);
    try std.testing.expect(!slots_after_one[2].is_purchased);
    try std.testing.expect(slots_after_one[0].boon.equals(first_boon));

    consumeBoon(slots_after_one[1].boon);
    consumeBoon(slots_after_one[2].boon);

    const slots_after_all = getSlots(stats, attack);
    for (slots_after_all) |slot| {
        try std.testing.expect(slot.is_purchased);
    }

    reroll(stats, attack);
    const new_round_slots = getSlots(stats, attack);
    try std.testing.expectEqual(@as(usize, 3), new_round_slots.len);
    for (new_round_slots) |slot| {
        try std.testing.expect(!slot.is_purchased);
    }
    try std.testing.expect(!new_round_slots[0].boon.equals(new_round_slots[1].boon));
    try std.testing.expect(!new_round_slots[0].boon.equals(new_round_slots[2].boon));
    try std.testing.expect(!new_round_slots[1].boon.equals(new_round_slots[2].boon));
}

test "BoonPool respects weapon availability conditions" {
    reset();

    const stats = Stats{ .team = .player };
    var attack = Attack{};
    attack.equipped_weapons[1] = null;

    for (0..10) |_| {
        reroll(stats, attack);
        const drawn_slots = getSlots(stats, attack);
        for (drawn_slots) |slot| {
            try std.testing.expect(slot.boon.isAvailable(&stats, &attack));
        }
    }
}

test "BoonPool rerollCategory filters strictly to requested category" {
    reset();

    const stats = Stats{ .team = .player };
    const attack = Attack{};

    rerollCategory(stats, attack, "plates_damage");
    const plate_slots = getSlots(stats, attack);
    try std.testing.expectEqual(@as(usize, 3), plate_slots.len);
    for (plate_slots) |slot| {
        try std.testing.expect(containsBoon(boons.plates_damage_boons, slot.boon));
    }

    rerollCategory(stats, attack, "vitality");
    const vitality_slots = getSlots(stats, attack);
    try std.testing.expectEqual(@as(usize, 3), vitality_slots.len);
    for (vitality_slots) |slot| {
        try std.testing.expect(containsBoon(boons.vitality_boons, slot.boon));
    }
}

test "BoonPool rerollCategory falls back to all boons if category has no candidates" {
    reset();

    const stats = Stats{ .team = .player };
    var attack = Attack{};
    attack.equipped_weapons[1] = null;

    rerollCategory(stats, attack, "plates_damage");
    const drawn_slots = getSlots(stats, attack);
    try std.testing.expectEqual(@as(usize, 3), drawn_slots.len);
    for (drawn_slots) |slot| {
        try std.testing.expect(slot.boon.isAvailable(&stats, &attack));
        try std.testing.expect(!containsBoon(boons.plates_damage_boons, slot.boon));
    }
}
