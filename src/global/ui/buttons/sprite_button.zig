const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;
const clay = lm.deps.clay;

const theme = @import("../theme.zig");
const color_scheme = @import("../color_scheme.zig");

pub const ActionFn = *const fn (index: usize) void;
pub const Variant = theme.ButtonVariant;

/// Optional overrides for customizing sprite button sizing, typography, and disabled styling.
pub const Options = struct {
    letter_spacing: u16 = 1,
    font_size_override: ?u16 = null,
    is_disabled: bool = false,
    idle_text_color_override: ?clay.Color = null,
    width_override_pixels: ?f32 = null,
    id_prefix_override: ?[]const u8 = null,
};

/// Renders a scaled interactive sprite button and updates selection or invokes action on interaction.
pub fn draw(
    comptime variant: Variant,
    index: usize,
    caption: []const u8,
    selected_index: *usize,
    action: ActionFn,
    ui_scale: f32,
    options: Options,
) void {
    const spec = comptime variant.spec();
    const button_id = if (options.id_prefix_override) |prefix|
        clay.ElementId.IDI(prefix, @intCast(index))
    else
        clay.ElementId.IDI(spec.id_prefix, @intCast(index));

    const is_hovered = clay.pointerOver(button_id);
    const is_selected = !options.is_disabled and ((selected_index.* == index) or is_hovered);

    const dimensions_pixels: lm.Vector2 = .init(
        options.width_override_pixels orelse @round(spec.base_width_pixels * ui_scale),
        @round(spec.base_height_pixels * ui_scale),
    );
    const sprite_path = if (is_selected) spec.active_sprite_path else spec.idle_sprite_path;
    const font_size = options.font_size_override orelse theme.scaledU16(
        spec.font_scale,
        spec.minimum_font_size_pixels,
        ui_scale,
    );

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
        handlePointerInteraction(index, is_hovered, options.is_disabled, selected_index, action);
        drawButtonLabel(spec, index, caption, is_selected, ui_scale, font_size, options);
    });
}

fn handlePointerInteraction(
    index: usize,
    is_hovered: bool,
    is_disabled: bool,
    selected_index: *usize,
    action: ActionFn,
) void {
    const is_pointer_over = clay.hovered() or is_hovered;
    if (!is_pointer_over) return;

    selected_index.* = index;
    if (is_disabled) return;
    if (lm.mouse.getButtonDown(.left)) {
        action(index);
    }
}

fn resolveLabelColor(is_selected: bool, options: Options) clay.Color {
    if (options.is_disabled) return color_scheme.button_text_disabled;
    if (is_selected) return color_scheme.button_text_selected;
    return options.idle_text_color_override orelse color_scheme.button_text_idle;
}

fn drawButtonLabel(
    comptime spec: theme.ButtonSpec,
    index: usize,
    caption: []const u8,
    is_selected: bool,
    ui_scale: f32,
    font_size: u16,
    options: Options,
) void {
    const top_padding_pixels: u16 = if (is_selected and spec.active_top_padding_scale > 0.0)
        lm.tou16(@round(spec.active_top_padding_scale * ui_scale))
    else
        0;
    const bottom_padding_pixels: u16 = if (is_selected)
        0
    else
        lm.tou16(@round(spec.idle_bottom_padding_scale * ui_scale));

    ui.new(.{
        .id = .IDI(spec.text_container_id_prefix, @intCast(index)),
        .layout = .{
            .sizing = .{ .w = .percent(1), .h = .percent(1) },
            .padding = .{
                .top = top_padding_pixels,
                .bottom = bottom_padding_pixels,
            },
            .child_alignment = .center,
        },
    })({
        ui.text(caption, .{
            .color = resolveLabelColor(is_selected, options),
            .font_size = font_size,
            .letter_spacing = options.letter_spacing,
            .alignment = .center,
            .font_id = theme.getFontId(is_selected),
        });
    });
}

test "sprite_button resolveLabelColor respects disabled and idle overrides" {
    const disabled_color = resolveLabelColor(true, .{ .is_disabled = true });
    try std.testing.expectEqual(color_scheme.button_text_disabled, disabled_color);

    const override_color = resolveLabelColor(false, .{
        .idle_text_color_override = color_scheme.button_text_primary_idle,
    });
    try std.testing.expectEqual(color_scheme.button_text_primary_idle, override_color);
}
