const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;
const rl = lm.deps.rl;

const Interactable = @import("../interaction/Interactable.zig");
const RoomManager = @import("../../global/RoomManager.zig");
const AudioManager = @import("../../global/audio/AudioManager.zig");
const GameOverMenu = @import("../../global/ui/GameOverMenu.zig");
const PauseMenu = @import("../../global/ui/PauseMenu.zig");
const BoonMenu = @import("../../global/ui/BoonMenu.zig");

const Self = @This();

pub const RewardKind = enum {
    boon_category,
    mini_boss,
    boss,
};

pub const DoorConfig = struct {
    door_index: usize = 0,
    category_id: ?[]const u8 = null,
    title: []const u8 = "Next Room",
    icon: []const u8 = "ui/icons/empty_icon.png",
    reward_kind: RewardKind = .boon_category,
    is_open: bool = true,
};

transform: ?*lm.Transform = null,
renderer: ?*lm.Renderer = null,
interactable: ?*Interactable = null,
camera: ?*lm.Camera = null,

door_index: usize = 0,
category_id: ?[]const u8 = null,
reward_title: []const u8 = "Next Room",
reward_icon: []const u8 = "ui/icons/empty_icon.png",
reward_kind: RewardKind = .boon_category,
is_open: bool = true,
action_text_buffer: [64]u8 = [_]u8{0} ** 64,

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.transform = try entity.pullComponent(lm.Transform);
    self.renderer = entity.getComponent(lm.Renderer);
    self.interactable = entity.getComponent(Interactable);

    if (std.fmt.bufPrint(&self.action_text_buffer, "Enter: {s}", .{self.reward_title})) |formatted_text| {
        if (self.interactable) |interactable| {
            interactable.action_text = formatted_text;
        }
    } else |_| {}

    self.applyVisualState();
}

pub fn Start(self: *Self) void {
    const scene = lm.activeScene() orelse return;
    self.camera = scene.getCameraById("main");
}

pub fn Update(self: *Self) !void {
    if (!self.is_open or !RoomManager.isReplenish()) return;
    if (PauseMenu.isShowing() or GameOverMenu.isShowing() or BoonMenu.isShowing() or lm.time.paused()) return;

    const transform = self.transform orelse return;
    const camera = self.camera orelse {
        const scene = lm.activeScene() orelse return;
        self.camera = scene.getCameraById("main");
        return;
    };

    const door_position = lm.vec3ToVec2(transform.position);
    const overhead_world_position = door_position.add(.init(0, -68.0));
    const screen_position = camera.worldToScreenPos(overhead_world_position);

    const badge_id = @as(u32, @intCast(self.door_index));
    const border_color = switch (self.reward_kind) {
        .boss => ui.color(255, 205, 50, 255),
        .mini_boss => ui.color(195, 95, 255, 255),
        .boon_category => ui.color(75, 175, 255, 255),
    };
    const accent_title_color = switch (self.reward_kind) {
        .boss => ui.color(255, 230, 120, 255),
        .mini_boss => ui.color(230, 170, 255, 255),
        .boon_category => ui.color(200, 235, 255, 255),
    };

    ui.new(.{
        .id = .IDI("door-reward-badge-", badge_id),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{ .x = screen_position.x, .y = screen_position.y },
            .attach_points = .{
                .element = .center_bottom,
                .parent = .left_top,
            },
        },
        .background_color = ui.color(18, 22, 30, 240),
        .corner_radius = .all(6),
        .border = .{
            .color = border_color,
            .width = .outside(1),
        },
        .layout = .{
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .child_gap = 6,
            .padding = .axes(4, 8),
        },
    })({
        ui.new(.{
            .id = .IDI("door-badge-icon-", badge_id),
            .image = ui.image(self.reward_icon, .init(20, 20)) catch .{ .image_data = null },
            .layout = .{
                .sizing = .{ .w = .fixed(20), .h = .fixed(20) },
            },
        })({});

        ui.text(self.reward_title, .{
            .color = accent_title_color,
            .font_size = 13,
            .letter_spacing = 1,
        });
    });
}

pub fn setOpenState(self: *Self, open: bool) void {
    self.is_open = open;
    if (self.interactable) |interactable| {
        interactable.enabled = open;
    }
    self.applyVisualState();
}

fn applyVisualState(self: *Self) void {
    const renderer = self.renderer orelse return;
    if (!self.is_open) {
        renderer.tint = rl.Color{ .r = 70, .g = 75, .b = 90, .a = 220 };
        return;
    }

    renderer.tint = switch (self.reward_kind) {
        .boss => rl.Color{ .r = 255, .g = 215, .b = 60, .a = 255 },
        .mini_boss => rl.Color{ .r = 200, .g = 120, .b = 255, .a = 255 },
        .boon_category => rl.Color{ .r = 120, .g = 210, .b = 255, .a = 255 },
    };
}

pub fn onDoorInteract(interactable: *Interactable, player: *lm.Entity) void {
    _ = player;
    const entity = interactable.entity orelse return;
    const door = entity.getComponent(Self) orelse return;

    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.9, 0.05);

    if (door.category_id) |category| {
        RoomManager.enterNextRoomWithCategory(category) catch |err| {
            std.log.err("Failed to enter next room with category {s}: {any}", .{ category, err });
        };
    } else {
        RoomManager.enterNextRoom() catch |err| {
            std.log.err("Failed to enter next room: {any}", .{err});
        };
    }
}
