const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const HUD = @import("../HUD.zig");
const DevicePrompts = @import("../input/DevicePrompts.zig");
const color_scheme = @import("color_scheme.zig");

const Spell = @import("../../components/Weapons/Spell.zig");

fn progressBar(
    bar_index: u32,
    current_value: f32,
    maximum_value: f32,
    background_color: lm.Color,
    fill_color: lm.Color,
    height_pixels: f32,
) void {
    ui.new(.{
        .id = .IDI("progress-bar-", bar_index),
        .background_color = color_scheme.fromRgbaWithAlpha(background_color, background_color.a),
        .layout = .{
            .sizing = .{ .h = .fixed(height_pixels), .w = .percent(1) },
        },
    })({
        if (@round(current_value) != 0)
            ui.new(.{
                .id = .IDI("progress-bar-inner-", bar_index),
                .background_color = color_scheme.fromRgbaWithAlpha(fill_color, fill_color.a),
                .layout = .{
                    .sizing = .{ .h = .percent(1), .w = .percent(current_value / maximum_value) },
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
    badge_padding_y_pixels: u16,
    badge_padding_x_pixels: u16,
    key_font_size_pixels: u16,
) void {
    const corner_radius_pixels: f32 = if (is_gamepad) 1.5 * HUD.ui_scale else 0.75 * HUD.ui_scale;
    const horizontal_padding_pixels: u16 = if (is_gamepad)
        lm.tou16(@max(2, @round(1.0 * HUD.ui_scale)))
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
                .font_id = HUD.boldFontId(),
            });
        });
    });
}

fn drawSpellCooldownBadge(
    slot_index: u32,
    remaining_seconds: f32,
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
            .corner_radius = .all(0.75 * HUD.ui_scale),
            .layout = .{
                .padding = .axes(badge_padding_y_pixels, badge_padding_x_pixels),
                .child_alignment = .{ .x = .center, .y = .center },
            },
        })({
            ui.text(cooldown_text, .{
                .color = color_scheme.text_bright,
                .font_size = font_size_pixels,
                .letter_spacing = 1,
                .font_id = HUD.regularFontId(),
            });
        });
    });
}

fn drawPopulatedSpellSlot(
    spell: Spell,
    slot_index: u32,
    slot_size_pixels: f32,
    allocator: ?std.mem.Allocator,
) void {
    const badge_padding_y_pixels = lm.tou16(@max(1, @round(0.25 * HUD.ui_scale)));
    const badge_padding_x_pixels = lm.tou16(@max(1, @round(0.75 * HUD.ui_scale)));
    const font_size_pixels = lm.tou16(@max(5, @round(2.5 * HUD.ui_scale)));
    const key_font_size_pixels = lm.tou16(@max(4, @round(2.25 * HUD.ui_scale)));

    const prompt = DevicePrompts.getActionPrompt(if (slot_index == 0) .spell_0 else .spell_1);
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
            .padding = .all(lm.tou16(@max(1, @round(0.5 * HUD.ui_scale)))),
        },
    })({
        drawSpellKeyBadge(
            slot_index,
            prompt,
            is_gamepad,
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
    allocator: ?std.mem.Allocator,
) void {
    const slot_size_pixels = HUD.hud_height;
    if (maybe_spell) |spell| {
        drawPopulatedSpellSlot(spell, slot_index, slot_size_pixels, allocator);
    } else {
        drawEmptySpellSlot(slot_index, slot_size_pixels);
    }
}

fn experienceCounter(experience: usize, allocator: ?std.mem.Allocator) void {
    const counter_size_pixels = HUD.hud_height * 0.5;
    const font_size_pixels = lm.tou16(counter_size_pixels);

    ui.new(.{
        .id = .ID("experience-counter"),
        .floating = .{
            .attach_to = .to_root,
            .attach_points = .{
                .element = .right_bottom,
                .parent = .right_bottom,
            },
            .offset = .{ .x = -4.0 * HUD.ui_scale, .y = -1 * HUD.hud_height / 2 - 0.5 * counter_size_pixels },
        },
        .corner_radius = .all(lm.tou16(@round(1.0 * HUD.ui_scale))),
        .background_color = color_scheme.hud_translucent_background,
        .layout = .{
            .padding = .axes(lm.tou16(@round(1.0 * HUD.ui_scale)), lm.tou16(@round(2.0 * HUD.ui_scale))),
            .child_gap = lm.tou16(@round(2.0 * HUD.ui_scale)),
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
                .init(HUD.hud_height, HUD.hud_height),
            ) catch .{ .image_data = null },
        })({});

        const experience_text = if (allocator) |active_allocator|
            std.fmt.allocPrint(active_allocator, "{d}", .{experience}) catch "0"
        else
            "0";

        ui.text(experience_text, .{
            .line_height = font_size_pixels - lm.tou16(@max(1, @round(0.5 * HUD.ui_scale))),
            .font_size = font_size_pixels,
            .letter_spacing = lm.tou16(@max(1, @round(0.5 * HUD.ui_scale))),
            .color = color_scheme.text_bright,
            .font_id = HUD.boldFontId(),
        });
    });
}

pub fn draw(stats: *Stats, attack: *Attack, allocator: ?std.mem.Allocator) void {
    experienceCounter(stats.current.experience, allocator);

    const bar_overlay_width_pixels = 124.0 * HUD.ui_scale;
    const health_bar_overlay_height_pixels = 7.0 * HUD.ui_scale;
    const stamina_bar_overlay_height_pixels = 6.0 * HUD.ui_scale;

    ui.new(.{
        .id = .ID("player-hud"),
        .floating = .{
            .attach_to = .to_root,
            .attach_points = .{ .element = .center_bottom, .parent = .center_bottom },
            .offset = .{ .x = 0, .y = -1 * HUD.hud_height / 2 },
        },
        .layout = .{
            .child_gap = lm.tou16(@round(2.0 * HUD.ui_scale)),
            .direction = .left_to_right,
        },
    })({
        ui.new(.{
            .id = .ID("player-hud-health-bar-overlay"),
            .floating = .{
                .attach_to = .to_parent,
                .attach_points = .{
                    .element = .center_bottom,
                    .parent = .center_bottom,
                },
                .offset = .{ .x = 0, .y = -7.0 * HUD.ui_scale },
            },
            .layout = .{
                .sizing = .{ .w = .fixed(bar_overlay_width_pixels), .h = .fixed(health_bar_overlay_height_pixels) },
            },
            .image = ui.image("ui/hud/health_bar_overlay.png", .init(bar_overlay_width_pixels, health_bar_overlay_height_pixels)) catch .{ .image_data = null },
        })({});

        ui.new(.{
            .id = .ID("player-hud-stamina-bar-overlay"),
            .floating = .{
                .attach_to = .to_parent,
                .attach_points = .{
                    .element = .center_bottom,
                    .parent = .center_bottom,
                },
                .offset = .{ .x = 0, .y = -2.0 * HUD.ui_scale },
            },
            .layout = .{
                .sizing = .{ .w = .fixed(bar_overlay_width_pixels), .h = .fixed(stamina_bar_overlay_height_pixels) },
            },
            .image = ui.image("ui/hud/stamina_bar_overlay.png", .init(bar_overlay_width_pixels, stamina_bar_overlay_height_pixels)) catch .{ .image_data = null },
        })({});

        spellShower(attack.equipped_spells[0], 0, allocator);
        ui.new(.{
            .id = .ID("player-hud-progress-bars"),
            .layout = .{
                .sizing = .{ .h = .fixed(HUD.hud_height), .w = .fixed(HUD.hud_width) },
                .direction = .top_to_bottom,
                .padding = .axes(lm.tou16(@round(2.0 * HUD.ui_scale)), lm.tou16(@round(2.0 * HUD.ui_scale))),
            },
            .background_color = color_scheme.hud_bar_trough,
            .image = ui.image("ui/hud/background.png", .init(HUD.hud_width, HUD.hud_height)) catch .{ .image_data = null },
        })({
            ui.new(.{
                .id = .IDI("player-hud-padding-", 0),
                .layout = .{
                    .sizing = .{ .w = .percent(1), .h = .fixed(1.0 * HUD.ui_scale) },
                },
            })({});

            progressBar(
                0,
                stats.current.health,
                stats.max.health,
                color_scheme.hud_bar_trough_rgba,
                color_scheme.hud_health_fill_rgba,
                6.0 * HUD.ui_scale,
            );

            ui.new(.{
                .id = .IDI("player-hud-padding-", 1),
                .layout = .{
                    .sizing = .{ .w = .percent(1), .h = .fixed(1.0 * HUD.ui_scale) },
                },
            })({});

            progressBar(
                1,
                stats.current.stamina,
                stats.max.stamina,
                color_scheme.hud_bar_trough_rgba,
                color_scheme.hud_stamina_fill_rgba,
                3.0 * HUD.ui_scale,
            );

            ui.new(.{
                .id = .IDI("player-hud-padding-", 2),
                .layout = .{
                    .sizing = .{ .w = .percent(1), .h = .fixed(1.0 * HUD.ui_scale) },
                },
            })({});
        });
        spellShower(attack.equipped_spells[1], 1, allocator);
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
