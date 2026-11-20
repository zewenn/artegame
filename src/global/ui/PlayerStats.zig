const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;
const clay = lm.deps.clay;

const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const DevicePrompts = @import("../input/DevicePrompts.zig");
const theme = @import("theme.zig");
const color_scheme = @import("color_scheme.zig");

const Spell = @import("../../components/weapons/Spell.zig");

const ResourceBarSpec = struct {
    field_name: []const u8,
    fill_color: clay.Color,
    bar_height_scale: f32,
    overlay_id: []const u8,
    overlay_sprite: []const u8,
    overlay_height_scale: f32,
    overlay_offset_y_scale: f32,
};

const resource_bars = [_]ResourceBarSpec{
    .{
        .field_name = "health",
        .fill_color = color_scheme.hud_health_fill,
        .bar_height_scale = 6.0,
        .overlay_id = "player-hud-health-bar-overlay",
        .overlay_sprite = "ui/hud/health_bar_overlay.png",
        .overlay_height_scale = 7.0,
        .overlay_offset_y_scale = -7.0,
    },
    .{
        .field_name = "stamina",
        .fill_color = color_scheme.hud_stamina_fill,
        .bar_height_scale = 4.0,
        .overlay_id = "player-hud-stamina-bar-overlay",
        .overlay_sprite = "ui/hud/stamina_bar_overlay.png",
        .overlay_height_scale = 6.0,
        .overlay_offset_y_scale = -2.0,
    },
};

const spell_prompt_actions = [2]DevicePrompts.PromptAction{ .spell_0, .spell_1 };

fn calculateFillRatio(current_value: f32, maximum_value: f32) f32 {
    if (maximum_value <= 0.0) return 0.0;
    return std.math.clamp(current_value / maximum_value, 0.0, 1.0);
}

fn progressBar(
    bar_index: u32,
    current_value: f32,
    maximum_value: f32,
    background_color: clay.Color,
    fill_color: clay.Color,
    height_pixels: f32,
) void {
    const fill_ratio = calculateFillRatio(current_value, maximum_value);
    const should_draw_fill = @round(current_value) > 0.0 and fill_ratio > 0.0;

    ui.new(.{
        .id = .IDI("progress-bar-", bar_index),
        .background_color = background_color,
        .layout = .{
            .sizing = .{ .h = .fixed(height_pixels), .w = .percent(1) },
        },
    })({
        if (!should_draw_fill) return;
        ui.new(.{
            .id = .IDI("progress-bar-inner-", bar_index),
            .background_color = fill_color,
            .layout = .{
                .sizing = .{ .h = .percent(1), .w = .percent(fill_ratio) },
            },
        })({});
    });
}

fn formatCooldownSeconds(allocator: ?std.mem.Allocator, remaining_seconds: f32) []const u8 {
    const active_allocator = allocator orelse return "0s";
    if (remaining_seconds >= 10.0) {
        return std.fmt.allocPrint(active_allocator, "{d:.0}s", .{@ceil(remaining_seconds)}) catch "0s";
    }
    return std.fmt.allocPrint(active_allocator, "{d:.1}s", .{remaining_seconds}) catch "0s";
}

fn drawSpellKeyBadge(
    slot_index: u32,
    prompt: DevicePrompts.ActionPrompt,
    is_gamepad: bool,
    ui_scale: f32,
    badge_padding_y_pixels: u16,
    badge_padding_x_pixels: u16,
    key_font_size_pixels: u16,
) void {
    const corner_radius_pixels: f32 = if (is_gamepad) 1.5 * ui_scale else 0.75 * ui_scale;
    const horizontal_padding_pixels: u16 = if (is_gamepad)
        theme.scaledU16(1.0, 2, ui_scale)
    else
        badge_padding_x_pixels;

    ui.new(.{
        .id = .IDI("spell-top-row-", slot_index),
        .layout = .{
            .direction = .left_to_right,
            .sizing = .{ .w = .percent(1) },
        },
    })({
        ui.new(.{
            .id = .IDI("spell-key-badge-", slot_index),
            .background_color = prompt.badge_background_color,
            .corner_radius = .all(corner_radius_pixels),
            .border = .{
                .color = prompt.badge_border_color,
                .width = .outside(1),
            },
            .layout = .{
                .padding = .axes(badge_padding_y_pixels, horizontal_padding_pixels),
                .child_alignment = .{ .x = .center, .y = .center },
            },
        })({
            ui.text(prompt.label, .{
                .color = prompt.text_color,
                .font_size = key_font_size_pixels,
                .letter_spacing = 1,
                .font_id = theme.boldFontId(),
            });
        });
    });
}

fn drawSpellCooldownBadge(
    slot_index: u32,
    remaining_seconds: f32,
    ui_scale: f32,
    badge_padding_y_pixels: u16,
    badge_padding_x_pixels: u16,
    font_size_pixels: u16,
    allocator: ?std.mem.Allocator,
) void {
    const cooldown_text = formatCooldownSeconds(allocator, remaining_seconds);

    ui.new(.{
        .id = .IDI("spell-bottom-row-", slot_index),
        .layout = .{
            .direction = .left_to_right,
            .sizing = .{ .w = .percent(1) },
            .child_alignment = .{ .y = .center },
        },
    })({
        ui.new(.{
            .id = .IDI("spell-bottom-spacer-", slot_index),
            .layout = .{ .sizing = .{ .w = .grow } },
        })({});

        ui.new(.{
            .id = .IDI("spell-cooldown-badge-", slot_index),
            .background_color = color_scheme.hud_badge_background,
            .corner_radius = .all(0.75 * ui_scale),
            .layout = .{
                .padding = .axes(badge_padding_y_pixels, badge_padding_x_pixels),
                .child_alignment = .{ .x = .center, .y = .center },
            },
        })({
            ui.text(cooldown_text, .{
                .color = color_scheme.text_bright,
                .font_size = font_size_pixels,
                .letter_spacing = 1,
                .font_id = theme.regularFontId(),
            });
        });
    });
}

fn drawPopulatedSpellSlot(
    spell: Spell,
    slot_index: u32,
    slot_size_pixels: f32,
    ui_scale: f32,
    allocator: ?std.mem.Allocator,
) void {
    const badge_padding_y_pixels = theme.scaledU16(0.25, 1, ui_scale);
    const badge_padding_x_pixels = theme.scaledU16(0.75, 1, ui_scale);
    const font_size_pixels = theme.scaledU16(2.5, 5, ui_scale);
    const key_font_size_pixels = theme.scaledU16(2.25, 4, ui_scale);

    const prompt = DevicePrompts.getActionPrompt(spell_prompt_actions[slot_index]);
    const is_gamepad = DevicePrompts.isGamepad();

    ui.new(.{
        .id = .IDI("spell-slot-", slot_index),
        .image = ui.image(
            spell.icon,
            .init(slot_size_pixels, slot_size_pixels),
        ) catch .{ .image_data = null },
        .layout = .{
            .sizing = .{
                .h = .fixed(slot_size_pixels),
                .w = .fixed(slot_size_pixels),
            },
            .direction = .top_to_bottom,
            .padding = .all(theme.scaledU16(0.5, 1, ui_scale)),
        },
    })({
        drawSpellKeyBadge(
            slot_index,
            prompt,
            is_gamepad,
            ui_scale,
            badge_padding_y_pixels,
            badge_padding_x_pixels,
            key_font_size_pixels,
        );

        ui.new(.{
            .id = .IDI("spell-mid-spacer-", slot_index),
            .layout = .{ .sizing = .{ .h = .grow } },
        })({});

        if (spell.cooldown_remaining > 0.0) {
            drawSpellCooldownBadge(
                slot_index,
                spell.cooldown_remaining,
                ui_scale,
                badge_padding_y_pixels,
                badge_padding_x_pixels,
                font_size_pixels,
                allocator,
            );
        }
    });
}

fn drawEmptySpellSlot(slot_index: u32, slot_size_pixels: f32) void {
    ui.new(.{
        .id = .IDI("spell-empty-", slot_index),
        .image = ui.image(
            "backgrounds/neunyx32x32.png",
            .init(slot_size_pixels, slot_size_pixels),
        ) catch .{ .image_data = null },
        .layout = .{
            .sizing = .{
                .h = .fixed(slot_size_pixels),
                .w = .fixed(slot_size_pixels),
            },
        },
    })({});
}

fn spellShower(
    maybe_spell: ?Spell,
    slot_index: u32,
    ui_scale: f32,
    allocator: ?std.mem.Allocator,
) void {
    const slot_size_pixels = ui_scale * 16.0;
    if (maybe_spell) |spell| {
        drawPopulatedSpellSlot(spell, slot_index, slot_size_pixels, ui_scale, allocator);
    } else {
        drawEmptySpellSlot(slot_index, slot_size_pixels);
    }
}

fn experienceCounter(experience: usize, ui_scale: f32) void {
    const hud_height_pixels = ui_scale * 16.0;
    const counter_size_pixels = hud_height_pixels * 0.5;
    const font_size_pixels = lm.tou16(counter_size_pixels);

    ui.new(.{
        .id = .ID("experience-counter"),
        .floating = .{
            .attach_to = .to_root,
            .attach_points = .{
                .element = .right_bottom,
                .parent = .right_bottom,
            },
            .offset = .{ .x = -4.0 * ui_scale, .y = -1 * hud_height_pixels / 2 - 0.5 * counter_size_pixels },
        },
        .corner_radius = .all(lm.tou16(@round(1.0 * ui_scale))),
        .background_color = color_scheme.hud_translucent_background,
        .layout = .{
            .padding = .axes(lm.tou16(@round(1.0 * ui_scale)), lm.tou16(@round(2.0 * ui_scale))),
            .child_gap = lm.tou16(@round(2.0 * ui_scale)),
            .direction = .left_to_right,
        },
    })({
        ui.new(.{
            .id = .ID("experience-img"),
            .layout = .{
                .sizing = .{
                    .h = .fixed(counter_size_pixels),
                    .w = .fixed(counter_size_pixels),
                },
            },
            .image = ui.image(
                "items/exp_orb.png",
                .init(hud_height_pixels, hud_height_pixels),
            ) catch .{ .image_data = null },
        })({});

        ui.textFmt("{d}", .{experience}, .{
            .line_height = font_size_pixels - theme.scaledU16(0.5, 1, ui_scale),
            .font_size = font_size_pixels,
            .letter_spacing = theme.scaledU16(0.5, 1, ui_scale),
            .color = color_scheme.text_bright,
            .font_id = theme.boldFontId(),
        });
    });
}

fn drawBarOverlay(comptime bar_spec: ResourceBarSpec, overlay_width_pixels: f32, ui_scale: f32) void {
    const overlay_height_pixels = bar_spec.overlay_height_scale * ui_scale;
    ui.new(.{
        .id = .ID(bar_spec.overlay_id),
        .floating = .{
            .attach_to = .to_parent,
            .attach_points = .{
                .element = .center_bottom,
                .parent = .center_bottom,
            },
            .offset = .{ .x = 0, .y = bar_spec.overlay_offset_y_scale * ui_scale },
        },
        .layout = .{
            .sizing = .{ .w = .fixed(overlay_width_pixels), .h = .fixed(overlay_height_pixels) },
        },
        .image = ui.image(bar_spec.overlay_sprite, .init(overlay_width_pixels, overlay_height_pixels)) catch .{ .image_data = null },
    })({});
}

fn drawProgressBarStack(stats: *Stats, hud_width_pixels: f32, hud_height_pixels: f32, ui_scale: f32) void {
    const bar_padding_pixels = lm.tou16(@round(2.0 * ui_scale));
    ui.new(.{
        .id = .ID("player-hud-progress-bars"),
        .layout = .{
            .sizing = .{ .h = .fixed(hud_height_pixels), .w = .fixed(hud_width_pixels) },
            .direction = .top_to_bottom,
            .padding = .axes(bar_padding_pixels, bar_padding_pixels),
        },
        .background_color = color_scheme.hud_bar_trough,
        .image = ui.image("ui/hud/background.png", .init(hud_width_pixels, hud_height_pixels)) catch .{ .image_data = null },
    })({
        ui.new(.{
            .id = .IDI("player-hud-padding-", 0),
            .layout = .{ .sizing = .{ .w = .percent(1), .h = .fixed(1.0 * ui_scale) } },
        })({});

        inline for (resource_bars, 0..) |bar_spec, bar_index| {
            progressBar(
                @intCast(bar_index),
                @field(stats.current, bar_spec.field_name),
                @field(stats.max, bar_spec.field_name),
                color_scheme.hud_bar_trough_fill,
                bar_spec.fill_color,
                bar_spec.bar_height_scale * ui_scale,
            );
        }

        ui.new(.{
            .id = .IDI("player-hud-padding-", 1),
            .layout = .{ .sizing = .{ .w = .percent(1), .h = .fixed(1.0 * ui_scale) } },
        })({});
    });
}

/// Renders the bottom-center player health, stamina, spell slots, and experience counter HUD.
pub fn draw(stats: *Stats, attack: *Attack, ui_scale: f32, allocator: ?std.mem.Allocator) void {
    experienceCounter(stats.current.experience, ui_scale);

    const hud_height_pixels = ui_scale * 16.0;
    const hud_width_pixels = hud_height_pixels * 8.0;
    const bar_overlay_width_pixels = 124.0 * ui_scale;

    ui.new(.{
        .id = .ID("player-hud"),
        .floating = .{
            .attach_to = .to_root,
            .attach_points = .{ .element = .center_bottom, .parent = .center_bottom },
            .offset = .{ .x = 0, .y = -1 * hud_height_pixels / 2 },
        },
        .layout = .{
            .child_gap = lm.tou16(@round(2.0 * ui_scale)),
            .direction = .left_to_right,
        },
    })({
        inline for (resource_bars) |bar_spec| {
            drawBarOverlay(bar_spec, bar_overlay_width_pixels, ui_scale);
        }

        spellShower(attack.equipped_spells[0], 0, ui_scale, allocator);
        drawProgressBarStack(stats, hud_width_pixels, hud_height_pixels, ui_scale);
        spellShower(attack.equipped_spells[1], 1, ui_scale, allocator);
    });
}

test "formatCooldownSeconds formats correctly" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try std.testing.expectEqualStrings("0s", formatCooldownSeconds(null, 5.0));
    try std.testing.expectEqualStrings("4.5s", formatCooldownSeconds(allocator, 4.5));
    try std.testing.expectEqualStrings("12s", formatCooldownSeconds(allocator, 11.2));
}

test "PlayerStats calculateFillRatio guards zero max and clamps bounds" {
    try std.testing.expectEqual(@as(f32, 0.0), calculateFillRatio(50.0, 0.0));
    try std.testing.expectEqual(@as(f32, 0.0), calculateFillRatio(50.0, -10.0));
    try std.testing.expectEqual(@as(f32, 0.0), calculateFillRatio(-5.0, 100.0));
    try std.testing.expectEqual(@as(f32, 1.0), calculateFillRatio(150.0, 100.0));
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), calculateFillRatio(50.0, 100.0), 0.0001);
}
