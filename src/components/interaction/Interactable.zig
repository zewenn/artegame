const std = @import("std");
const lm = @import("loom");
const DemoMap = @import("../../global/DemoMap.zig");

const Self = @This();

pub const OnInteractFn = *const fn (interactable: *Self, player: *lm.Entity) void;
pub const CanInteractFn = *const fn () bool;

var registry: [64]?*Self = [_]?*Self{null} ** 64;

transform: ?*lm.Transform = null,
interaction_radius: f32 = 96.0,
action_text: []const u8 = "Interact",
prompt_offset: lm.Vector2 = .init(0, -64.0),
enabled: bool = true,
is_focused: bool = false,
can_interact: ?CanInteractFn = null,
on_interact: ?OnInteractFn = null,

pub fn register(self: *Self) void {
    for (&registry) |*slot| {
        if (slot.* == self) return;
    }
    for (&registry) |*slot| {
        if (slot.* == null) {
            slot.* = self;
            return;
        }
    }
}

pub fn unregister(self: *Self) void {
    for (&registry) |*slot| {
        if (slot.* == self) {
            slot.* = null;
            return;
        }
    }
}

pub fn clearRegistry() void {
    @memset(&registry, null);
}

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.transform = try entity.pullComponent(lm.Transform);
    self.register();
}

pub fn End(self: *Self) void {
    self.unregister();
    self.is_focused = false;
}

pub fn isActive(self: *const Self) bool {
    if (!self.enabled) return false;
    if (DemoMap.state == .combat) return false;
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

/// Finds the single closest active interactable within range of the given player position.
pub fn getClosest(player_position: lm.Vector2) ?*Self {
    var closest: ?*Self = null;
    var min_dist: f32 = std.math.floatMax(f32);

    for (registry) |maybe_item| {
        const item = maybe_item orelse continue;
        if (!item.isActive()) continue;
        const transform = item.transform orelse continue;

        const pos2d = lm.vec3ToVec2(transform.position);
        const dx = pos2d.x - player_position.x;
        const dy = pos2d.y - player_position.y;
        const dist = std.math.hypot(dx, dy);

        if (dist <= item.interaction_radius and dist < min_dist) {
            min_dist = dist;
            closest = item;
        }
    }

    return closest;
}

pub fn getFocused() ?*Self {
    for (registry) |maybe_item| {
        const item = maybe_item orelse continue;
        if (item.is_focused and item.isActive()) return item;
    }
    return null;
}

pub fn clearFocus() void {
    for (registry) |maybe_item| {
        const item = maybe_item orelse continue;
        item.is_focused = false;
    }
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

    const closest = getClosest(player_pos);
    self.is_focused = (closest == self);

    if (self.is_focused) {
        const is_interact_pressed = lm.keyboard.getKeyDown(.f) or (lm.gamepad.isAvailable(0) and lm.gamepad.getButtonDown(0, .right_face_down));
        if (is_interact_pressed) {
            self.trigger(player);
        }
    }
}
