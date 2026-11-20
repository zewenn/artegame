const std = @import("std");
const lm = @import("loom");

const Self = @This();

pub const OnInteractFn = *const fn (interactable: *Self, player: *lm.Entity) void;
pub const CanInteractFn = *const fn () bool;

var registry: ?lm.List(*Self) = null;
var focused_item: ?*Self = null;
var last_update_time_seconds: f32 = -1.0;

entity: ?*lm.Entity = null,
transform: ?*lm.Transform = null,
interaction_radius: f32 = 96.0,
action_text: []const u8 = "Interact",
prompt_offset: lm.Vector2 = .init(0, -64.0),
enabled: bool = true,
is_focused: bool = false,
can_interact: ?CanInteractFn = null,
on_interact: ?OnInteractFn = null,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.entity = entity;
    self.transform = try entity.pullComponent(lm.Transform);
    self.register();
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
    const player_position = lm.vec3ToVec2(player_transform.position);

    refreshFocus(player_position);

    if (!self.is_focused) return;
    const is_interact_pressed = lm.keyboard.getKeyDown(.f) or
        (lm.gamepad.isAvailable(0) and lm.gamepad.getButtonDown(0, .right_face_down));

    if (is_interact_pressed) {
        self.trigger(player);
    }
}

pub fn End(self: *Self) void {
    self.unregister();
    self.is_focused = false;
}

pub fn register(self: *Self) void {
    if (registry == null) {
        registry = lm.List(*Self).init(lm.allocators.generic());
    }
    const list = &(registry.?);
    for (list.items()) |item| {
        if (item == self) return;
    }
    list.append(self) catch |register_error| {
        std.log.err("Failed to register interactable: {any}", .{register_error});
    };
}

pub fn unregister(self: *Self) void {
    const list = &(registry orelse return);
    for (list.items(), 0..) |item, item_index| {
        if (item != self) continue;

        _ = list.swapRemove(item_index);
        if (focused_item == self) {
            focused_item = null;
        }
        return;
    }
}

pub fn clearRegistry() void {
    if (registry) |*list| {
        list.clearRetainingCapacity();
    }
    focused_item = null;
    last_update_time_seconds = -1.0;
}

pub fn deinitRegistry() void {
    if (registry) |*list| {
        list.deinit();
        registry = null;
    }
    focused_item = null;
    last_update_time_seconds = -1.0;
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

fn findClosest(player_position: lm.Vector2, reset_focus: bool) ?*Self {
    const list = &(registry orelse return null);
    var closest_item: ?*Self = null;
    var minimum_distance_squared_pixels: f32 = std.math.floatMax(f32);

    for (list.items()) |item| {
        if (reset_focus) item.is_focused = false;
        if (!item.isActive()) continue;
        const transform = item.transform orelse continue;

        const item_position = lm.vec3ToVec2(transform.position);
        const delta_x_pixels = item_position.x - player_position.x;
        const delta_y_pixels = item_position.y - player_position.y;
        const distance_squared_pixels = delta_x_pixels * delta_x_pixels + delta_y_pixels * delta_y_pixels;
        const interaction_radius_squared_pixels = item.interaction_radius * item.interaction_radius;

        if (distance_squared_pixels <= interaction_radius_squared_pixels and distance_squared_pixels < minimum_distance_squared_pixels) {
            minimum_distance_squared_pixels = distance_squared_pixels;
            closest_item = item;
        }
    }

    return closest_item;
}

fn refreshFocus(player_position: lm.Vector2) void {
    const current_time_seconds = lm.time.appTime();
    if (current_time_seconds == last_update_time_seconds) return;
    last_update_time_seconds = current_time_seconds;

    const closest_item = findClosest(player_position, true);
    if (closest_item) |item| {
        item.is_focused = true;
    }
    focused_item = closest_item;
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

test "Interactable dynamic registration and squared distance closest selection" {
    clearRegistry();
    defer deinitRegistry();

    var first_transform: lm.Transform = .{ .position = .init(100, 100, 0) };
    var second_transform: lm.Transform = .{ .position = .init(50, 50, 0) };

    var first_item: Self = .{
        .transform = &first_transform,
        .interaction_radius = 80.0,
    };
    var second_item: Self = .{
        .transform = &second_transform,
        .interaction_radius = 80.0,
    };

    first_item.register();
    second_item.register();
    try std.testing.expect(registry != null);
    try std.testing.expectEqual(@as(usize, 2), registry.?.len());

    const closest_to_second = findClosest(.init(40, 40), false);
    try std.testing.expect(closest_to_second == &second_item);

    const closest_to_first = findClosest(.init(90, 90), false);
    try std.testing.expect(closest_to_first == &first_item);

    const closest_out_of_range = findClosest(.init(500, 500), false);
    try std.testing.expect(closest_out_of_range == null);

    second_item.unregister();
    try std.testing.expectEqual(@as(usize, 1), registry.?.len());
    const closest_after_unregister = findClosest(.init(40, 40), false);
    try std.testing.expect(closest_after_unregister == null);
}
