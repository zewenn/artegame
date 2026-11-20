const std = @import("std");

const Self = @This();

pub const Objective = struct {
    name: []const u8,
    description: []const u8,
};

current: ?Objective = null,

pub fn setSingleObjective(self: *Self, name: []const u8, description: []const u8) error{}!void {
    self.current = .{
        .name = name,
        .description = description,
    };
}

pub fn clear(self: *Self) void {
    self.current = null;
}

pub fn trackingObjective(self: *const Self) ?Objective {
    return self.current;
}

test "Objectives setSingleObjective and clear manage active objective without heap allocation" {
    var objectives: Self = .{};

    try objectives.setSingleObjective("Phase 1", "Fight wave 1");
    try std.testing.expectEqualStrings("Phase 1", objectives.trackingObjective().?.name);
    try std.testing.expectEqualStrings("Fight wave 1", objectives.trackingObjective().?.description);

    try objectives.setSingleObjective("Phase 2", "Replenish");
    try std.testing.expectEqualStrings("Phase 2", objectives.trackingObjective().?.name);

    objectives.clear();
    try std.testing.expect(objectives.trackingObjective() == null);
}
