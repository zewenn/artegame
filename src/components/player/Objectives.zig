const std = @import("std");
const lm = @import("loom");

const Self = @This();

pub const Objective = struct {
    name: []const u8,
    description: []const u8,
    uuid: u128,

    pub fn init(name: []const u8, desc: []const u8) Objective {
        return Objective{
            .name = name,
            .description = desc,
            .uuid = lm.UUIDv7(),
        };
    }
};

tracking: ?u128 = null,
objectives: ?lm.List(Objective) = null,

pub fn Awake(self: *Self) void {
    self.objectives = .init(lm.allocators.scene());
}

pub fn End(self: *Self) void {
    const objectives = &(self.objectives orelse return);
    objectives.deinit();
    self.objectives = null;
}

pub fn addObjective(self: *Self, objective: Objective) !u128 {
    const objectives = &(self.objectives orelse return error.Uninitalised);

    try objectives.append(objective);
    self.tracking = objective.uuid;
    return objective.uuid;
}

pub fn clear(self: *Self) void {
    const objectives = &(self.objectives orelse return);
    objectives.clearRetainingCapacity();
    self.tracking = null;
}

pub fn setSingleObjective(self: *Self, name: []const u8, desc: []const u8) !u128 {
    self.clear();
    return try self.addObjective(.init(name, desc));
}

pub fn removeObjective(self: *Self, uuid: u128) void {
    const objectives = &(self.objectives orelse return);

    defer {
        if (self.tracking == uuid) self.tracking = null;
    }

    for (objectives.items(), 0..) |objective, index| {
        if (objective.uuid != uuid) continue;

        objectives.swapRemove(index);
        return;
    }
}

pub fn trackingObjective(self: *Self) ?Objective {
    const objectives = &(self.objectives orelse return null);
    const uuid = (self.tracking orelse return null);

    for (objectives.items()) |objective| {
        if (objective.uuid != uuid) continue;
        return objective;
    }

    return null;
}

test "Objectives.clear and setSingleObjective prevent unbounded list growth" {
    var obj_comp: Self = .{};
    obj_comp.objectives = .init(std.testing.allocator);
    defer obj_comp.End();

    _ = try obj_comp.setSingleObjective("Phase 1", "Fight wave 1");
    try std.testing.expectEqual(@as(usize, 1), obj_comp.objectives.?.items().len);
    try std.testing.expectEqualStrings("Phase 1", obj_comp.trackingObjective().?.name);

    _ = try obj_comp.setSingleObjective("Phase 2", "Replenish");
    try std.testing.expectEqual(@as(usize, 1), obj_comp.objectives.?.items().len);
    try std.testing.expectEqualStrings("Phase 2", obj_comp.trackingObjective().?.name);

    obj_comp.clear();
    try std.testing.expectEqual(@as(usize, 0), obj_comp.objectives.?.items().len);
    try std.testing.expect(obj_comp.trackingObjective() == null);
}
