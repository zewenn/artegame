const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const HUD = @import("../HUD.zig");

const Spell = @import("../../components/Weapons/Spell.zig");

var index: u32 = 0;

fn progressBar(current: f32, max: f32, bg_color: lm.Color, color: lm.Color, height: f32) void {
    defer index +%= 1;

    ui.new(.{
        .id = .IDI("progress-bar-", index),
        .background_color = ui.color(bg_color.r, bg_color.g, bg_color.b, bg_color.a),
        .layout = .{
            .sizing = .{ .h = .percent(height), .w = .percent(1) },
        },
    })({
        ui.new(.{
            .id = .IDI("progress-bar-inner-", index),
            .background_color = ui.color(color.r, color.g, color.b, color.a),
            .layout = .{
                .sizing = .{ .h = .percent(1), .w = .percent(current / max) },
            },
        })({});
    });
}

fn spellShower(
    maybe_spell: ?Spell,
    key_label: []const u8,
    slot_index: u32,
    alloc: ?std.mem.Allocator,
) void {
    const slot_size = HUD.hud_height;
    const badge_pad_y = lm.tou16(@max(1, @round(1 * HUD.scale)));
    const badge_pad_x = lm.tou16(@max(2, @round(3 * HUD.scale)));
    const font_sz = lm.tou16(@max(9, @round(10 * HUD.scale)));
    const key_font_sz = lm.tou16(@max(8, @round(9 * HUD.scale)));

    if (maybe_spell) |spell| {
        const is_on_cooldown = spell.cooldown_remaining > 0;

        ui.new(.{
            .id = .IDI("spell-slot-", slot_index),
            .image = ui.image(
                spell.icon,
                .init(slot_size, slot_size),
            ) catch .{ .image_data = null },
            .layout = .{
                .sizing = .{
                    .h = .fixed(slot_size),
                    .w = .fixed(slot_size),
                },
                .direction = .top_to_bottom,
                .padding = .all(lm.tou16(@max(2, @round(2 * HUD.scale)))),
            },
        })({
            // Top row: Keybind badge in top-left
            ui.new(.{
                .id = .IDI("spell-top-row-", slot_index),
                .layout = .{
                    .direction = .left_to_right,
                    .sizing = .{ .w = .percent(1) },
                },
            })({
                ui.new(.{
                    .id = .IDI("spell-key-badge-", slot_index),
                    .background_color = ui.color(15, 20, 28, 210),
                    .corner_radius = .all(3 * HUD.scale),
                    .border = .{
                        .color = ui.color(70, 80, 100, 180),
                        .width = .outside(1),
                    },
                    .layout = .{
                        .padding = .axes(badge_pad_y, badge_pad_x),
                        .child_alignment = .{ .x = .center, .y = .center },
                    },
                })({
                    ui.text(key_label, .{
                        .color = ui.color(210, 220, 235, 240),
                        .font_size = key_font_sz,
                        .letter_spacing = 1,
                    });
                });
            });

            // Middle space
            ui.new(.{
                .id = .IDI("spell-mid-spacer-", slot_index),
                .layout = .{
                    .sizing = .{ .h = .grow },
                },
            })({});

            // Bottom row: Cooldown on right corner (if on cooldown)
            if (is_on_cooldown) {
                ui.new(.{
                    .id = .IDI("spell-bottom-row-", slot_index),
                    .layout = .{
                        .direction = .left_to_right,
                        .sizing = .{ .w = .percent(1) },
                        .child_alignment = .{ .y = .center },
                    },
                })({
                    // Spacer pushing cooldown to right corner
                    ui.new(.{
                        .id = .IDI("spell-bottom-spacer-", slot_index),
                        .layout = .{
                            .sizing = .{ .w = .grow },
                        },
                    })({});

                    // Right corner: Cooldown indicator
                    ui.new(.{
                        .id = .IDI("spell-cooldown-badge-", slot_index),
                        .background_color = ui.color(16, 18, 24, 230),
                        .corner_radius = .all(3 * HUD.scale),
                        .layout = .{
                            .padding = .axes(badge_pad_y, badge_pad_x),
                            .child_alignment = .{ .x = .center, .y = .center },
                        },
                    })({
                        const cd_str = if (alloc) |a| blk: {
                            if (spell.cooldown_remaining >= 10.0) {
                                break :blk std.fmt.allocPrint(a, "{d:.0}s", .{@ceil(spell.cooldown_remaining)}) catch "0s";
                            } else {
                                break :blk std.fmt.allocPrint(a, "{d:.1}s", .{spell.cooldown_remaining}) catch "0s";
                            }
                        } else "0s";

                        ui.text(cd_str, .{
                            .color = ui.color(255, 255, 255, 255),
                            .font_size = font_sz,
                            .letter_spacing = 1,
                        });
                    });
                });
            }
        });
    } else {
        ui.new(.{
            .id = .IDI("spell-empty-", slot_index),
            .image = ui.image(
                "backgrounds/neunyx32x32.png",
                .init(slot_size, slot_size),
            ) catch .{ .image_data = null },
            .layout = .{
                .sizing = .{
                    .h = .fixed(slot_size),
                    .w = .fixed(slot_size),
                },
            },
        })({});
    }
}

fn experienceCounter(experience: usize, alloc: ?std.mem.Allocator) void {
    ui.new(.{
        .id = .ID("experience-counter"),
        .background_color = ui.color(50, 50, 50, 128),
        .floating = .{
            .attach_to = .to_root,
            .attach_points = .{
                .element = .right_bottom,
                .parent = .right_bottom,
            },
            .offset = .{ .x = -1 * HUD.hud_height / 2, .y = -1.5 * HUD.hud_height / 2 },
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
                    .h = .fixed(HUD.hud_height / 2),
                    .w = .fixed(HUD.hud_height / 2),
                },
            },
            .image = ui.image(
                "ui/sleep_icon.png",
                .init(HUD.hud_height, HUD.hud_height),
            ) catch .{ .image_data = null },
        })({});

        const exp_str = if (alloc) |a|
            std.fmt.allocPrint(a, "{d}", .{experience}) catch "0"
        else
            "0";

        ui.text(exp_str, .{
            .font_size = lm.tou16(HUD.hud_height / 2),
            .letter_spacing = 2,
            .color = ui.color(255, 255, 255, 255),
        });
    });
}

pub fn draw(stats: *Stats, attack: *Attack, alloc: ?std.mem.Allocator) void {
    experienceCounter(stats.current.experience, alloc);

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
        spellShower(attack.equipped_spells[0], if (lm.gamepad.isAvailable(0)) "X" else "Q", 0, alloc);
        ui.new(.{
            .id = .ID("player-hud-progress-bars"),
            .layout = .{
                .sizing = .{ .h = .fixed(HUD.hud_height), .w = .fixed(HUD.hud_width) },
                .direction = .top_to_bottom,
                .child_gap = 5,
                .padding = .axes(lm.tou16(HUD.scale * 6), lm.tou16(HUD.scale * 6)),
            },
            .background_color = ui.color(50, 50, 50, 255),
            .image = ui.image("ui/HUD/background.png", .init(HUD.hud_width, HUD.hud_height)) catch .{ .image_data = null },
        })({
            progressBar(
                stats.current.health,
                stats.max.health,
                .init(50, 50, 50, 255),
                .init(220, 20, 120, 255),
                0.7,
            );
            progressBar(
                stats.current.stamina,
                stats.max.stamina,
                .init(50, 50, 50, 255),
                .init(220, 220, 220, 255),
                0.3,
            );
        });
        spellShower(attack.equipped_spells[1], if (lm.gamepad.isAvailable(0)) "Y" else "E", 1, alloc);
    });
}
