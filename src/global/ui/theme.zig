const std = @import("std");
const lm = @import("loom");

pub const BASE_UI_SCALE: f32 = 2.0;

pub const MENU_BUTTON_BASE_HEIGHT: f32 = 12.0;
pub const MENU_BUTTON_BASE_WIDTH: f32 = MENU_BUTTON_BASE_HEIGHT * 6.0;
pub const UTILITY_BUTTON_BASE_HEIGHT: f32 = 6.0;
pub const UTILITY_BUTTON_BASE_WIDTH: f32 = UTILITY_BUTTON_BASE_HEIGHT * 4.0;

pub const MENU_BUTTON_SPRITE: []const u8 = "ui/HUD/buttons/large_button1.png";
pub const MENU_BUTTON_HOVER_SPRITE: []const u8 = "ui/HUD/buttons/large_button2.png";
pub const UTILITY_BUTTON_SPRITE: []const u8 = "ui/HUD/buttons/small_button1.png";
pub const UTILITY_BUTTON_HOVER_SPRITE: []const u8 = "ui/HUD/buttons/small_button2.png";

pub const FONT_REGULAR: []const u8 = "ui/fonts/Silkscreen-Regular.ttf";
pub const FONT_BOLD: []const u8 = "ui/fonts/Silkscreen-Bold.ttf";

/// Comptime layout and styling metadata for a sprite button variant.
pub const ButtonSpec = struct {
    id_prefix: []const u8,
    text_container_id_prefix: []const u8,
    base_width_pixels: f32,
    base_height_pixels: f32,
    idle_sprite_path: []const u8,
    active_sprite_path: []const u8,
    font_scale: f32,
    minimum_font_size_pixels: u16,
    active_top_padding_scale: f32,
    idle_bottom_padding_scale: f32,
};

/// Identifies standard button style variants in the UI theme.
pub const ButtonVariant = enum {
    menu,
    utility,

    /// Returns the comptime specification for this button variant.
    pub fn spec(comptime self: ButtonVariant) ButtonSpec {
        return switch (self) {
            .menu => .{
                .id_prefix = "menu-btn-",
                .text_container_id_prefix = "menu-btn-text-container-",
                .base_width_pixels = MENU_BUTTON_BASE_WIDTH,
                .base_height_pixels = MENU_BUTTON_BASE_HEIGHT,
                .idle_sprite_path = MENU_BUTTON_SPRITE,
                .active_sprite_path = MENU_BUTTON_HOVER_SPRITE,
                .font_scale = 4.5,
                .minimum_font_size_pixels = 9,
                .active_top_padding_scale = 0.0,
                .idle_bottom_padding_scale = 2.0,
            },
            .utility => .{
                .id_prefix = "utility-btn-",
                .text_container_id_prefix = "utility-btn-text-container-",
                .base_width_pixels = UTILITY_BUTTON_BASE_WIDTH,
                .base_height_pixels = UTILITY_BUTTON_BASE_HEIGHT,
                .idle_sprite_path = UTILITY_BUTTON_SPRITE,
                .active_sprite_path = UTILITY_BUTTON_HOVER_SPRITE,
                .font_scale = 3.25,
                .minimum_font_size_pixels = 6,
                .active_top_padding_scale = 0.5,
                .idle_bottom_padding_scale = 1.0,
            },
        };
    }
};

/// Returns the asset path for the Silkscreen font family (bold or regular weight).
pub fn getFontPath(is_bold: bool) []const u8 {
    return if (is_bold) FONT_BOLD else FONT_REGULAR;
}

/// Returns the active frame font ID for Silkscreen-Regular.
pub fn regularFontId() u16 {
    return lm.ui.fontID(FONT_REGULAR);
}

/// Returns the active frame font ID for Silkscreen-Bold.
pub fn boldFontId() u16 {
    return lm.ui.fontID(FONT_BOLD);
}

/// Returns the active frame font ID for Silkscreen (bold when `is_bold` is true, regular otherwise).
pub fn getFontId(is_bold: bool) u16 {
    return lm.ui.fontID(getFontPath(is_bold));
}

/// Scales a base pixel metric by `ui_scale`, clamping at `minimum_pixels`.
pub fn scaledU16(base_pixels: f32, minimum_pixels: u16, ui_scale: f32) u16 {
    const minimum_float: f32 = @floatFromInt(minimum_pixels);
    return lm.tou16(@max(minimum_float, @round(base_pixels * ui_scale)));
}

/// Calculates integer-stepped UI scale factor from the current window dimensions.
pub fn calculateUiScale(window_dimensions: lm.Vector2) f32 {
    const scale_x = window_dimensions.x / 1280.0;
    const scale_y = window_dimensions.y / 720.0;
    const resolution_tier = @max(0.0, @floor(@min(scale_x, scale_y)));
    return BASE_UI_SCALE + (2.0 * resolution_tier);
}

test "theme.calculateUiScale integer scaling" {
    try std.testing.expectEqual(@as(f32, 4.0), calculateUiScale(.{ .x = 1280, .y = 720 }));
    try std.testing.expectEqual(@as(f32, 4.0), calculateUiScale(.{ .x = 1920, .y = 1080 }));
    try std.testing.expectEqual(@as(f32, 6.0), calculateUiScale(.{ .x = 2560, .y = 1440 }));
    try std.testing.expectEqual(@as(f32, 8.0), calculateUiScale(.{ .x = 3840, .y = 2160 }));
    try std.testing.expectEqual(@as(f32, 4.0), calculateUiScale(.{ .x = 2560, .y = 1080 }));
    try std.testing.expectEqual(@as(f32, 6.0), calculateUiScale(.{ .x = 3440, .y = 1440 }));
    try std.testing.expectEqual(@as(f32, 2.0), calculateUiScale(.{ .x = 800, .y = 600 }));
}

test "theme.scaledU16 clamps to minimum pixels" {
    try std.testing.expectEqual(@as(u16, 18), scaledU16(4.5, 9, 4.0));
    try std.testing.expectEqual(@as(u16, 9), scaledU16(2.0, 9, 2.0));
    try std.testing.expectEqual(@as(u16, 1), scaledU16(0.25, 1, 2.0));
}
