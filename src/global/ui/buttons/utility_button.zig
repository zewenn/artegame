const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;
const clay = lm.deps.clay;

const HUD = @import("../../HUD.zig");

pub const ActionFn = *const fn (index: usize) void;

/// Renders a scaled interactive utility button and updates selection or invokes action on interaction.
pub fn draw(
    index: usize,
    caption: []const u8,
    selected_index: *usize,
    action: ActionFn,
    _: u16,
    letter_spacing: u16,
) void {
    const button_id = clay.ElementId.IDI("utility-btn-", @intCast(index));

    const is_hovered = clay.pointerOver(button_id);
    const is_selected = (selected_index.* == index) or is_hovered;

    const window_size = lm.window.size.get();
    const ui_scale = HUD.calculateUiScale(window_size);
    const dimensions_pixels: lm.Vector2 = .init(
        @round(HUD.UTILITY_BUTTON_BASE_W * ui_scale),
        @round(HUD.UTILITY_BUTTON_BASE_H * ui_scale),
    );

    const sprite_path = HUD.getUtilityButtonSprite(is_selected);
    const font_size = lm.tou16(@max(13, @round(13 * ui_scale)));

    clay.UI()(.{
        .id = button_id,
        .layout = .{
            .sizing = .{
                .w = .fixed(dimensions_pixels.x),
                .h = .fixed(dimensions_pixels.y),
            },
            .child_alignment = .{ .x = .center, .y = .center },
        },
        .image = ui.image(sprite_path, dimensions_pixels) catch .{ .image_data = null },
    })({
        handlePointerInteraction(index, is_hovered, selected_index, action);
        drawButtonLabel(index, caption, is_selected, ui_scale, font_size, letter_spacing);
    });
}

fn handlePointerInteraction(
    index: usize,
    is_hovered: bool,
    selected_index: *usize,
    action: ActionFn,
) void {
    const is_pointer_over = clay.hovered() or is_hovered;
    if (!is_pointer_over) return;

    selected_index.* = index;
    if (lm.mouse.getButtonDown(.left)) {
        action(index);
    }
}

fn drawButtonLabel(
    index: usize,
    caption: []const u8,
    is_selected: bool,
    ui_scale: f32,
    font_size: u16,
    letter_spacing: u16,
) void {
    const bottom_padding_pixels: u16 = if (is_selected) 0 else 4 * lm.tou16(ui_scale);
    const top_padding_pixels: u16 = if (!is_selected) 0 else 2 * lm.tou16(ui_scale);
    const text_color = if (is_selected) ui.color(255, 255, 255, 255) else ui.color(238, 230, 234, 255);
    const font_id = if (is_selected) ui.fontID("ui/fonts/Silkscreen-Bold.ttf") else ui.fontID("ui/fonts/Silkscreen-Regular.ttf");

    ui.new(.{
        .id = .IDI("utility-btn-text-container-", @intCast(index)),
        .layout = .{
            .sizing = .{ .w = .percent(1), .h = .percent(1) },
            .padding = .{
                .bottom = bottom_padding_pixels,
                .top = top_padding_pixels,
            },
            .child_alignment = .center,
        },
    })({
        ui.text(caption, .{
            .color = text_color,
            .font_size = font_size,
            .letter_spacing = letter_spacing,
            .alignment = .center,
            .font_id = font_id,
        });
    });
}
