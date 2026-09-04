const std = @import("std");
const lm = @import("loom");

const Stats = @import("../components/Stats.zig");
const Objectives = @import("../components/player/Objectives.zig");
const Attack = @import("../components/player/Attack.zig");
const Boon = @import("boons/Boon.zig");
const Interactable = @import("../components/interaction/Interactable.zig");

pub const ui = @import("ui/ui.zig");
pub const PlayerStats = ui.PlayerStats;
pub const ObjectiveUI = ui.ObjectiveUI;
pub const BoonMenu = ui.BoonMenu;
pub const InteractionPrompt = ui.InteractionPrompt;

const Self = @This();

// Public global scaling and sizing variables calculated once per frame in Update
pub var window_size: lm.Vector2 = .init(1280, 720);
pub var scale: f32 = 1.0;
pub var hud_height: f32 = 64.0;
pub var hud_width: f32 = 512.0;
pub var ui_scale: f32 = 1.0;

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

    // Calculate sizing and scaling metrics once per frame
    window_size = lm.window.size.get();
    scale = @max(1.0, @round(@min(window_size.x, window_size.y) / 540.0));
    hud_height = scale * 32.0;
    hud_width = hud_height * 8.0;

    const scale_x = window_size.x / 1280.0;
    const scale_y = window_size.y / 720.0;
    ui_scale = @max(0.65, @min(2.5, @min(scale_x, scale_y)));

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

    // Draw interaction prompt for focused interactable
    if (!BoonMenu.isShowing()) {
        if (Interactable.getFocused()) |focused| {
            const camera = scene.getCameraById("main");
            InteractionPrompt.draw(camera, focused);
        }
    }

    // Draw boon menu if showing
    if (BoonMenu.boons) |boon_array| {
        BoonMenu.draw(boon_array, self.player_stats, self.player_attack, self.alloc);
    }
}

pub fn End(self: *Self) void {
    if (self.arena) |*arena| arena.deinit();
    self.arena = null;
    self.alloc = null;
    BoonMenu.hide();
}

pub fn showBoons(boons: []const Boon) void {
    BoonMenu.show(boons);
}
