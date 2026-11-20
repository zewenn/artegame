const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const Interactable = @import("../interaction/Interactable.zig");
const RoomManager = @import("../../global/RoomManager.zig");
const AudioManager = @import("../../global/audio/AudioManager.zig");
const HUD = @import("../../global/HUD.zig");
const theme = @import("../../global/ui/theme.zig");

const Self = @This();

pub const RewardKind = enum {
    boon_category,
    mini_boss,
    boss,
};

const DoorSprites = struct {
    open: []const u8,
    closed: []const u8,
};

const DOOR_SPRITE_ROOT = "items/exit_doors/";

const door_sprites = std.EnumArray(RewardKind, DoorSprites).init(.{
    .boon_category = .{
        .open = DOOR_SPRITE_ROOT ++ "normal_open.png",
        .closed = DOOR_SPRITE_ROOT ++ "normal_closed.png",
    },
    .mini_boss = .{
        .open = DOOR_SPRITE_ROOT ++ "miniboss_open.png",
        .closed = DOOR_SPRITE_ROOT ++ "miniboss_closed.png",
    },
    .boss = .{
        .open = DOOR_SPRITE_ROOT ++ "boss_open.png",
        .closed = DOOR_SPRITE_ROOT ++ "boss_closed.png",
    },
});

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

pub fn Awake(self: *Self, entity: *lm.Entity) !void {
    self.transform = try entity.pullComponent(lm.Transform);
    self.renderer = entity.getComponent(lm.Renderer);
    self.interactable = entity.getComponent(Interactable);

    if (self.interactable) |interactable| {
        interactable.enabled = self.is_open;
    }

    self.applyVisualState();
}

pub fn Start(self: *Self) void {
    const scene = lm.activeScene() orelse return;
    self.camera = scene.getCameraById("main");
}

pub fn Update(self: *Self) void {
    const is_tutorial = if (RoomManager.get()) |room_manager| room_manager.getRoomType() == .tutorial else false;
    if (!self.is_open or (!RoomManager.isReplenish() and !is_tutorial)) return;
    if (HUD.isModalOpen() or lm.time.paused()) return;

    const transform = self.transform orelse return;
    const camera = self.camera orelse {
        const scene = lm.activeScene() orelse return;
        self.camera = scene.getCameraById("main");
        return;
    };

    const door_position = lm.vec3ToVec2(transform.position);
    const overhead_world_position = door_position.add(.init(0, -68.0));
    const screen_position = camera.worldToScreenPos(overhead_world_position);
    self.drawRewardBadge(screen_position);
}

fn drawRewardBadge(self: *const Self, screen_position: lm.Vector2) void {
    const ui_scale = HUD.ui_scale;
    const icon_size_pixels = @round(5.0 * ui_scale);
    const badge_id = @as(u32, @intCast(self.door_index));
    const accent_title_color = ui.color(238, 230, 234, 255);

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
        .corner_radius = .all(lm.tou16(@round(1.0 * ui_scale))),
        .background_color = ui.color(23, 21, 22, 196),
        .layout = .{
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .child_gap = lm.tou16(@round(1.5 * ui_scale)),
            .padding = .axes(
                lm.tou16(@round(1.0 * ui_scale)),
                lm.tou16(@round(2.0 * ui_scale)),
            ),
        },
    })({
        ui.new(.{
            .id = .IDI("door-badge-icon-", badge_id),
            .image = ui.image(self.reward_icon, .init(icon_size_pixels, icon_size_pixels)) catch .{ .image_data = null },
            .layout = .{
                .sizing = .{ .w = .fixed(icon_size_pixels), .h = .fixed(icon_size_pixels) },
            },
        })({});

        ui.text(self.reward_title, .{
            .color = accent_title_color,
            .font_size = lm.tou16(@max(6, @round(3.25 * ui_scale))),
            .letter_spacing = 1,
            .font_id = theme.boldFontId(),
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
    const sprites = door_sprites.get(self.reward_kind);
    renderer.img_path = if (self.is_open) sprites.open else sprites.closed;
}

pub fn onDoorInteract(interactable: *Interactable, player: *lm.Entity) void {
    _ = player;
    const entity = interactable.entity orelse return;
    const door = entity.getComponent(Self) orelse return;

    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.9, 0.05);

    if (RoomManager.isPlaytestMode() or RoomManager.isPracticeTutorialMode()) {
        RoomManager.enterNextRoom() catch |transition_error| {
            std.log.err("Failed to exit standalone room: {any}", .{transition_error});
        };
        return;
    }

    if (door.category_id) |category| {
        RoomManager.enterNextRoomWithCategory(category) catch |transition_error| {
            std.log.err("Failed to enter next room with category {s}: {any}", .{ category, transition_error });
        };
        return;
    }

    RoomManager.enterNextRoom() catch |transition_error| {
        std.log.err("Failed to enter next room: {any}", .{transition_error});
    };
}
