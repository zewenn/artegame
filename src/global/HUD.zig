const std = @import("std");
const lm = @import("loom");

const Stats = @import("../components/Stats.zig");
const Objectives = @import("../components/player/Objectives.zig");
const Attack = @import("../components/player/Attack.zig");
const Interactable = @import("../components/interaction/Interactable.zig");
const RoomManager = @import("RoomManager.zig");
const RoomType = @import("RoomType.zig").RoomType;
const RoundSpawner = @import("spawner/RoundSpawner.zig");
const MusicManager = @import("audio/MusicManager.zig");

const ui = @import("ui/ui.zig");
const theme = @import("ui/theme.zig");
const color_scheme = ui.color_scheme;
const PlayerStats = ui.PlayerStats;
const ObjectiveUI = ui.ObjectiveUI;
const InteractionPrompt = ui.InteractionPrompt;

pub const BoonMenu = ui.BoonMenu;
pub const PauseMenu = ui.PauseMenu;
pub const GameOverMenu = ui.GameOverMenu;

const Self = @This();

pub var window_size: lm.Vector2 = .init(1280, 720);
pub var hud_height: f32 = 64.0;
pub var hud_width: f32 = 512.0;
pub var ui_scale: f32 = 4.0;

player_stats: ?*Stats = null,
player_objectives: ?*Objectives = null,
player_attack: ?*Attack = null,

arena: ?std.heap.ArenaAllocator = null,
allocator: ?std.mem.Allocator = null,

pub fn Awake(self: *Self) void {
    self.arena = std.heap.ArenaAllocator.init(lm.allocators.scene());
    self.allocator = self.arena.?.allocator();
    GameOverMenu.reset();
}

pub fn Update(self: *Self, scene: *lm.Scene) !void {
    if (self.arena) |*arena| _ = arena.reset(.retain_capacity);
    if (!self.ensurePlayerComponents(scene)) return;

    self.checkPlayerDeath();
    if (GameOverMenu.isShowing()) {
        GameOverMenu.draw(self.allocator);
        return;
    }

    window_size = lm.window.size.get();
    ui_scale = theme.calculateUiScale(window_size);
    hud_height = ui_scale * 16.0;
    hud_width = hud_height * 8.0;

    self.drawHudOverlays();
    self.handlePauseAndInteract(scene);
    self.drawActiveMenus();
}

pub fn End(self: *Self) void {
    if (self.arena) |*arena| arena.deinit();
    self.arena = null;
    self.allocator = null;
    BoonMenu.hide();
    PauseMenu.hide();
    GameOverMenu.hide();
}

pub fn showBoons(slots: []const BoonMenu.BoonSlot) void {
    BoonMenu.show(slots);
}

/// Returns true when any full-screen modal menu overlay is currently open.
pub fn isModalOpen() bool {
    return GameOverMenu.isShowing() or PauseMenu.isShowing() or BoonMenu.isShowing();
}

fn ensurePlayerComponents(self: *Self, scene: *lm.Scene) bool {
    const has_all_components = self.player_stats != null and
        self.player_objectives != null and
        self.player_attack != null;
    if (has_all_components) return true;

    const player = scene.getEntityById("player") orelse return false;
    self.player_stats = player.getComponent(Stats);
    self.player_objectives = player.getComponent(Objectives);
    self.player_attack = player.getComponent(Attack);
    return true;
}

fn checkPlayerDeath(self: *Self) void {
    const stats = self.player_stats orelse return;
    if (stats.current.health > 0.0 or GameOverMenu.isShowing()) return;

    BoonMenu.hide();
    PauseMenu.hide();
    GameOverMenu.show(RoomManager.getRunStats());
    MusicManager.setGlobalPhase(.replenish);
}

fn drawHudOverlays(self: *Self) void {
    if (RoomManager.getWaveProgress()) |progress| {
        if (progress.round > 0) drawRoundIndicator(progress);
    }

    if (self.player_attack) |attack| {
        if (self.player_stats) |stats| {
            PlayerStats.draw(stats, attack, ui_scale, self.allocator);
        }
    }

    const objectives = self.player_objectives orelse return;
    const tracking = objectives.trackingObjective() orelse return;
    ObjectiveUI.draw(tracking, ui_scale, window_size);
}

fn handlePauseAndInteract(self: *Self, scene: *lm.Scene) void {
    _ = self;
    if (BoonMenu.isShowing() or PauseMenu.isShowing()) return;

    const gamepad_pause_pressed = lm.gamepad.isAvailable(0) and
        (lm.gamepad.getButtonDown(0, .middle_right) or lm.gamepad.getButtonDown(0, .middle));
    const pause_pressed = lm.keyboard.getKeyDown(.escape) or gamepad_pause_pressed;
    if (pause_pressed) {
        PauseMenu.show();
        return;
    }

    const focused = Interactable.getFocused() orelse return;
    const camera = scene.getCameraById("main");
    InteractionPrompt.draw(camera, focused, ui_scale);
}

fn drawActiveMenus(self: *Self) void {
    if (PauseMenu.isShowing()) {
        PauseMenu.draw(self.allocator);
        return;
    }
    const slot_array = BoonMenu.slots orelse return;
    BoonMenu.draw(slot_array, self.player_stats, self.player_attack);
}

fn drawRoundIndicator(progress: RoundSpawner.WaveProgress) void {
    const room_type = if (RoomManager.get()) |room_manager| room_manager.getRoomType() else RoomType.fromRoomNumber(progress.round);
    const room_label = room_type.hudLabel();

    const font_size = theme.scaledU16(2.5, 5, ui_scale);
    const padding_y_pixels = lm.tou16(@round(1.5 * ui_scale));
    const padding_x_pixels = lm.tou16(@round(4.0 * ui_scale));

    lm.ui.new(.{
        .id = .ID("hud-round-indicator"),
        .floating = .{
            .attach_to = .to_root,
            .attach_points = .{
                .element = .center_top,
                .parent = .center_top,
            },
            .offset = .{ .x = 0, .y = 4.0 * ui_scale },
        },
        .background_color = color_scheme.hud_overlay_background,
        .corner_radius = .all(1.0 * ui_scale),
        .layout = .{
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = lm.tou16(@round(0.5 * ui_scale)),
            .padding = .axes(padding_y_pixels, padding_x_pixels),
        },
    })({
        lm.ui.textFmt("Room {d}{s}  -  {d} / {d}", .{ progress.round, room_label, progress.killed, progress.total }, .{
            .color = color_scheme.text_highlight_gold,
            .font_size = font_size,
            .letter_spacing = 1,
            .font_id = theme.regularFontId(),
        });
    });
}

test "HUD.isModalOpen reflects active modal overlays" {
    defer {
        GameOverMenu.hide();
        PauseMenu.hide();
        BoonMenu.hide();
        lm.time.proceed();
    }
    GameOverMenu.hide();
    PauseMenu.hide();
    BoonMenu.hide();
    try std.testing.expect(!isModalOpen());

    PauseMenu.show();
    try std.testing.expect(isModalOpen());
    PauseMenu.hide();
    try std.testing.expect(!isModalOpen());

    GameOverMenu.show(.{});
    try std.testing.expect(isModalOpen());
    GameOverMenu.hide();
    try std.testing.expect(!isModalOpen());

    const empty_slots = [_]BoonMenu.BoonSlot{};
    BoonMenu.show(&empty_slots);
    try std.testing.expect(isModalOpen());
    BoonMenu.hide();
    try std.testing.expect(!isModalOpen());
}
