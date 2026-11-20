const lm = @import("loom");
const ui = lm.ui;

const Objectives = @import("../../components/player/Objectives.zig");
const theme = @import("theme.zig");
const color_scheme = @import("color_scheme.zig");

/// Renders the active objective tracker card in the top-right corner of the screen.
pub fn draw(tracking: Objectives.Objective, ui_scale: f32, window_size: lm.Vector2) void {
    ui.new(.{
        .id = .ID("objective-container"),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{ .x = -4.0 * ui_scale, .y = window_size.y * 0.075 },
            .attach_points = .{
                .element = .right_top,
                .parent = .right_top,
            },
        },
        .corner_radius = .all(lm.tou16(@round(1.0 * ui_scale))),
        .background_color = color_scheme.hud_translucent_background,
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
                .color = color_scheme.text_bright,
                .font_size = theme.scaledU16(8.0, 12, ui_scale),
                .letter_spacing = 1,
                .font_id = theme.boldFontId(),
            });
        });
        ui.new(.{
            .id = .ID("desc"),
        })({
            ui.text(tracking.description, .{
                .color = color_scheme.text_bright,
                .font_size = theme.scaledU16(4.0, 8, ui_scale),
                .letter_spacing = 1,
                .font_id = theme.regularFontId(),
            });
        });
    });
}
