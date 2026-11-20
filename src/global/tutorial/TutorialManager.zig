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
};

const StepConfig = struct {
    title: []const u8,
    prompt_action: ?DevicePrompts.PromptAction = null,
    expected_attack_kind: ?Projectile.AttackKind = null,
    next_step: ?TutorialStep = null,
};

const step_configs = std.EnumArray(TutorialStep, StepConfig).init(.{
    .move = .{
        .title = "Movement",
        .next_step = .dash,
    },
    .dash = .{
        .title = "Dash",
        .prompt_action = .dash,
        .next_step = .light_attack,
    },
    .light_attack = .{
        .title = "Light Attack",
        .prompt_action = .attack_primary,
        .expected_attack_kind = .light,
        .next_step = .heavy_attack,
    },
    .heavy_attack = .{
        .title = "Heavy Attack",
        .prompt_action = .attack_secondary,
        .expected_attack_kind = .heavy,
        .next_step = .dash_attack,
    },
    .dash_attack = .{
        .title = "Dash Attack",
        .prompt_action = .attack_primary,
        .expected_attack_kind = .dash,
        .next_step = .exit_door,
    },
    .exit_door = .{
        .title = "Enter Arena",
        .prompt_action = .interact,
    },
});

const MIN_MOVEMENT_DISTANCE_PIXELS: f32 = 120.0;

var global_instance: ?*Self = null;

step: TutorialStep = .move,
accumulated_movement_pixels: f32 = 0.0,
previous_player_position: ?lm.Vector2 = null,
has_opened_door: bool = false,
objective_description_buffer: [128]u8 = undefined,

pub fn Awake(self: *Self) !void {
    global_instance = self;
    self.reset();
}

pub fn Start(self: *Self) void {
    if (!isTutorialActive()) return;
    self.setExitDoorsUnlocked(false);
    self.refreshObjectives();
}

pub fn Update(self: *Self) !void {
    if (!isTutorialActive()) return;

    const player = lm.getEntity(.{ .id = "player" }) orelse return;
    const transform = player.getComponent(lm.Transform) orelse return;
    const player_position = lm.vec3ToVec2(transform.position);

    switch (self.step) {
        .move => self.updateMovementStep(player_position),
        .dash => self.updateDashStep(player),
        .light_attack, .heavy_attack, .dash_attack => {},
        .exit_door => if (!self.has_opened_door) self.setExitDoorsUnlocked(true),
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
    const config = step_configs.get(self.step);
    const expected_attack_kind = config.expected_attack_kind orelse return;
    if (attack_kind != expected_attack_kind) return;

    const next_step = config.next_step orelse return;
    self.advanceStep(next_step);
    if (next_step == .exit_door) {
        self.setExitDoorsUnlocked(true);
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
    const config = step_configs.get(self.step);
    const is_gamepad = DevicePrompts.isGamepad();

    const title = if (self.step == .exit_door and RoomManager.isPracticeTutorialMode())
        "Exit Tutorial"
    else
        config.title;
    const description = self.formatStepDescription(config, is_gamepad);
    _ = objectives.setSingleObjective(title, description) catch {};
}

pub fn setExitDoorsUnlocked(self: *Self, unlocked: bool) void {
    if (unlocked) {
        self.has_opened_door = true;
        if (RoomManager.get()) |room_manager| {
            room_manager.state = .replenish;
        }
    }

    const scene = lm.activeScene() orelse return;
    for (scene.entities.items()) |entity| {
        if (!std.mem.startsWith(u8, entity.id, "exit-door")) continue;
        if (entity.getComponent(Door)) |door| {
            door.setOpenState(unlocked);
        }
        if (entity.getComponent(Interactable)) |interactable| {
            interactable.enabled = unlocked;
        }
    }
}

fn updateMovementStep(self: *Self, player_position: lm.Vector2) void {
    if (self.previous_player_position) |previous_position| {
        const distance_pixels = player_position.subtract(previous_position).length();
        self.accumulated_movement_pixels += distance_pixels;
        if (self.accumulated_movement_pixels >= MIN_MOVEMENT_DISTANCE_PIXELS) {
            self.advanceStep(.dash);
        }
    }
    self.previous_player_position = player_position;
}

fn updateDashStep(self: *Self, player: *lm.Entity) void {
    const dashing = player.getComponent(Dashing) orelse return;
    if (dashing.isDashing()) {
        self.advanceStep(.light_attack);
    }
}

fn formatStepDescription(self: *Self, config: StepConfig, is_gamepad: bool) []const u8 {
    return switch (self.step) {
        .move => if (is_gamepad) "Use Left Stick to move" else "Use W, A, S, D to move",
        .dash => self.formatSinglePrompt("Press {s} to Dash", config.prompt_action.?),
        .light_attack => self.formatSinglePrompt("Press {s} to strike the Training Dummy", config.prompt_action.?),
        .heavy_attack => self.formatSinglePrompt("Press {s} for a heavy strike", config.prompt_action.?),
        .dash_attack => self.formatDualPrompt(
            "Press {s} and {s} together",
            .dash,
            config.prompt_action.?,
        ),
        .exit_door => if (RoomManager.isPracticeTutorialMode())
            self.formatSinglePrompt("Press {s} at the Exit Door to return to Main Menu", config.prompt_action.?)
        else
            self.formatSinglePrompt("Press {s} at the Exit Door to begin Room 1", config.prompt_action.?),
    };
}

fn formatSinglePrompt(self: *Self, comptime format_string: []const u8, action: DevicePrompts.PromptAction) []const u8 {
    const label = DevicePrompts.getActionPrompt(action).label;
    return std.fmt.bufPrint(&self.objective_description_buffer, format_string, .{label}) catch label;
}

fn formatDualPrompt(
    self: *Self,
    comptime format_string: []const u8,
    first_action: DevicePrompts.PromptAction,
    second_action: DevicePrompts.PromptAction,
) []const u8 {
    const first_label = DevicePrompts.getActionPrompt(first_action).label;
    const second_label = DevicePrompts.getActionPrompt(second_action).label;
    return std.fmt.bufPrint(&self.objective_description_buffer, format_string, .{ first_label, second_label }) catch first_label;
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
