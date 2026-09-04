const std = @import("std");
const lm = @import("loom");

const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const Boon = @import("Boon.zig");
const boons = @import("boons.zig");

var current_boons: [3]?Boon = [_]?Boon{ null, null, null };
var active_slice_buffer: [3]Boon = undefined;
var has_rolled: bool = false;

pub fn reroll(stats: Stats, attack: Attack) void {
    var valid_indices: [boons.all_boons.len]usize = undefined;
    var valid_count: usize = 0;

    for (boons.all_boons, 0..) |b, i| {
        if (b.isAvailable(stats, attack)) {
            valid_indices[valid_count] = i;
            valid_count += 1;
        }
    }

    const draw_count = @min(3, valid_count);
    for (0..draw_count) |i| {
        const pick_index = lm.random.intRangeLessThan(usize, i, valid_count);
        const chosen_boon_index = valid_indices[pick_index];
        valid_indices[pick_index] = valid_indices[i];
        valid_indices[i] = chosen_boon_index;

        current_boons[i] = boons.all_boons[chosen_boon_index];
    }
    for (draw_count..3) |i| {
        current_boons[i] = null;
    }
    has_rolled = true;
}

pub fn getCurrentBoons(stats: Stats, attack: Attack) []const Boon {
    if (!has_rolled) {
        reroll(stats, attack);
    }

    var count: usize = 0;
    for (current_boons) |maybe_boon| {
        if (maybe_boon) |b| {
            active_slice_buffer[count] = b;
            count += 1;
        }
    }
    return active_slice_buffer[0..count];
}

pub fn consumeBoon(boon: Boon) void {
    for (&current_boons) |*maybe_boon| {
        if (maybe_boon.*) |b| {
            if (b.eql(boon)) {
                maybe_boon.* = null;
                break;
            }
        }
    }
}

pub fn reset() void {
    current_boons = [_]?Boon{ null, null, null };
    has_rolled = false;
}

test "BoonPool rolls 3 distinct valid boons and handles consumption & reroll" {
    reset();

    const stats = Stats{
        .team = .player,
    };
    const attack = Attack{};

    // Initial roll
    const initial_boons = getCurrentBoons(stats, attack);
    try std.testing.expectEqual(@as(usize, 3), initial_boons.len);

    // Verify distinct boons
    try std.testing.expect(!initial_boons[0].eql(initial_boons[1]));
    try std.testing.expect(!initial_boons[0].eql(initial_boons[2]));
    try std.testing.expect(!initial_boons[1].eql(initial_boons[2]));

    // Verify all are available
    for (initial_boons) |b| {
        try std.testing.expect(b.isAvailable(stats, attack));
    }

    // Consume first boon
    const first_boon = initial_boons[0];
    consumeBoon(first_boon);

    const remaining_after_one = getCurrentBoons(stats, attack);
    try std.testing.expectEqual(@as(usize, 2), remaining_after_one.len);
    for (remaining_after_one) |b| {
        try std.testing.expect(!b.eql(first_boon));
    }

    // Consume remaining boons
    consumeBoon(remaining_after_one[0]);
    consumeBoon(remaining_after_one[1]);

    const remaining_after_all = getCurrentBoons(stats, attack);
    try std.testing.expectEqual(@as(usize, 0), remaining_after_all.len);

    // Reroll for new round
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
    attack.equipped_weapons[1] = null; // No Goliath weapon

    for (0..10) |_| {
        reroll(stats, attack);
        const drawn = getCurrentBoons(stats, attack);
        for (drawn) |b| {
            try std.testing.expect(b.isAvailable(stats, attack));
        }
    }
}

