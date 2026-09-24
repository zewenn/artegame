const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const Boon = @import("Boon.zig");
const boons = @import("boons.zig");
const BoonCategory = @import("BoonCategory.zig");
const RoomManager = @import("../RoomManager.zig");

pub const BoonSlot = struct {
    boon: Boon,
    is_purchased: bool = false,
};

var current_slots: [3]?BoonSlot = [_]?BoonSlot{ null, null, null };
var active_slots_buffer: [3]BoonSlot = undefined;
var active_slice_buffer: [3]Boon = undefined;
var has_rolled: bool = false;
var current_category: ?[]const u8 = null;

pub fn setCategory(category_id: ?[]const u8) void {
    current_category = category_id;
}

pub fn getCategory() ?[]const u8 {
    return current_category;
}

fn collectAvailableBoonIndices(
    boon_slice: []const Boon,
    stats: Stats,
    attack: Attack,
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

pub fn rerollCategory(stats: Stats, attack: Attack, category_id: []const u8) void {
    current_category = category_id;

    var candidate_boons: []const Boon = boons.all_boons;
    const is_unrestricted = std.mem.eql(u8, category_id, "normal") or
        std.mem.eql(u8, category_id, "Tutorial") or
        std.mem.eql(u8, category_id, "Mini-Boss") or
        std.mem.eql(u8, category_id, "Boss");

    if (!is_unrestricted) {
        if (BoonCategory.getCategoryById(category_id)) |category| {
            candidate_boons = category.boons;
        }
    }

    var valid_indices: [boons.all_boons.len]usize = undefined;
    var valid_count = collectAvailableBoonIndices(candidate_boons, stats, attack, &valid_indices);

    if (valid_count == 0 and candidate_boons.len != boons.all_boons.len) {
        candidate_boons = boons.all_boons;
        valid_count = collectAvailableBoonIndices(candidate_boons, stats, attack, &valid_indices);
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

pub fn reroll(stats: Stats, attack: Attack) void {
    if (current_category) |category_id| {
        rerollCategory(stats, attack, category_id);
        return;
    }
    const room_category = RoomManager.getRoomCategory();
    rerollCategory(stats, attack, room_category);
}

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

pub fn getCurrentBoons(stats: Stats, attack: Attack) []const Boon {
    if (!has_rolled) {
        reroll(stats, attack);
    }

    var count: usize = 0;
    for (current_slots) |maybe_slot| {
        const slot = maybe_slot orelse continue;
        if (slot.is_purchased) continue;
        active_slice_buffer[count] = slot.boon;
        count += 1;
    }
    return active_slice_buffer[0..count];
}

pub fn consumeBoon(boon: Boon) void {
    for (&current_slots) |*maybe_slot| {
        const slot = &(maybe_slot.* orelse continue);
        if (slot.boon.eql(boon)) {
            slot.is_purchased = true;
            break;
        }
    }
}

pub fn reset() void {
    current_slots = [_]?BoonSlot{ null, null, null };
    has_rolled = false;
    current_category = null;
}

test "BoonPool rolls 3 distinct valid boons and handles consumption & reroll" {
    reset();

    const stats = Stats{
        .team = .player,
    };
    const attack = Attack{};

    const initial_boons = getCurrentBoons(stats, attack);
    try std.testing.expectEqual(@as(usize, 3), initial_boons.len);

    try std.testing.expect(!initial_boons[0].eql(initial_boons[1]));
    try std.testing.expect(!initial_boons[0].eql(initial_boons[2]));
    try std.testing.expect(!initial_boons[1].eql(initial_boons[2]));

    for (initial_boons) |boon| {
        try std.testing.expect(boon.isAvailable(stats, attack));
    }

    const first_boon = initial_boons[0];
    consumeBoon(first_boon);

    const remaining_after_one = getCurrentBoons(stats, attack);
    try std.testing.expectEqual(@as(usize, 2), remaining_after_one.len);
    for (remaining_after_one) |boon| {
        try std.testing.expect(!boon.eql(first_boon));
    }

    consumeBoon(remaining_after_one[0]);
    consumeBoon(remaining_after_one[1]);

    const remaining_after_all = getCurrentBoons(stats, attack);
    try std.testing.expectEqual(@as(usize, 0), remaining_after_all.len);

    reroll(stats, attack);
    const new_round_boons = getCurrentBoons(stats, attack);
    try std.testing.expectEqual(@as(usize, 3), new_round_boons.len);
    try std.testing.expect(!new_round_boons[0].eql(new_round_boons[1]));
    try std.testing.expect(!new_round_boons[0].eql(new_round_boons[2]));
    try std.testing.expect(!new_round_boons[1].eql(new_round_boons[2]));
}

test "BoonPool respects weapon availability conditions" {
    reset();

    const stats = Stats{
        .team = .player,
    };
    var attack = Attack{};
    attack.equipped_weapons[1] = null;

    for (0..10) |_| {
        reroll(stats, attack);
        const drawn = getCurrentBoons(stats, attack);
        for (drawn) |boon| {
            try std.testing.expect(boon.isAvailable(stats, attack));
        }
    }
}

test "BoonPool getSlots retains consumed boons with is_purchased = true" {
    reset();

    const stats = Stats{ .team = .player };
    const attack = Attack{};

    const slots = getSlots(stats, attack);
    try std.testing.expectEqual(@as(usize, 3), slots.len);
    for (slots) |slot| {
        try std.testing.expect(!slot.is_purchased);
    }

    const first_boon = slots[0].boon;
    consumeBoon(first_boon);

    const slots_after_one = getSlots(stats, attack);
    try std.testing.expectEqual(@as(usize, 3), slots_after_one.len);
    try std.testing.expect(slots_after_one[0].is_purchased);
    try std.testing.expect(!slots_after_one[1].is_purchased);
    try std.testing.expect(!slots_after_one[2].is_purchased);
    try std.testing.expect(slots_after_one[0].boon.eql(first_boon));

    consumeBoon(slots_after_one[1].boon);
    consumeBoon(slots_after_one[2].boon);

    const slots_after_all = getSlots(stats, attack);
    try std.testing.expectEqual(@as(usize, 3), slots_after_all.len);
    for (slots_after_all) |slot| {
        try std.testing.expect(slot.is_purchased);
    }

    reset();
    try std.testing.expectEqual(@as(usize, 3), getSlots(stats, attack).len);
}

test "BoonPool rerollCategory filters strictly to requested category" {
    reset();

    const stats = Stats{ .team = .player };
    const attack = Attack{};

    rerollCategory(stats, attack, "plates_damage");
    const plate_slots = getSlots(stats, attack);
    try std.testing.expectEqual(@as(usize, 3), plate_slots.len);
    for (plate_slots) |slot| {
        var found_in_plates = false;
        for (boons.plates_damage_boons) |plate_boon| {
            if (slot.boon.eql(plate_boon)) {
                found_in_plates = true;
                break;
            }
        }
        try std.testing.expect(found_in_plates);
    }

    rerollCategory(stats, attack, "vitality");
    const vitality_slots = getSlots(stats, attack);
    try std.testing.expectEqual(@as(usize, 3), vitality_slots.len);
    for (vitality_slots) |slot| {
        var found_in_vitality = false;
        for (boons.vitality_boons) |vitality_boon| {
            if (slot.boon.eql(vitality_boon)) {
                found_in_vitality = true;
                break;
            }
        }
        try std.testing.expect(found_in_vitality);
    }
}

test "BoonPool rerollCategory falls back to all boons if category has no candidates" {
    reset();

    const stats = Stats{ .team = .player };
    var attack = Attack{};
    attack.equipped_weapons[0] = null;

    rerollCategory(stats, attack, "plates_damage");
    const drawn_slots = getSlots(stats, attack);
    try std.testing.expectEqual(@as(usize, 3), drawn_slots.len);
    for (drawn_slots) |slot| {
        try std.testing.expect(slot.boon.isAvailable(stats, attack));
    }
}
