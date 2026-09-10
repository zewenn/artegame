const std = @import("std");
const lm = @import("loom");

const Stats = @import("../components/Stats.zig");
const Objectives = @import("../components/player/Objectives.zig");
const Attack = @import("../components/player/Attack.zig");
const Boon = @import("boons/Boon.zig");
const Interactable = @import("../components/interaction/Interactable.zig");
const DemoMap = @import("DemoMap.zig");
const RoundSpawner = @import("spawner/RoundSpawner.zig");
const MusicManager = @import("audio/MusicManager.zig");
const InputHelper = @import("input/InputHelper.zig");

pub const ui = @import("ui/ui.zig");
pub const PlayerStats = ui.PlayerStats;
pub const ObjectiveUI = ui.ObjectiveUI;
pub const BoonMenu = ui.BoonMenu;
pub const InteractionPrompt = ui.InteractionPrompt;
pub const PauseMenu = ui.PauseMenu;
pub const GameOverMenu = ui.GameOverMenu;

const Self = @This();

pub var window_size: lm.Vector2 = .init(1280, 720);
pub var scale: f32 = 1.0;
pub var hud_height: f32 = 64.0;
pub var hud_width: f32 = 512.0;
pub var ui_scale: f32 = 1.0;

pub const MENU_BUTTON_BASE_H: f32 = 48.0;
pub const MENU_BUTTON_BASE_W: f32 = MENU_BUTTON_BASE_H * 6.0;
pub const UTILITY_BUTTON_BASE_H: f32 = 24.0;
pub const UTILITY_BUTTON_BASE_W: f32 = UTILITY_BUTTON_BASE_H * 4.0;

pub const MENU_BUTTON_SPRITE: []const u8 = "ui/HUD/buttons/large_button1.png";
pub const MENU_BUTTON_HOVER_SPRITE: []const u8 = "ui/HUD/buttons/large_button2.png";
pub const UTILITY_BUTTON_SPRITE: []const u8 = "ui/HUD/buttons/small_button1.png";
pub const UTILITY_BUTTON_HOVER_SPRITE: []const u8 = "ui/HUD/buttons/small_button2.png";

pub fn getMenuButtonSprite(is_active: bool) []const u8 {
    return if (is_active) MENU_BUTTON_HOVER_SPRITE else MENU_BUTTON_SPRITE;
}

pub fn getUtilityButtonSprite(is_active: bool) []const u8 {
    return if (is_active) UTILITY_BUTTON_HOVER_SPRITE else UTILITY_BUTTON_SPRITE;
}

/// Calculates crisp integer scaling factor relative to 1280x720 base resolution.
/// Ensures pixel art UI sprites scale cleanly by integer multipliers (1x, 2x, 3x, etc.).
pub fn calculateUiScale(win_size: lm.Vector2) f32 {
    const scale_x = win_size.x / 1280.0;
    const scale_y = win_size.y / 720.0;
    return @max(1.0, @floor(@min(scale_x, scale_y)));
}

player: ?*lm.Entity = null,
player_stats: ?*Stats = null,
player_objectives: ?*Objectives = null,
player_attack: ?*Attack = null,

arena: ?std.heap.ArenaAllocator = null,
alloc: ?std.mem.Allocator = null,

pub fn Awake(self: *Self) void {
    self.player = null;
    self.player_stats = null;
    self.player_objectives = null;
    self.player_attack = null;

    self.arena = .init(lm.allocators.generic());
    self.alloc = self.arena.?.allocator();
}

pub fn Update(self: *Self, scene: *lm.Scene) !void {
    InputHelper.update();
    if (self.arena) |*arena| _ = arena.reset(.free_all);

    if (self.player == null or self.player_stats == null or self.player_objectives == null) {
        const player = scene.getEntityById("player") orelse {
            self.player = null;
            self.player_stats = null;
            self.player_objectives = null;
            self.player_attack = null;
            return;
        };

        self.player = player;
        self.player_stats = player.getComponentUnsafe(Stats).result;
        self.player_objectives = player.getComponent(Objectives);
        self.player_attack = player.getComponent(Attack);
    }

    // Defeat detection: trigger Game Over when player health <= 0
    if (self.player_stats) |stats| {
        if (stats.current.health <= 0 and !GameOverMenu.isShowing()) {
            BoonMenu.hide();
            PauseMenu.hide();
            GameOverMenu.show(DemoMap.getRunStats());
            MusicManager.setGlobalPhase(.replenish);
        }
    }

    // Suppress all in-game HUD rendering when Game Over is active
    if (GameOverMenu.isShowing()) {
        GameOverMenu.draw(self.alloc);
        return;
    }

    window_size = lm.window.size.get();
    scale = @max(1.0, @round(@min(window_size.x, window_size.y) / 540.0));
    hud_height = scale * 32.0;
    hud_width = hud_height * 8.0;

    ui_scale = calculateUiScale(window_size);

    round_indicator: {
        const progress = DemoMap.getWaveProgress() orelse break :round_indicator;
        if (progress.round == 0) break :round_indicator;

        drawRoundIndicator(progress, self.alloc);
    }

    player_stats: {
        const attack = self.player_attack orelse break :player_stats;
        const stats = self.player_stats orelse break :player_stats;

        PlayerStats.draw(stats, attack, self.alloc);
    }

    objectives: {
        const objectives = self.player_objectives orelse break :objectives;
        const tracking = objectives.trackingObjective() orelse break :objectives;

        ObjectiveUI.draw(tracking);
    }

    if (!BoonMenu.isShowing() and !PauseMenu.isShowing()) menus: {
        const pause_pressed = lm.keyboard.getKeyDown(.escape) or
            (lm.gamepad.isAvailable(0) and (lm.gamepad.getButtonDown(0, .middle_right) or lm.gamepad.getButtonDown(0, .middle)));
        if (pause_pressed) {
            PauseMenu.show();
            break :menus;
        }

        if (!PauseMenu.isShowing()) {
            if (Interactable.getFocused()) |focused| {
                const camera = scene.getCameraById("main");
                InteractionPrompt.draw(camera, focused);
            }
        }
    }

    if (PauseMenu.isShowing()) {
        PauseMenu.draw(self.alloc);
    } else if (BoonMenu.slots) |slot_array| {
        BoonMenu.draw(slot_array, self.player_stats, self.player_attack, self.alloc);
    }
}

pub fn End(self: *Self) void {
    if (self.arena) |*arena| arena.deinit();
    self.arena = null;
    self.alloc = null;
    BoonMenu.hide();
    PauseMenu.hide();
    GameOverMenu.hide();
}

pub fn showBoons(slots: []const BoonMenu.BoonSlot) void {
    BoonMenu.show(slots);
}

fn drawRoundIndicator(progress: RoundSpawner.WaveProgress, alloc: ?std.mem.Allocator) void {
    const round_str = if (alloc) |a|
        std.fmt.allocPrint(a, "{d}. Round", .{progress.round}) catch "Round"
    else
        "Round";

    const count_str = if (alloc) |a|
        std.fmt.allocPrint(a, "{d} / {d}", .{ progress.killed, progress.total }) catch "0 / 0"
    else
        "0 / 0";

    const title_font_size = lm.tou16(@max(20, @round(24 * scale)));
    const count_font_size = lm.tou16(@max(14, @round(16 * scale)));
    const pad_y = lm.tou16(@round(6 * ui_scale));
    const pad_x = lm.tou16(@round(16 * ui_scale));

    lm.ui.new(.{
        .id = .ID("hud-round-indicator"),
        .floating = .{
            .attach_to = .to_root,
            .attach_points = .{
                .element = .center_top,
                .parent = .center_top,
            },
            .offset = .{ .x = 0, .y = 16 * scale },
        },
        .background_color = lm.ui.color(18, 20, 26, 210),
        .corner_radius = .all(8 * ui_scale),
        .border = .{
            .color = lm.ui.color(240, 200, 100, 160),
            .width = .outside(1),
        },
        .layout = .{
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = lm.tou16(@round(2 * ui_scale)),
            .padding = .axes(pad_y, pad_x),
        },
    })({
        lm.ui.new(.{
            .id = .ID("hud-round-title"),
        })({
            lm.ui.text(round_str, .{
                .color = lm.ui.color(255, 235, 170, 255),
                .font_size = title_font_size,
                .letter_spacing = 1,
            });
        });

        lm.ui.new(.{
            .id = .ID("hud-round-count"),
        })({
            lm.ui.text(count_str, .{
                .color = lm.ui.color(210, 225, 245, 255),
                .font_size = count_font_size,
                .letter_spacing = 1,
            });
        });
    });
}

test "HUD.calculateUiScale integer scaling" {
    // 720p base resolution -> 1.0x
    try std.testing.expectEqual(@as(f32, 1.0), calculateUiScale(.{ .x = 1280, .y = 720 }));

    // 1080p (1.5x ratio) -> 1.0x floor
    try std.testing.expectEqual(@as(f32, 1.0), calculateUiScale(.{ .x = 1920, .y = 1080 }));

    // 1440p (2.0x ratio) -> 2.0x
    try std.testing.expectEqual(@as(f32, 2.0), calculateUiScale(.{ .x = 2560, .y = 1440 }));

    // 4K (3.0x ratio) -> 3.0x
    try std.testing.expectEqual(@as(f32, 3.0), calculateUiScale(.{ .x = 3840, .y = 2160 }));

    // Ultrawide 1080p (2560x1080) -> limited by vertical scale (1080/720 = 1.5 -> 1.0x)
    try std.testing.expectEqual(@as(f32, 1.0), calculateUiScale(.{ .x = 2560, .y = 1080 }));

    // Ultrawide 1440p (3440x1440) -> limited by vertical scale (1440/720 = 2.0 -> 2.0x)
    try std.testing.expectEqual(@as(f32, 2.0), calculateUiScale(.{ .x = 3440, .y = 1440 }));

    // Small sub-720p window (e.g. 800x600) -> clamped to 1.0x minimum
    try std.testing.expectEqual(@as(f32, 1.0), calculateUiScale(.{ .x = 800, .y = 600 }));
}

test "UI button base aspect ratios" {
    // Menu item ratio: exactly 6:1 with 48px base height
    try std.testing.expectEqual(@as(f32, 48.0), MENU_BUTTON_BASE_H);
    try std.testing.expectEqual(@as(f32, 6.0), MENU_BUTTON_BASE_W / MENU_BUTTON_BASE_H);

    // Utility button ratio: exactly 4:1 with dynamic base height
    try std.testing.expectEqual(@as(f32, 24.0), UTILITY_BUTTON_BASE_H);
    try std.testing.expectEqual(@as(f32, 4.0), UTILITY_BUTTON_BASE_W / UTILITY_BUTTON_BASE_H);
}

test "UI button sprites idle and hover variants" {
    try std.testing.expectEqualStrings("ui/HUD/buttons/large_button1.png", getMenuButtonSprite(false));
    try std.testing.expectEqualStrings("ui/HUD/buttons/large_button2.png", getMenuButtonSprite(true));
    try std.testing.expectEqualStrings("ui/HUD/buttons/small_button1.png", getUtilityButtonSprite(false));
    try std.testing.expectEqualStrings("ui/HUD/buttons/small_button2.png", getUtilityButtonSprite(true));
}

