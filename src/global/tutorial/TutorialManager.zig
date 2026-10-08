const std = @import("std");
const lm = @import("loom");

const Objectives = @import("../../components/player/Objectives.zig");
const Dashing = @import("../../components/Dashing.zig");
const Door = @import("../../components/world/Door.zig");
const Interactable = @import("../../components/interaction/Interactable.zig");
const RoomManager = @import("../RoomManager.zig");
const AudioManager = @import("../audio/AudioManager.zig");
const DevicePrompts = @import("../input/DevicePrompts.zig");
const Projectile = @import("../../prefabs/Projectile.zig");

const Self = @This();

pub const TutorialStep = enum {
    move,
    dash,
    light_attack,
    heavy_attack,
    dash_attack,
    exit_door,
    completed,
};

const MIN_MOVEMENT_DISTANCE_PIXELS: f32 = 120.0;

var global_instance: ?*Self = null;

step: TutorialStep = .move,
accumulated_movement_pixels: f32 = 0.0,
previous_player_position: ?lm.Vector2 = null,
has_opened_door: bool = false,

pub fn Awake(self: *Self) !void {
    global_instance = self;
    self.reset();
}

pub fn Start(self: *Self) void {
    if (!isTutorialActive()) return;
    self.lockExitDoor();
    self.refreshObjectives();
}

pub fn Update(self: *Self) !void {
    if (!isTutorialActive()) return;
    if (self.step == .completed) return;

    const player = lm.getEntity(.{ .id = "player" }) orelse return;
    const transform = player.getComponent(lm.Transform) orelse return;
    const player_position = lm.vec3ToVec2(transform.position);

    switch (self.step) {
        .move => {
            if (self.previous_player_position) |previous_position| {
                const distance = player_position.subtract(previous_position).length();
                self.accumulated_movement_pixels += distance;
                if (self.accumulated_movement_pixels >= MIN_MOVEMENT_DISTANCE_PIXELS) {
                    self.advanceStep(.dash);
                }
            }
            self.previous_player_position = player_position;
        },
        .dash => {
            if (player.getComponent(Dashing)) |dashing| {
                if (dashing.isDashing()) {
                    self.advanceStep(.light_attack);
                }
            }
        },
        .light_attack, .heavy_attack, .dash_attack => {},
        .exit_door => {
            if (!self.has_opened_door) {
                self.unlockExitDoor();
            }
        },
        .completed => {},
    }
}

pub fn End(self: *Self) void {
    if (global_instance == self) {
        global_instance = null;
    }
}

pub fn get() ?*Self {
    return global_instance;
}

pub fn isTutorialActive() bool {
    const room_manager = RoomManager.get() orelse return false;
    return room_manager.getRoomType() == .tutorial;
}

pub fn reset(self: *Self) void {
    self.step = .move;
    self.accumulated_movement_pixels = 0.0;
    self.previous_player_position = null;
    self.has_opened_door = false;
}

pub fn notifyDummyHit(attack_kind: Projectile.AttackKind) void {
    if (!isTutorialActive()) return;
    const self = get() orelse return;
    self.handleDummyHit(attack_kind);
}

pub fn handleDummyHit(self: *Self, attack_kind: Projectile.AttackKind) void {
    switch (self.step) {
        .light_attack => {
            if (attack_kind == .light) {
                self.advanceStep(.heavy_attack);
            }
        },
        .heavy_attack => {
            if (attack_kind == .heavy) {
                self.advanceStep(.dash_attack);
            }
        },
        .dash_attack => {
            if (attack_kind == .dash) {
                self.advanceStep(.exit_door);
                self.unlockExitDoor();
            }
        },
        else => {},
    }
}

pub fn advanceStep(self: *Self, next_step: TutorialStep) void {
    self.step = next_step;
    AudioManager.playSfxPitched("audio/sfx/coin.wav", 1.15, 0.05);
    self.refreshObjectives();
}

pub fn refreshObjectives(self: *Self) void {
    const player = lm.getEntity(.{ .id = "player" }) orelse return;
    const objectives = player.getComponent(Objectives) orelse return;
    const is_gamepad = DevicePrompts.isGamepad();

    switch (self.step) {
        .move => _ = objectives.setSingleObjective(
            "Movement",
            if (is_gamepad) "Use Left Stick to move" else "Use W, A, S, D to move",
        ) catch {},
        .dash => _ = objectives.setSingleObjective(
            "Dash",
            if (is_gamepad) "Press A to Dash" else "Press Space to Dash",
        ) catch {},
        .light_attack => _ = objectives.setSingleObjective(
            "Light Attack",
            if (is_gamepad) "Press RT to strike the Training Dummy" else "Left Click to strike the Training Dummy",
        ) catch {},
        .heavy_attack => _ = objectives.setSingleObjective(
            "Heavy Attack",
            if (is_gamepad) "Press LT for a heavy strike" else "Right Click for a heavy strike",
        ) catch {},
        .dash_attack => _ = objectives.setSingleObjective(
            "Dash Attack",
            if (is_gamepad) "Dash and press RT together" else "Dash and Left Click together",
        ) catch {},
        .exit_door => _ = objectives.setSingleObjective(
            "Enter Arena",
            if (is_gamepad) "Press A at the Exit Door to begin Room 1" else "Press F at the Exit Door to begin Room 1",
        ) catch {},
        .completed => _ = objectives.setSingleObjective(
            "Tutorial Complete",
            "Entering Room 1",
        ) catch {},
    }
}

pub fn lockExitDoor(self: *Self) void {
    _ = self;
    const scene = lm.activeScene() orelse return;
    for (scene.entities.items()) |entity| {
        if (std.mem.startsWith(u8, entity.id, "exit-door")) {
            if (entity.getComponent(Door)) |door| {
                door.setOpenState(false);
            }
            if (entity.getComponent(Interactable)) |interactable| {
                interactable.enabled = false;
            }
        }
    }
}

pub fn unlockExitDoor(self: *Self) void {
    self.has_opened_door = true;
    if (RoomManager.get()) |room_manager| {
        room_manager.state = .replenish;
    }
    const scene = lm.activeScene() orelse return;
    for (scene.entities.items()) |entity| {
        if (std.mem.startsWith(u8, entity.id, "exit-door")) {
            if (entity.getComponent(Door)) |door| {
                door.setOpenState(true);
            }
            if (entity.getComponent(Interactable)) |interactable| {
                interactable.enabled = true;
            }
        }
    }
}

test "TutorialManager step progression and dummy hit handling" {
    var manager = Self{};
    manager.reset();
    try std.testing.expectEqual(TutorialStep.move, manager.step);

    manager.step = .light_attack;
    manager.handleDummyHit(.heavy);
    try std.testing.expectEqual(TutorialStep.light_attack, manager.step);

    manager.handleDummyHit(.light);
    try std.testing.expectEqual(TutorialStep.heavy_attack, manager.step);

    manager.handleDummyHit(.heavy);
    try std.testing.expectEqual(TutorialStep.dash_attack, manager.step);

    manager.handleDummyHit(.dash);
    try std.testing.expectEqual(TutorialStep.exit_door, manager.step);
    try std.testing.expect(manager.has_opened_door);
}
