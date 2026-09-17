const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const DevicePrompts = @import("../input/DevicePrompts.zig");
pub const PromptAction = DevicePrompts.PromptAction;
pub const ActionPrompt = DevicePrompts.ActionPrompt;
pub const UiColor = DevicePrompts.UiColor;

pub fn drawBadge(id_prefix: []const u8, action: PromptAction, ui_scale: f32) void {
    const prompt = DevicePrompts.getActionPrompt(action);
    drawCustomBadge(
        id_prefix,
        prompt.label,
        prompt.badge_background_color,
        prompt.badge_border_color,
        prompt.text_color,
        prompt.is_controller_button,
        ui_scale,
    );
}

pub fn drawCustomBadge(
    id_prefix: []const u8,
    label: []const u8,
    background_color: UiColor,
    border_color: UiColor,
    text_color: UiColor,
    is_controller: bool,
    ui_scale: f32,
) void {
    const corner_radius = if (is_controller) 8 * ui_scale else 4 * ui_scale;
    const padding_y = lm.tou16(@max(1, @round(2 * ui_scale)));
    const padding_x = lm.tou16(@max(3, @round(6 * ui_scale)));
    const font_size = lm.tou16(@max(9, @round(11 * ui_scale)));

    ui.new(.{
        .id = .IDI(id_prefix, 0),
        .background_color = background_color,
        .corner_radius = .all(corner_radius),
        .border = .{
            .color = border_color,
            .width = .outside(1),
        },
        .layout = .{
            .padding = .axes(padding_y, padding_x),
            .child_alignment = .{ .x = .center, .y = .center },
        },
    })({
        ui.text(label, .{
            .color = text_color,
            .font_size = font_size,
            .letter_spacing = 1,
            .alignment = .center,
        });
    });
}

pub fn drawInlinePrompt(
    id_prefix: []const u8,
    index: usize,
    action: PromptAction,
    description: []const u8,
    ui_scale: f32,
) void {
    const prompt = DevicePrompts.getActionPrompt(action);
    const corner_radius = if (prompt.is_controller_button) 8 * ui_scale else 4 * ui_scale;
    const padding_y = lm.tou16(@max(1, @round(2 * ui_scale)));
    const padding_x = lm.tou16(@max(3, @round(5 * ui_scale)));
    const badge_font_size = lm.tou16(@max(9, @round(11 * ui_scale)));
    const text_font_size = lm.tou16(@max(10, @round(12 * ui_scale)));
    const gap_pixels = lm.tou16(@max(2, @round(4 * ui_scale)));

    ui.new(.{
        .id = .IDI(id_prefix, @intCast(index)),
        .layout = .{
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .child_gap = gap_pixels,
        },
    })({
        ui.new(.{
            .id = .IDI("badge-inner-", @intCast(index)),
            .background_color = prompt.badge_background_color,
            .corner_radius = .all(corner_radius),
            .border = .{
                .color = prompt.badge_border_color,
                .width = .outside(1),
            },
            .layout = .{
                .padding = .axes(padding_y, padding_x),
                .child_alignment = .{ .x = .center, .y = .center },
            },
        })({
            ui.text(prompt.label, .{
                .color = prompt.text_color,
                .font_size = badge_font_size,
                .letter_spacing = 1,
            });
        });

        ui.text(description, .{
            .color = ui.color(180, 190, 205, 230),
            .font_size = text_font_size,
            .letter_spacing = 1,
        });
    });
}
