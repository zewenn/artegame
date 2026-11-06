const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const Objectives = @import("../../components/player/Objectives.zig");
const HUD = @import("../HUD.zig");

pub fn draw(tracking: Objectives.Objective, ui_scale: f32) void {
    ui.new(.{
        .id = .ID("objective-container"),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{ .x = -4.0 * ui_scale, .y = HUD.window_size.y * 0.075 },
            .attach_points = .{
                .element = .right_top,
                .parent = .right_top,
            },
        },
        .corner_radius = .all(lm.tou16(@round(1.0 * ui_scale))),
        .background_color = ui.color(23, 21, 22, 196),
        .layout = .{
            .direction = .top_to_bottom,
            .child_gap = lm.tou16(@round(1.25 * ui_scale)),
            .padding = .all(lm.tou16(@round(2.5 * ui_scale))),
        },
    })({
        ui.new(.{
            .id = .ID("name"),
        })({
            ui.text(tracking.name, .{
                .color = ui.color(255, 255, 255, 255),
                .font_size = lm.tou16(@max(12, @round(8.0 * ui_scale))),
                .letter_spacing = 1,
                .font_id = HUD.boldFontId(),
            });
        });
        ui.new(.{
            .id = .ID("desc"),
        })({
            ui.text(tracking.description, .{
                .color = ui.color(255, 255, 255, 255),
                .font_size = lm.tou16(@max(8, @round(4.0 * ui_scale))),
                .letter_spacing = 1,
                .font_id = HUD.regularFontId(),
            });
        });
    });
}
