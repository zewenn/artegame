const std = @import("std");
const lm = @import("loom");

const Self = @This();

pub const OnInteractFn = *const fn (interactable: *Self, player: *lm.Entity) void;
pub const CanInteractFn = *const fn () bool;

var registry: ?lm.List(*Self) = null;
var focused_item: ?*Self = null;
var last_update_time: f32 = -1.0;

transform: ?*lm.Transform = null,
interaction_radius: f32 = 96.0,
action_text: []const u8 = "Interact",
prompt_offset: lm.Vector2 = .init(0, -64.0),
enabled: bool = true,
is_focused: bool = false,
can_interact: ?CanInteractFn = null,
on_interact: ?OnInteractFn = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.transform = try entity.pullComponent(lm.Transform);
    self.register();
}

pub fn End(self: *Self) void {
    self.unregister();
    self.is_focused = false;
}

pub fn Update(self: *Self) !void {
    if (lm.time.paused() or !self.isActive()) {
        self.is_focused = false;
        return;
    }

    const scene = lm.activeScene() orelse return;
    const player = scene.getEntityById("player") orelse {
        self.is_focused = false;
        return;
    };
    const player_transform = player.getComponent(lm.Transform) orelse {
        self.is_focused = false;
        return;
    };
    const player_pos = lm.vec3ToVec2(player_transform.position);

    refreshFocus(player_pos);

    if (self.is_focused) {
        const is_interact_pressed = lm.keyboard.getKeyDown(.f) or (lm.gamepad.isAvailable(0) and lm.gamepad.getButtonDown(0, .right_face_down));
        if (is_interact_pressed) {
            self.trigger(player);
        }
    }
}

pub fn register(self: *Self) void {
    if (registry == null) {
        registry = lm.List(*Self).init(lm.allocators.generic());
    }
    const list = &(registry.?);
    for (list.items()) |item| {
        if (item == self) return;
    }
    list.append(self) catch |err| {
        std.log.err("Failed to register interactable: {any}", .{err});
    };
}

pub fn unregister(self: *Self) void {
    const list = &(registry orelse return);
    for (list.items(), 0..) |item, i| {
        if (item == self) {
            _ = list.swapRemove(i);
            if (focused_item == self) {
                focused_item = null;
            }
            return;
        }
    }
}

pub fn clearRegistry() void {
    if (registry) |*list| {
        list.clearRetainingCapacity();
    }
    focused_item = null;
    last_update_time = -1.0;
}

pub fn deinitRegistry() void {
    if (registry) |*list| {
        list.deinit();
        registry = null;
    }
    focused_item = null;
    last_update_time = -1.0;
}

pub fn isActive(self: *const Self) bool {
    if (!self.enabled) return false;
    if (self.can_interact) |check| {
        if (!check()) return false;
    }
    return true;
}

pub fn trigger(self: *Self, player: *lm.Entity) void {
    if (self.on_interact) |callback| {
        callback(self, player);
    }
}

fn refreshFocus(player_position: lm.Vector2) void {
    const current_time = lm.time.appTime();
    if (current_time == last_update_time) return;
    last_update_time = current_time;

    var closest: ?*Self = null;
    var min_dist_sq: f32 = std.math.floatMax(f32);

    const list = &(registry orelse return);
    for (list.items()) |item| {
        item.is_focused = false;
        if (!item.isActive()) continue;
        const transform = item.transform orelse continue;

        const pos2d = lm.vec3ToVec2(transform.position);
        const dx = pos2d.x - player_position.x;
        const dy = pos2d.y - player_position.y;
        const dist_sq = dx * dx + dy * dy;
        const radius_sq = item.interaction_radius * item.interaction_radius;

        if (dist_sq <= radius_sq and dist_sq < min_dist_sq) {
            min_dist_sq = dist_sq;
            closest = item;
        }
    }

    if (closest) |item| {
        item.is_focused = true;
    }
    focused_item = closest;
}

pub fn getClosest(player_position: lm.Vector2) ?*Self {
    var closest: ?*Self = null;
    var min_dist_sq: f32 = std.math.floatMax(f32);

    const list = &(registry orelse return null);
    for (list.items()) |item| {
        if (!item.isActive()) continue;
        const transform = item.transform orelse continue;

        const pos2d = lm.vec3ToVec2(transform.position);
        const dx = pos2d.x - player_position.x;
        const dy = pos2d.y - player_position.y;
        const dist_sq = dx * dx + dy * dy;
        const radius_sq = item.interaction_radius * item.interaction_radius;

        if (dist_sq <= radius_sq and dist_sq < min_dist_sq) {
            min_dist_sq = dist_sq;
            closest = item;
        }
    }

    return closest;
}

pub fn getFocused() ?*Self {
    if (focused_item) |item| {
        if (item.is_focused and item.isActive()) return item;
    }
    const list = &(registry orelse return null);
    for (list.items()) |item| {
        if (item.is_focused and item.isActive()) return item;
    }
    return null;
}

pub fn clearFocus() void {
    if (registry) |*list| {
        for (list.items()) |item| {
            item.is_focused = false;
        }
    }
    focused_item = null;
}

test "Interactable dynamic registration and squared distance closest selection" {
    clearRegistry();
    defer clearRegistry();

    var t1: lm.Transform = .{ .position = .init(100, 100, 0) };
    var t2: lm.Transform = .{ .position = .init(50, 50, 0) };

    var item1: Self = .{
        .transform = &t1,
        .interaction_radius = 80.0,
    };
    var item2: Self = .{
        .transform = &t2,
        .interaction_radius = 80.0,
    };

    item1.register();
    item2.register();
    try std.testing.expect(registry != null);
    try std.testing.expectEqual(@as(usize, 2), registry.?.len());

    const closest1 = getClosest(.init(40, 40));
    try std.testing.expect(closest1 == &item2);

    const closest2 = getClosest(.init(90, 90));
    try std.testing.expect(closest2 == &item1);

    const closest_none = getClosest(.init(500, 500));
    try std.testing.expect(closest_none == null);

    item2.unregister();
    try std.testing.expectEqual(@as(usize, 1), registry.?.len());
    const closest3 = getClosest(.init(40, 40));
    try std.testing.expect(closest3 == null);
}
