const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;
const clay = lm.deps.clay;
const Boon = @import("../boons/Boon.zig");

/// Fullscreen menu background color.
pub const screen_background: clay.Color = ui.color(10, 12, 16, 255);
/// Semi-transparent modal backdrop color.
pub const backdrop_overlay: clay.Color = ui.color(6, 8, 12, 195);
/// Semi-transparent danger/game-over modal backdrop color.
pub const backdrop_danger: clay.Color = ui.color(8, 4, 6, 225);

/// Primary modal panel background color.
pub const panel_background: clay.Color = ui.color(16, 18, 25, 250);
/// Translucent modal container background color.
pub const panel_translucent_background: clay.Color = ui.color(18, 20, 26, 235);
/// Standard modal panel border color.
pub const panel_border: clay.Color = ui.color(55, 62, 80, 200);
/// Subtle container border color.
pub const panel_subtle_border: clay.Color = ui.color(55, 60, 75, 180);
/// Game over card background color.
pub const panel_danger_background: clay.Color = ui.color(16, 12, 16, 252);
/// Elevated inner box surface color.
pub const surface_elevated: clay.Color = ui.color(20, 22, 28, 220);
/// Danger inset box surface color.
pub const surface_danger_inset: clay.Color = ui.color(24, 18, 24, 200);
/// Status pill background color.
pub const status_pill_background: clay.Color = ui.color(24, 28, 38, 180);
/// Main menu high score badge background color.
pub const stats_badge_background: clay.Color = ui.color(16, 20, 28, 220);
/// Main menu high score stats text color.
pub const stats_badge_text: clay.Color = ui.color(238, 230, 234, 255);

/// Highlighted/selected interactive row background color.
pub const row_selected_background: clay.Color = ui.color(28, 33, 46, 220);
/// Warm highlighted volume row background color.
pub const row_selected_warm_background: clay.Color = ui.hex(0x2a1e23ff);
/// Idle interactive row background color.
pub const row_idle_background: clay.Color = ui.color(20, 23, 31, 160);
/// Dark idle volume row background color.
pub const row_dark_background: clay.Color = ui.hex(0x0c0c0cff);
/// Idle interactive row border color.
pub const row_idle_border: clay.Color = ui.color(40, 46, 60, 120);
/// Table header row background color.
pub const table_header_background: clay.Color = ui.color(25, 30, 42, 220);
/// Alternating even table row background color.
pub const table_row_even_background: clay.Color = ui.color(18, 21, 28, 180);
/// Alternating odd table row background color.
pub const table_row_odd_background: clay.Color = ui.color(14, 16, 22, 180);

/// Pure white high-contrast text color.
pub const text_bright: clay.Color = ui.color(255, 255, 255, 255);
/// Active control binding text color.
pub const text_active_binding: clay.Color = ui.color(240, 245, 255, 255);
/// Standard primary label text color.
pub const text_primary: clay.Color = ui.color(220, 225, 235, 255);
/// Standard body description text color.
pub const text_body: clay.Color = ui.color(210, 215, 225, 255);
/// Secondary informational text color.
pub const text_secondary: clay.Color = ui.color(180, 190, 210, 240);
/// Danger screen subtitle text color.
pub const text_danger_subtitle: clay.Color = ui.color(180, 165, 175, 255);
/// Muted label or inactive header text color.
pub const text_muted: clay.Color = ui.color(150, 160, 180, 200);
/// Subtle category or subtitle text color.
pub const text_subtle: clay.Color = ui.color(150, 155, 170, 255);
/// Danger stat label text color.
pub const text_danger_muted: clay.Color = ui.color(160, 150, 160, 255);
/// Dimmed inactive control binding text color.
pub const text_dim: clay.Color = ui.color(140, 150, 170, 180);
/// Navigation hint footer text color.
pub const text_footer: clay.Color = ui.color(140, 150, 175, 200);
/// Selected row and HUD round indicator warm gold text color.
pub const text_highlight_gold: clay.Color = ui.color(255, 235, 170, 255);
/// Active input device column header text color.
pub const text_active_device: clay.Color = ui.color(255, 235, 140, 255);
/// Disabled card title text color.
pub const text_disabled_title: clay.Color = ui.color(140, 145, 160, 200);
/// Disabled card description text color.
pub const text_disabled_body: clay.Color = ui.color(110, 115, 130, 170);
/// Disabled card rarity text color.
pub const text_disabled_muted: clay.Color = ui.color(100, 105, 120, 160);
/// Disabled card category text color.
pub const text_disabled_subtle: clay.Color = ui.color(90, 95, 110, 160);

/// Primary gold accent color for titles and active highlights.
pub const accent_gold: clay.Color = ui.color(240, 200, 100, 255);
/// Bright gold accent color for boon headers.
pub const accent_gold_bright: clay.Color = ui.color(255, 215, 100, 255);
/// Gold border highlight color for selected elements and pause cards.
pub const accent_gold_border: clay.Color = ui.color(240, 200, 100, 200);
/// Cyan accent color for experience stats.
pub const accent_cyan: clay.Color = ui.color(100, 200, 255, 255);
/// Cyan border color for stats badges.
pub const accent_cyan_border: clay.Color = ui.color(100, 200, 255, 120);
/// Cyan text color for stats badges.
pub const accent_cyan_text: clay.Color = ui.color(140, 215, 255, 230);
/// Crimson accent color for game over title.
pub const accent_crimson: clay.Color = ui.color(240, 70, 75, 255);
/// Crimson stat value color for enemies defeated.
pub const accent_crimson_stat: clay.Color = ui.color(235, 90, 95, 255);
/// Crimson border color for game over card.
pub const accent_crimson_border: clay.Color = ui.color(190, 45, 55, 230);
/// Green accent color for high score values.
pub const accent_green: clay.Color = ui.color(180, 230, 140, 255);
/// Subtle border color for danger stat boxes.
pub const border_danger_subtle: clay.Color = ui.color(60, 48, 60, 180);

/// Selected or hovered button label text color.
pub const button_text_selected: clay.Color = ui.color(255, 255, 255, 255);
/// Idle button label text color.
pub const button_text_idle: clay.Color = ui.color(238, 230, 234, 255);
/// Primary idle action button text color.
pub const button_text_primary_idle: clay.Color = ui.color(240, 200, 205, 255);
/// Secondary idle action button text color.
pub const button_text_secondary_idle: clay.Color = ui.color(190, 180, 200, 255);
/// Disabled action button text color.
pub const button_text_disabled: clay.Color = ui.color(120, 105, 115, 200);
/// Hovered volume step button background color.
pub const step_button_hovered_background: clay.Color = ui.color(50, 58, 78, 255);
/// Idle volume step button background color.
pub const step_button_idle_background: clay.Color = ui.color(30, 35, 48, 220);
/// Gamepad hint badge background color.
pub const badge_gamepad_background: clay.Color = ui.color(55, 60, 75, 200);
/// Keyboard hint badge background color.
pub const badge_keyboard_background: clay.Color = ui.color(35, 40, 52, 200);
/// Gamepad hint badge border color.
pub const badge_gamepad_border: clay.Color = ui.color(120, 130, 150, 180);
/// Keyboard hint badge border color.
pub const badge_keyboard_border: clay.Color = ui.color(70, 80, 100, 180);
/// Hint badge label text color.
pub const badge_text: clay.Color = ui.color(190, 200, 220, 230);
/// Boon rarity badge background color.
pub const badge_rarity_background: clay.Color = ui.color(14, 12, 12, 64);
/// Purchased boon badge background color.
pub const badge_purchased_background: clay.Color = ui.color(24, 27, 35, 230);
/// Purchased boon badge border color.
pub const badge_purchased_border: clay.Color = ui.color(60, 68, 85, 180);
/// Purchased boon badge label text color.
pub const badge_purchased_text: clay.Color = ui.color(160, 165, 180, 255);

/// Volume and progress bar trough background color.
pub const progress_trough_background: clay.Color = ui.color(24, 28, 38, 255);
/// Unselected active volume bar fill color.
pub const progress_fill_active: clay.Color = ui.color(70, 140, 230, 255);
/// Muted volume bar fill color.
pub const progress_fill_muted: clay.Color = ui.color(140, 60, 60, 220);
/// HUD top round indicator background color.
pub const hud_overlay_background: clay.Color = ui.color(18, 20, 26, 210);
/// HUD spell cooldown badge background color.
pub const hud_badge_background: clay.Color = ui.color(16, 18, 24, 230);
/// Translucent HUD panel background for XP and objectives.
pub const hud_translucent_background: clay.Color = ui.color(23, 21, 22, 196);
/// HUD player bar container background color.
pub const hud_bar_trough: clay.Color = ui.color(50, 50, 50, 255);
/// HUD player bar trough RGBA color.
pub const hud_bar_trough_rgba: lm.Color = .init(55, 51, 52, 255);
/// HUD player health bar fill RGBA color.
pub const hud_health_fill_rgba: lm.Color = .init(178, 82, 102, 255);
/// HUD player stamina bar fill RGBA color.
pub const hud_stamina_fill_rgba: lm.Color = .init(192, 144, 169, 255);
/// World interaction prompt background color.
pub const prompt_background: clay.Color = ui.color(23, 21, 22, 196);
/// World interaction prompt border color.
pub const prompt_border: clay.Color = ui.color(80, 160, 255, 220);

/// Normal boon rarity color.
pub const rarity_normal: clay.Color = ui.color(180, 190, 200, 255);
/// Rare boon rarity color.
pub const rarity_rare: clay.Color = ui.color(65, 160, 255, 255);
/// Epic boon rarity color.
pub const rarity_epic: clay.Color = ui.color(180, 85, 255, 255);
/// Legendary boon rarity color.
pub const rarity_legendary: clay.Color = ui.color(255, 195, 45, 255);
/// Mythic boon rarity color.
pub const rarity_mythic: clay.Color = ui.color(255, 60, 100, 255);
/// Cosmic boon rarity color.
pub const rarity_cosmic: clay.Color = ui.color(45, 240, 225, 255);

/// Mini-boss rank accent RGBA color.
pub const boss_mini_accent_rgba: lm.Color = .{ .r = 240, .g = 195, .b = 80, .a = 255 };
/// Boss rank accent RGBA color.
pub const boss_main_accent_rgba: lm.Color = .{ .r = 255, .g = 85, .b = 95, .a = 255 };
/// Boss name header text color.
pub const boss_title_text: clay.Color = ui.color(255, 240, 245, 255);
/// Boss rank badge background color.
pub const boss_rank_badge_background: clay.Color = ui.color(18, 16, 22, 220);
/// Boss health bar trough background color.
pub const boss_trough_background: clay.Color = ui.color(20, 14, 18, 240);
/// Boss health bar damage lag fill color.
pub const boss_damage_lag_fill: clay.Color = ui.color(235, 155, 45, 220);
/// Boss health bar current health fill color.
pub const boss_health_fill: clay.Color = ui.color(225, 28, 48, 255);
/// Boss health bar quarter-phase divider color.
pub const boss_phase_divider: clay.Color = ui.color(40, 16, 22, 180);

/// Returns the semantic UI color corresponding to a boon rarity tier.
pub fn rarityColor(rarity: Boon.Rarity) clay.Color {
    return switch (rarity) {
        .normal => rarity_normal,
        .rare => rarity_rare,
        .epic => rarity_epic,
        .legendary => rarity_legendary,
        .mythic => rarity_mythic,
        .cosmic => rarity_cosmic,
    };
}

/// Converts an RGBA color struct into a Clay UI color with a custom alpha channel.
pub fn fromRgbaWithAlpha(rgba: lm.Color, alpha: u8) clay.Color {
    return ui.color(rgba.r, rgba.g, rgba.b, alpha);
}
