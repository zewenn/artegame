const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const InputHelper = @import("../input/InputHelper.zig");
pub const PromptAction = InputHelper.PromptAction;
pub const ActionPrompt = InputHelper.ActionPrompt;
pub const UiColor = InputHelper.UiColor;

pub fn drawBadge(id_prefix: []const u8, action: PromptAction, ui_scale: f32) void {
    const prompt = InputHelper.getActionPrompt(action);
    drawCustomBadge(
        id_prefix,
        prompt.label,
        prompt.badge_bg,
        prompt.badge_border,
        prompt.text_color,
        prompt.is_controller_button,
        ui_scale,
    );
}

pub fn drawCustomBadge(
    id_prefix: []const u8,
    label: []const u8,
    bg_color: UiColor,
    border_color: UiColor,
    text_color: UiColor,
    is_controller: bool,
    ui_scale: f32,
) void {
    const corner_rad = if (is_controller) 8 * ui_scale else 4 * ui_scale;
    const pad_y = lm.tou16(@max(1, @round(2 * ui_scale)));
    const pad_x = lm.tou16(@max(3, @round(6 * ui_scale)));
    const font_sz = lm.tou16(@max(9, @round(11 * ui_scale)));

    ui.new(.{
        .id = .IDI(id_prefix, 0),
        .background_color = bg_color,
        .corner_radius = .all(corner_rad),
        .border = .{
            .color = border_color,
            .width = .outside(1),
        },
        .layout = .{
            .padding = .axes(pad_y, pad_x),
            .child_alignment = .{ .x = .center, .y = .center },
        },
    })({
        ui.text(label, .{
            .color = text_color,
            .font_size = font_sz,
            .letter_spacing = 1,
            .alignment = .center,
        });
    });
}

pub fn drawInlinePrompt(
    id_prefix: []const u8,
    index: usize,
    action: PromptAction,
    desc: []const u8,
    ui_scale: f32,
) void {
    const prompt = InputHelper.getActionPrompt(action);
    const corner_rad = if (prompt.is_controller_button) 8 * ui_scale else 4 * ui_scale;
    const pad_y = lm.tou16(@max(1, @round(2 * ui_scale)));
    const pad_x = lm.tou16(@max(3, @round(5 * ui_scale)));
    const badge_font_sz = lm.tou16(@max(9, @round(11 * ui_scale)));
    const text_font_sz = lm.tou16(@max(10, @round(12 * ui_scale)));
    const gap = lm.tou16(@max(2, @round(4 * ui_scale)));

    ui.new(.{
        .id = .IDI(id_prefix, @intCast(index)),
        .layout = .{
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .child_gap = gap,
        },
    })({
        ui.new(.{
            .id = .IDI("badge-inner-", @intCast(index)),
            .background_color = prompt.badge_bg,
            .corner_radius = .all(corner_rad),
            .border = .{
                .color = prompt.badge_border,
                .width = .outside(1),
            },
            .layout = .{
                .padding = .axes(pad_y, pad_x),
                .child_alignment = .{ .x = .center, .y = .center },
            },
        })({
            ui.text(prompt.label, .{
                .color = prompt.text_color,
                .font_size = badge_font_sz,
                .letter_spacing = 1,
            });
        });

        ui.text(desc, .{
            .color = ui.color(180, 190, 205, 230),
            .font_size = text_font_sz,
            .letter_spacing = 1,
        });
    });
}
