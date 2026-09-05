const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const Boon = @import("../boons/Boon.zig");
const BoonPool = @import("../boons/BoonPool.zig");
const HUD = @import("../HUD.zig");
const AudioManager = @import("../audio/AudioManager.zig");

pub var boons: ?[]const Boon = null;
pub var selected_index: usize = 0;
var stick_moved_x: bool = false;
var stick_moved_y: bool = false;

pub fn show(boons_to_show: []const Boon) void {
    boons = boons_to_show;
    selected_index = 0;
    lm.time.pause();
}

pub fn hide() void {
    if (boons != null) {
        boons = null;
        lm.time.proceed();
    }
}

pub fn isShowing() bool {
    return boons != null;
}

fn selectBoon(boon: Boon, stats_opt: ?*Stats, attack_opt: ?*Attack) void {
    const stats = stats_opt orelse return;
    const cost = boon.cost();

    if (stats.current.experience < cost) {
        AudioManager.playSfxPitched("audio/click.wav", 0.5, 0.1);
        return;
    }

    stats.current.experience -= cost;
    AudioManager.playSfxPitched("audio/coin.wav", 0.9, 0.05);

    boon.applyTo(stats, attack_opt);
    BoonPool.consumeBoon(boon);

    if (attack_opt) |attack| {
        boons = BoonPool.getCurrentBoons(stats.*, attack.*);
        return;
    }

    hide();
}

fn rarityColor(rarity: Boon.Rarity) lm.deps.clay.Color {
    return switch (rarity) {
        .normal => ui.color(180, 190, 200, 255),
        .rare => ui.color(65, 160, 255, 255),
        .epic => ui.color(180, 85, 255, 255),
        .legendary => ui.color(255, 195, 45, 255),
        .mythic => ui.color(255, 60, 100, 255),
        .cosmic => ui.color(45, 240, 225, 255),
    };
}

fn rarityBgColor(rarity: Boon.Rarity, is_hovered: bool) lm.deps.clay.Color {
    if (is_hovered) {
        return switch (rarity) {
            .normal => ui.color(42, 46, 56, 245),
            .rare => ui.color(28, 44, 68, 245),
            .epic => ui.color(44, 28, 68, 245),
            .legendary => ui.color(60, 48, 24, 245),
            .mythic => ui.color(60, 24, 34, 245),
            .cosmic => ui.color(24, 54, 58, 245),
        };
    } else {
        return ui.color(28, 30, 38, 230);
    }
}

fn rarityBorderColor(rarity: Boon.Rarity, is_hovered: bool) lm.deps.clay.Color {
    if (is_hovered) {
        return rarityColor(rarity);
    } else {
        return ui.color(55, 60, 75, 180);
    }
}

fn boonCard(
    boon: Boon,
    index: u32,
    card_w: f32,
    stats: ?*Stats,
    attack: ?*Attack,
    alloc: ?std.mem.Allocator,
) void {
    const ui_scale = HUD.ui_scale;
    const card_padding = lm.tou16(@round(16 * ui_scale));
    const card_content_gap = lm.tou16(@round(6 * ui_scale));
    const img_size = @round(128 * ui_scale);
    const letter_spacing = lm.tou16(@max(2, @round(2 * ui_scale)));
    const is_focused = (selected_index == index);

    lm.deps.clay.UI()(.{
        .id = .IDI("boon-card-", index),
        .layout = .{
            .sizing = .{
                .h = .percent(1),
                .w = .fixed(card_w),
            },
            .direction = .top_to_bottom,
            .padding = .all(card_padding),
            .child_gap = card_content_gap,
            .child_alignment = .{ .x = .center },
        },
        .background_color = rarityBgColor(boon.rarity, lm.deps.clay.hovered() or is_focused),
        .corner_radius = .all(10 * ui_scale),
        .border = .{
            .color = rarityBorderColor(boon.rarity, lm.deps.clay.hovered() or is_focused),
            .width = .outside(if (lm.deps.clay.hovered() or is_focused) 2 else 1),
        },
    })({
        if (lm.deps.clay.hovered()) {
            selected_index = index;
            if (lm.mouse.getButtonDown(.left)) {
                selectBoon(boon, stats, attack);
            }
        }

        ui.text(
            boon.rarity.toString(),
            .{
                .font_size = lm.tou16(@round(12 * ui_scale)),
                .letter_spacing = letter_spacing,
                .alignment = .center,
                .color = rarityColor(boon.rarity),
            },
        );

        ui.new(.{
            .id = .IDI("boon-image-", index),
            .image = ui.image(
                boon.icon,
                .init(img_size, img_size),
            ) catch .{ .image_data = null },
            .aspect_ratio = .{ .aspect_ratio = 1 },
            .layout = .{
                .sizing = .{
                    .w = .fixed(img_size),
                    .h = .fixed(img_size),
                },
            },
        })({});

        ui.text(boon.boon_type.toString(), .{
            .color = ui.color(150, 155, 170, 255),
            .letter_spacing = letter_spacing,
            .font_size = lm.tou16(@round(11 * ui_scale)),
            .alignment = .center,
        });

        ui.text(boon.name, .{
            .color = ui.color(255, 255, 255, 255),
            .letter_spacing = letter_spacing,
            .font_size = lm.tou16(@round(17 * ui_scale)),
            .alignment = .center,
        });

        ui.text(boon.description, .{
            .color = ui.color(210, 215, 225, 255),
            .font_size = lm.tou16(@round(13 * ui_scale)),
            .alignment = .center,
        });

        ui.new(.{
            .id = .IDI("boon-card-spacer-", index),
            .layout = .{
                .sizing = .{
                    .h = .grow,
                },
            },
        })({});

        const cost_box_pad_x = lm.tou16(@round(12 * ui_scale));
        const cost_box_pad_y = lm.tou16(@round(5 * ui_scale));
        const cost_img_size = @round(18 * ui_scale);

        ui.new(.{
            .id = .IDI("boon-cost-box-", index),
            .background_color = ui.color(20, 22, 28, 220),
            .corner_radius = .all(6 * ui_scale),
            .border = .{
                .color = ui.color(55, 60, 75, 200),
                .width = .outside(1),
            },
            .layout = .{
                .padding = .axes(cost_box_pad_y, cost_box_pad_x),
                .child_gap = lm.tou16(@round(6 * ui_scale)),
                .child_alignment = .{ .y = .center },
                .direction = .left_to_right,
            },
        })({
            const price_text = if (alloc) |a| std.fmt.allocPrint(a, "{d}", .{boon.cost()}) catch "0" else "0";

            ui.new(.{
                .id = .IDI("experience-img-", index),
                .layout = .{
                    .sizing = .{
                        .h = .fixed(cost_img_size),
                        .w = .fixed(cost_img_size),
                    },
                },
                .image = ui.image(
                    "ui/sleep_icon.png",
                    .init(cost_img_size, cost_img_size),
                ) catch .{ .image_data = null },
            })({});
            ui.text(price_text, .{
                .color = ui.color(255, 255, 255, 255),
                .letter_spacing = letter_spacing,
                .font_size = lm.tou16(@round(14 * ui_scale)),
                .alignment = .center,
            });
        });
    });
}

pub fn draw(
    boon_array: []const Boon,
    stats: ?*Stats,
    attack: ?*Attack,
    alloc: ?std.mem.Allocator,
) void {
    if (boons == null) return;

    if (boon_array.len == 0) {
        if (lm.keyboard.getKeyDown(.escape) or
            (lm.gamepad.isAvailable(0) and (lm.gamepad.getButtonDown(0, .right_face_right) or lm.gamepad.getButtonDown(0, .right_face_down))))
        {
            hide();
            return;
        }

        const window_size = HUD.window_size;
        const ui_scale = HUD.ui_scale;
        const container_w = @min(window_size.x - 32, @max(500 * ui_scale, window_size.x * 0.5));
        const container_h = @min(window_size.y - 32, @max(260 * ui_scale, window_size.y * 0.4));
        const container_padding = lm.tou16(@round(24 * ui_scale));

        ui.new(.{
            .id = .ID("boon-empty-container"),
            .floating = .{
                .attach_to = .to_root,
                .attach_points = .{
                    .element = .center_center,
                    .parent = .center_center,
                },
            },
            .layout = .{
                .sizing = .{
                    .h = .fixed(container_h),
                    .w = .fixed(container_w),
                },
                .direction = .top_to_bottom,
                .child_alignment = .{ .x = .center, .y = .center },
                .child_gap = lm.tou16(@round(16 * ui_scale)),
                .padding = .all(container_padding),
            },
            .background_color = ui.color(18, 20, 26, 235),
            .corner_radius = .all(14 * ui_scale),
            .border = .{
                .color = ui.color(55, 60, 75, 180),
                .width = .outside(1),
            },
        })({
            ui.text("ALL BOONS CLAIMED", .{
                .color = ui.color(255, 215, 100, 255),
                .letter_spacing = lm.tou16(@round(2 * ui_scale)),
                .font_size = lm.tou16(@round(20 * ui_scale)),
                .alignment = .center,
            });

            ui.text("You have claimed all upgrades for this round.\nDefeat the next wave to restock new boons!", .{
                .color = ui.color(180, 185, 200, 255),
                .letter_spacing = lm.tou16(@round(1 * ui_scale)),
                .font_size = lm.tou16(@round(13 * ui_scale)),
                .alignment = .center,
            });

            lm.deps.clay.UI()(.{
                .id = .ID("boon-empty-close-button"),
                .layout = .{
                    .padding = .axes(
                        lm.tou16(@round(8 * ui_scale)),
                        lm.tou16(@round(28 * ui_scale)),
                    ),
                    .child_alignment = .{ .x = .center, .y = .center },
                },
                .background_color = if (lm.deps.clay.hovered()) ui.color(45, 52, 68, 250) else ui.color(28, 32, 42, 230),
                .corner_radius = .all(8 * ui_scale),
                .border = .{
                    .color = if (lm.deps.clay.hovered()) ui.color(200, 205, 220, 255) else ui.color(65, 70, 85, 200),
                    .width = .outside(if (lm.deps.clay.hovered()) 2 else 1),
                },
            })({
                if (lm.deps.clay.hovered() and lm.mouse.getButtonDown(.left)) {
                    hide();
                }

                ui.text("CLOSE", .{
                    .color = if (lm.deps.clay.hovered()) ui.color(255, 255, 255, 255) else ui.color(220, 225, 235, 255),
                    .letter_spacing = lm.tou16(@round(2 * ui_scale)),
                    .font_size = lm.tou16(@round(13 * ui_scale)),
                    .alignment = .center,
                });
            });
        });
        return;
    }

    if (lm.keyboard.getKeyDown(.escape)) {
        hide();
        return;
    }

    const num_cards = boon_array.len;
    const skip_index = num_cards;
    if (selected_index > skip_index) selected_index = 0;

    if (lm.gamepad.isAvailable(0)) {
        if (lm.gamepad.getButtonDown(0, .right_face_right)) {
            hide();
            return;
        }

        const stick = lm.gamepad.getStickVector(0, .left, 0.2);
        var nav_left = lm.gamepad.getButtonDown(0, .left_face_left) or lm.gamepad.getButtonDown(0, .left_trigger_1);
        var nav_right = lm.gamepad.getButtonDown(0, .left_face_right) or lm.gamepad.getButtonDown(0, .right_trigger_1);
        var nav_up = lm.gamepad.getButtonDown(0, .left_face_up);
        var nav_down = lm.gamepad.getButtonDown(0, .left_face_down);

        if (@abs(stick.x) > 0.5) {
            if (!stick_moved_x) {
                if (stick.x > 0) nav_right = true else nav_left = true;
                stick_moved_x = true;
            }
        } else if (@abs(stick.x) < 0.2) {
            stick_moved_x = false;
        }

        if (@abs(stick.y) > 0.5) {
            if (!stick_moved_y) {
                if (stick.y > 0) nav_down = true else nav_up = true;
                stick_moved_y = true;
            }
        } else if (@abs(stick.y) < 0.2) {
            stick_moved_y = false;
        }

        if (selected_index < num_cards) {
            if (nav_left) {
                if (selected_index > 0) selected_index -= 1 else selected_index = num_cards - 1;
            }
            if (nav_right) {
                if (selected_index + 1 < num_cards) selected_index += 1 else selected_index = 0;
            }
            if (nav_down) {
                selected_index = skip_index;
            }
        } else {
            if (nav_up) {
                selected_index = 0;
            }
            if (nav_left) {
                selected_index = 0;
            }
            if (nav_right) {
                selected_index = num_cards - 1;
            }
        }

        if (lm.gamepad.getButtonDown(0, .right_face_down)) {
            if (selected_index < num_cards) {
                selectBoon(boon_array[selected_index], stats, attack);
                if (!isShowing()) return;
            } else {
                hide();
                return;
            }
        }
    }

    const window_size = HUD.window_size;
    const ui_scale = HUD.ui_scale;

    const container_w = @min(window_size.x - 32, @max(740 * ui_scale, window_size.x * 0.78));
    const container_h = @min(window_size.y - 32, @max(440 * ui_scale, window_size.y * 0.76));

    const container_padding = lm.tou16(@round(18 * ui_scale));
    const container_gap = lm.tou16(@round(14 * ui_scale));
    const card_gap = lm.tou16(@round(14 * ui_scale));

    const num_cards_f: f32 = @floatFromInt(boon_array.len);
    const inner_w = container_w - @as(f32, @floatFromInt(container_padding * 2));
    const total_card_gaps = @as(f32, @floatFromInt(card_gap)) * (num_cards_f - 1);
    const card_w = (inner_w - total_card_gaps) / num_cards_f;

    ui.new(.{
        .id = .ID("boon-menu-container"),
        .floating = .{
            .attach_to = .to_root,
            .attach_points = .{
                .element = .center_center,
                .parent = .center_center,
            },
        },
        .layout = .{
            .sizing = .{
                .h = .fixed(container_h),
                .w = .fixed(container_w),
            },
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = container_gap,
            .padding = .all(container_padding),
        },
        .background_color = ui.color(18, 20, 26, 235),
        .corner_radius = .all(14 * ui_scale),
        .border = .{
            .color = ui.color(55, 60, 75, 180),
            .width = .outside(1),
        },
    })({
        ui.new(.{
            .id = .ID("boon-menu-header"),
            .layout = .{
                .direction = .top_to_bottom,
                .child_alignment = .{ .x = .center },
                .child_gap = lm.tou16(@round(4 * ui_scale)),
            },
        })({
            ui.text("CHOOSE A BOON", .{
                .color = ui.color(255, 215, 100, 255),
                .letter_spacing = lm.tou16(@round(3 * ui_scale)),
                .font_size = lm.tou16(@round(22 * ui_scale)),
                .alignment = .center,
            });
            ui.text("Select an upgrade to enhance your abilities", .{
                .color = ui.color(150, 155, 170, 255),
                .letter_spacing = lm.tou16(@round(1 * ui_scale)),
                .font_size = lm.tou16(@round(12 * ui_scale)),
                .alignment = .center,
            });
        });

        ui.new(.{
            .id = .ID("boon-cards-row"),
            .layout = .{
                .direction = .left_to_right,
                .sizing = .{
                    .w = .percent(1),
                    .h = .grow,
                },
                .child_gap = card_gap,
            },
        })({
            for (boon_array, 0..) |boon, index| {
                boonCard(boon, lm.tou32(index), card_w, stats, attack, alloc);
            }
        });

        const is_skip_focused = (selected_index == skip_index);

        lm.deps.clay.UI()(.{
            .id = .ID("boon-skip-button"),
            .layout = .{
                .padding = .axes(
                    lm.tou16(@round(8 * ui_scale)),
                    lm.tou16(@round(28 * ui_scale)),
                ),
                .child_alignment = .{ .x = .center, .y = .center },
            },
            .background_color = if (lm.deps.clay.hovered() or is_skip_focused) ui.color(45, 52, 68, 250) else ui.color(28, 32, 42, 230),
            .corner_radius = .all(8 * ui_scale),
            .border = .{
                .color = if (lm.deps.clay.hovered() or is_skip_focused) ui.color(200, 205, 220, 255) else ui.color(65, 70, 85, 200),
                .width = .outside(if (lm.deps.clay.hovered() or is_skip_focused) 2 else 1),
            },
        })({
            if (lm.deps.clay.hovered()) {
                selected_index = skip_index;
                if (lm.mouse.getButtonDown(.left)) {
                    hide();
                }
            }

            ui.text("SKIP", .{
                .color = if (lm.deps.clay.hovered() or is_skip_focused) ui.color(255, 255, 255, 255) else ui.color(220, 225, 235, 255),
                .letter_spacing = lm.tou16(@round(2 * ui_scale)),
                .font_size = lm.tou16(@round(13 * ui_scale)),
                .alignment = .center,
            });
        });
    });
}
