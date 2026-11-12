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
    height_ratio: f32,
) void {
    ui.new(.{
        .id = .IDI("progress-bar-", bar_index),
        .background_color = color_scheme.fromRgbaWithAlpha(background_color, background_color.a),
        .layout = .{
            .sizing = .{ .h = .percent(height_ratio), .w = .percent(1) },
        },
    })({
        ui.new(.{
            .id = .IDI("progress-bar-inner-", bar_index),
            .background_color = color_scheme.fromRgbaWithAlpha(fill_color, fill_color.a),
            .layout = .{
                .sizing = .{ .h = .percent(1), .w = .percent(current_value / maximum_value) },
            },
        })({});
    });
}

fn renderSpellKeyBadge(slot_index: u32) void {
    const is_gamepad = DevicePrompts.isGamepad();
    const prompt = DevicePrompts.getActionPrompt(if (slot_index == 0) .spell_0 else .spell_1);
    const key_font_size = lm.tou16(@max(8, @round(9 * HUD.scale)));
    const badge_padding_y_pixels = lm.tou16(@max(1, @round(1 * HUD.scale)));
    const badge_padding_x_pixels = lm.tou16(@max(2, @round(3 * HUD.scale)));
    const padding_x = if (is_gamepad) lm.tou16(@max(3, @round(4 * HUD.scale))) else badge_padding_x_pixels;
    const corner_radius_pixels = if (is_gamepad) 6 * HUD.scale else 3 * HUD.scale;

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
                .padding = .axes(badge_padding_y_pixels, padding_x),
                .child_alignment = .{ .x = .center, .y = .center },
            },
        })({
            ui.text(prompt.label, .{
                .color = prompt.text_color,
                .font_size = key_font_size,
                .letter_spacing = 1,
            });
        });
    });
}

fn renderSpellCooldownBadge(
    slot_index: u32,
    cooldown_remaining_seconds: f32,
    allocator: ?std.mem.Allocator,
) void {
    const font_size = lm.tou16(@max(9, @round(10 * HUD.scale)));
    const badge_padding_y_pixels = lm.tou16(@max(1, @round(1 * HUD.scale)));
    const badge_padding_x_pixels = lm.tou16(@max(2, @round(3 * HUD.scale)));

    const cooldown_text = if (allocator) |alloc| blk: {
        if (cooldown_remaining_seconds >= 10.0) {
            break :blk std.fmt.allocPrint(alloc, "{d:.0}s", .{@ceil(cooldown_remaining_seconds)}) catch "0s";
        } else {
            break :blk std.fmt.allocPrint(alloc, "{d:.1}s", .{cooldown_remaining_seconds}) catch "0s";
        }
    } else "0s";

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
            .corner_radius = .all(3 * HUD.scale),
            .layout = .{
                .padding = .axes(badge_padding_y_pixels, badge_padding_x_pixels),
                .child_alignment = .{ .x = .center, .y = .center },
            },
        })({
            ui.text(cooldown_text, .{
                .color = color_scheme.text_bright,
                .font_size = font_size,
                .letter_spacing = 1,
            });
        });
    });
}

fn renderActiveSpellSlot(
    spell: Spell,
    slot_index: u32,
    slot_size_pixels: f32,
    allocator: ?std.mem.Allocator,
) void {
    const padding_pixels = lm.tou16(@max(2, @round(2 * HUD.scale)));

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
            .padding = .all(padding_pixels),
        },
    })({
        renderSpellKeyBadge(slot_index);

        ui.new(.{
            .id = .IDI("spell-mid-spacer-", slot_index),
            .layout = .{ .sizing = .{ .h = .grow } },
        })({});

        if (spell.cooldown_remaining > 0) {
            renderSpellCooldownBadge(slot_index, spell.cooldown_remaining, allocator);
        }
    });
}

fn renderEmptySpellSlot(slot_index: u32, slot_size_pixels: f32) void {
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
        renderActiveSpellSlot(spell, slot_index, slot_size_pixels, allocator);
    } else {
        renderEmptySpellSlot(slot_index, slot_size_pixels);
    }
}

fn experienceCounter(experience: usize, allocator: ?std.mem.Allocator) void {
    const experience_size_pixels = HUD.hud_height / 2;

    ui.new(.{
        .id = .ID("experience-counter"),
        .background_color = color_scheme.hud_translucent_background,
        .floating = .{
            .attach_to = .to_root,
            .attach_points = .{
                .element = .right_bottom,
                .parent = .right_bottom,
            },
            .offset = .{ .x = -1 * experience_size_pixels, .y = -1.5 * experience_size_pixels },
        },
        .layout = .{
            .padding = .axes(5, 10),
            .child_gap = lm.tou16(10),
            .direction = .left_to_right,
        },
    })({
        ui.new(.{
            .id = .ID("experience-img"),
            .layout = .{
                .sizing = .{
                    .h = .fixed(experience_size_pixels),
                    .w = .fixed(experience_size_pixels),
                },
            },
            .image = ui.image(
                "items/exp_orb.png",
                .init(HUD.hud_height, HUD.hud_height),
            ) catch .{ .image_data = null },
        })({});

        const experience_text = if (allocator) |alloc|
            std.fmt.allocPrint(alloc, "{d}", .{experience}) catch "0"
        else
            "0";

        ui.text(experience_text, .{
            .font_size = lm.tou16(experience_size_pixels),
            .letter_spacing = 2,
            .color = color_scheme.text_bright,
        });
    });
}

pub fn draw(stats: *Stats, attack: *Attack, allocator: ?std.mem.Allocator) void {
    experienceCounter(stats.current.experience, allocator);

    ui.new(.{
        .id = .ID("player-hud"),
        .floating = .{
            .attach_to = .to_root,
            .attach_points = .{ .element = .center_bottom, .parent = .center_bottom },
            .offset = .{ .x = 0, .y = -1 * HUD.hud_height / 2 },
        },
        .layout = .{
            .child_gap = 5,
            .padding = .all(5),
            .direction = .left_to_right,
        },
    })({
        spellShower(attack.equipped_spells[0], 0, allocator);
        ui.new(.{
            .id = .ID("player-hud-progress-bars"),
            .layout = .{
                .sizing = .{ .h = .fixed(HUD.hud_height), .w = .fixed(HUD.hud_width) },
                .direction = .top_to_bottom,
                .child_gap = 5,
                .padding = .axes(lm.tou16(HUD.scale * 6), lm.tou16(HUD.scale * 6)),
            },
            .background_color = color_scheme.hud_bar_trough,
            .image = ui.image("ui/hud/background.png", .init(HUD.hud_width, HUD.hud_height)) catch .{ .image_data = null },
        })({
            progressBar(
                0,
                stats.current.health,
                stats.max.health,
                color_scheme.hud_bar_trough_rgba,
                color_scheme.hud_health_fill_rgba,
                0.7,
            );
            progressBar(
                1,
                stats.current.stamina,
                stats.max.stamina,
                color_scheme.hud_bar_trough_rgba,
                color_scheme.hud_stamina_fill_rgba,
                0.3,
            );
        });
        spellShower(attack.equipped_spells[1], 1, allocator);
    });
}
