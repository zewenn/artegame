const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const Objectives = @import("../../components/player/Objectives.zig");
const HUD = @import("../HUD.zig");

pub fn draw(tracking: Objectives.Objective) void {
    ui.new(.{
        .id = .ID("objective-container"),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{ .x = 0, .y = HUD.window_size.y * 0.3 },
            .attach_points = .{
                .element = .right_top,
                .parent = .right_top,
            },
        },
        .background_color = ui.color(50, 50, 50, 128),
        .layout = .{
            .direction = .top_to_bottom,
            .child_gap = 5,
            .padding = .all(10),
        },
    })({
        ui.new(.{
            .id = .ID("name"),
        })({
            ui.text(tracking.name, .{
                .color = ui.color(255, 255, 255, 255),
                .font_size = 32,
                .letter_spacing = 1,
            });
        });
        ui.new(.{
            .id = .ID("desc"),
        })({
            ui.text(tracking.description, .{
                .color = ui.color(255, 255, 255, 255),
                .font_size = 16,
                .letter_spacing = 1,
            });
        });
    });
}
