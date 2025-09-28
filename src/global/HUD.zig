const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const Stats = @import("../components/Stats.zig");
const Self = @This();

player: ?*lm.Entity = null,
player_stats: ?*Stats = null,

pub fn Update(self: *Self, scene: *lm.Scene) !void {
    const stats: *Stats = self.player_stats orelse get: {
        self.player = scene.getEntityById("player");
        if (self.player == null) return;

        self.player_stats = try self.player.?.pullComponent(Stats);

        break :get self.player_stats.?;
    };

    const window_size = lm.window.size.get();
    const scaler = @min(window_size.x, window_size.y);
    const BASE_HUD_WIDTH: comptime_float = 0.35;

    ui.new(.{
        .id = .ID("player-hud"),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{ .x = window_size.x / 2 - scaler * (BASE_HUD_WIDTH / 2.0), .y = window_size.y - scaler * 0.07 },
        },
        .background_color = ui.color(50, 50, 50, 255),
        .layout = .{
            .sizing = .{ .h = .fixed(scaler * 0.06), .w = .fixed(scaler * BASE_HUD_WIDTH) },
            .direction = .top_to_bottom,
            .padding = .all(5),
            .child_gap = 5,
        },
    })({
        ui.new(.{
            .id = .ID("player-healthbar-outer"),
            .background_color = ui.color(20, 20, 20, 255),
            .layout = .{
                .sizing = .{ .h = .percent(0.45), .w = .percent(1) },
            },
        })({
            ui.new(.{
                .id = .ID("player-healthbar-inner"),
                .background_color = ui.color(220, 20, 120, 255),
                .layout = .{
                    .sizing = .{ .h = .percent(1), .w = .percent(stats.current.health / stats.max.health) },
                },
            })({});
        });
        ui.new(.{
            .id = .ID("player-manabar-outer"),
            .background_color = ui.color(20, 20, 20, 255),
            .layout = .{
                .sizing = .{ .h = .percent(0.35), .w = .percent(1) },
            },
        })({
            ui.new(.{
                .id = .ID("player-manabar-inner"),
                .background_color = ui.color(20, 120, 220, 255),
                .layout = .{
                    .sizing = .{ .h = .percent(1), .w = .percent(stats.current.mana / stats.max.mana) },
                },
            })({});
        });
        ui.new(.{
            .id = .ID("player-staminabar-outer"),
            .background_color = ui.color(20, 20, 20, 255),
            .layout = .{
                .sizing = .{ .h = .percent(0.20), .w = .percent(1) },
            },
        })({
            ui.new(.{
                .id = .ID("player-staminabar-inner"),
                .background_color = ui.color(255, 255, 255, 255),
                .layout = .{
                    .sizing = .{ .h = .percent(1), .w = .percent(stats.current.stamina / stats.max.stamina) },
                },
            })({});
        });
    });
}
