const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const Boon = @import("../boons/Boon.zig");
const BoonPool = @import("../boons/BoonPool.zig");
const BoonCategory = @import("../boons/BoonCategory.zig");
const HUD = @import("../HUD.zig");
const AudioManager = @import("../audio/AudioManager.zig");
const RoomManager = @import("../RoomManager.zig");
const DevicePrompts = @import("../input/DevicePrompts.zig");

pub const BoonSlot = BoonPool.BoonSlot;

pub const BASE_CARD_WIDTH_PIXELS: f32 = 72.0;
pub const BASE_CARD_HEIGHT_PIXELS: f32 = 112.0;
pub const CARD_SCALE_MULTIPLIER: f32 = 4.0;
pub const CARD_ASPECT_RATIO: f32 = 9.0 / 14.0;

pub const BOON_CARD_SPRITE: []const u8 = "ui/hud/boon_card.png";
pub const BOON_CARD_HOVER_SPRITE: []const u8 = "ui/hud/boon_card_hovered.png";

pub var slots: ?[]const BoonSlot = null;
pub var selected_index: usize = 0;
var stick_moved_x: bool = false;
var stick_moved_y: bool = false;

pub fn getBoonCardSprite(is_active: bool) []const u8 {
    return if (is_active) BOON_CARD_HOVER_SPRITE else BOON_CARD_SPRITE;
}

pub fn calculateCardWidthPixels(ui_scale: f32) f32 {
    return @round(BASE_CARD_WIDTH_PIXELS * CARD_SCALE_MULTIPLIER * ui_scale);
}

pub fn calculateCardHeightPixels(ui_scale: f32) f32 {
    return @round(BASE_CARD_HEIGHT_PIXELS * CARD_SCALE_MULTIPLIER * ui_scale);
}

pub fn findFirstAvailableIndex(slot_array: []const BoonSlot) usize {
    for (slot_array, 0..) |slot, slot_index| {
        if (!slot.is_purchased) return slot_index;
    }
    return slot_array.len;
}

pub fn findNextAvailableIndex(current_index: usize, direction: i32, slot_array: []const BoonSlot) usize {
    const card_count = slot_array.len;
    const close_index = card_count;

    if (card_count == 0) return 0;

    if (direction > 0) {
        var search_index = current_index + 1;
        while (search_index < card_count) : (search_index += 1) {
            if (!slot_array[search_index].is_purchased) return search_index;
        }
        var wrap_index: usize = 0;
        while (wrap_index <= current_index and wrap_index < card_count) : (wrap_index += 1) {
            if (!slot_array[wrap_index].is_purchased) return wrap_index;
        }
        return close_index;
    }

    if (current_index > 0) {
        var search_index = current_index - 1;
        while (true) {
            if (!slot_array[search_index].is_purchased) return search_index;
            if (search_index == 0) break;
            search_index -= 1;
        }
    }
    var wrap_index = card_count;
    while (wrap_index > current_index) {
        wrap_index -= 1;
        if (!slot_array[wrap_index].is_purchased) return wrap_index;
    }
    return close_index;
}

pub fn show(slots_to_show: []const BoonSlot) void {
    slots = slots_to_show;
    selected_index = findFirstAvailableIndex(slots_to_show);
    lm.time.pause();
}

pub fn hide() void {
    if (slots == null) return;
    slots = null;
    lm.time.proceed();
}

pub fn isShowing() bool {
    return slots != null;
}

fn selectBoon(slot_index: usize, maybe_stats: ?*Stats, maybe_attack: ?*Attack) void {
    const stats = maybe_stats orelse return;
    const current_slots = slots orelse return;
    if (slot_index >= current_slots.len) return;
    const slot = current_slots[slot_index];
    if (slot.is_purchased) return;

    const boon = slot.boon;
    const cost = boon.cost();

    if (stats.current.experience < cost) {
        AudioManager.playSfxPitched("audio/sfx/click.wav", 0.5, 0.1);
        return;
    }

    stats.current.experience -= cost;
    AudioManager.playSfxPitched("audio/sfx/coin.wav", 0.9, 0.05);

    boon.applyTo(stats, maybe_attack);
    BoonPool.consumeBoon(boon);
    RoomManager.saveCurrentRun();

    if (maybe_attack) |attack| {
        slots = BoonPool.getSlots(stats.*, attack.*);
        if (slots) |updated_slots| {
            selected_index = findNextAvailableIndex(slot_index, 1, updated_slots);
        }
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

fn renderBoonCostBox(
    card_index: u32,
    cost: usize,
    ui_scale: f32,
    letter_spacing: u16,
    allocator: ?std.mem.Allocator,
) void {
    const cost_box_padding_x_pixels = lm.tou16(@round(12 * ui_scale));
    const cost_box_padding_y_pixels = lm.tou16(@round(5 * ui_scale));
    const cost_image_size_pixels = @round(18 * ui_scale);

    ui.new(.{
        .id = .IDI("boon-cost-box-", card_index),
        .background_color = ui.color(20, 22, 28, 220),
        .corner_radius = .all(6 * ui_scale),
        .border = .{
            .color = ui.color(55, 60, 75, 200),
            .width = .outside(1),
        },
        .layout = .{
            .padding = .axes(cost_box_padding_y_pixels, cost_box_padding_x_pixels),
            .child_gap = lm.tou16(@round(6 * ui_scale)),
            .child_alignment = .{ .y = .center },
            .direction = .left_to_right,
        },
    })({
        const price_text = if (allocator) |active_allocator|
            std.fmt.allocPrint(active_allocator, "{d}", .{cost}) catch "0"
        else
            "0";

        ui.new(.{
            .id = .IDI("experience-img-", card_index),
            .layout = .{
                .sizing = .{
                    .h = .fixed(cost_image_size_pixels),
                    .w = .fixed(cost_image_size_pixels),
                },
            },
            .image = ui.image(
                "items/exp_orb.png",
                .init(cost_image_size_pixels, cost_image_size_pixels),
            ) catch .{ .image_data = null },
        })({});
        ui.text(price_text, .{
            .color = ui.color(255, 255, 255, 255),
            .letter_spacing = letter_spacing,
            .font_size = lm.tou16(@round(14 * ui_scale)),
            .alignment = .center,
        });
    });
}

fn boonCard(
    boon: Boon,
    card_index: u32,
    card_width_pixels: f32,
    card_height_pixels: f32,
    stats: ?*Stats,
    attack: ?*Attack,
    allocator: ?std.mem.Allocator,
) void {
    const ui_scale = HUD.ui_scale;
    const card_padding_pixels = lm.tou16(@round(16 * ui_scale));
    const card_content_gap_pixels = lm.tou16(@round(6 * ui_scale));
    const icon_size_pixels = @round(96 * ui_scale);
    const letter_spacing = lm.tou16(@max(2, @round(2 * ui_scale)));
    const is_focused = (selected_index == card_index);

    lm.deps.clay.UI()(.{
        .id = .IDI("boon-card-", card_index),
        .layout = .{
            .sizing = .{
                .w = .fixed(card_width_pixels),
                .h = .fixed(card_height_pixels),
            },
            .direction = .top_to_bottom,
            .padding = .all(card_padding_pixels),
            .child_gap = card_content_gap_pixels,
            .child_alignment = .{ .x = .center },
        },
        .image = ui.image(
            getBoonCardSprite(lm.deps.clay.hovered() or is_focused),
            .init(card_width_pixels, card_height_pixels),
        ) catch .{ .image_data = null },
    })({
        if (lm.deps.clay.hovered()) {
            selected_index = card_index;
        }
        if (lm.deps.clay.hovered() and lm.mouse.getButtonDown(.left)) {
            selectBoon(card_index, stats, attack);
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
            .id = .IDI("boon-image-", card_index),
            .image = ui.image(
                boon.icon,
                .init(icon_size_pixels, icon_size_pixels),
            ) catch .{ .image_data = null },
            .aspect_ratio = .{ .aspect_ratio = 1 },
            .layout = .{
                .sizing = .{
                    .w = .fixed(icon_size_pixels),
                    .h = .fixed(icon_size_pixels),
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
            .id = .IDI("boon-card-spacer-", card_index),
            .layout = .{
                .sizing = .{
                    .h = .grow,
                },
            },
        })({});

        renderBoonCostBox(card_index, boon.cost(), ui_scale, letter_spacing, allocator);
    });
}

fn renderPurchasedBadge(card_index: u32, ui_scale: f32) void {
    const badge_padding_x_pixels = lm.tou16(@round(14 * ui_scale));
    const badge_padding_y_pixels = lm.tou16(@round(6 * ui_scale));

    ui.new(.{
        .id = .IDI("boon-dummy-badge-", card_index),
        .background_color = ui.color(24, 27, 35, 230),
        .corner_radius = .all(6 * ui_scale),
        .border = .{
            .color = ui.color(60, 68, 85, 180),
            .width = .outside(1),
        },
        .layout = .{
            .padding = .axes(badge_padding_y_pixels, badge_padding_x_pixels),
            .child_alignment = .{ .x = .center, .y = .center },
        },
    })({
        ui.text("PURCHASED", .{
            .color = ui.color(160, 165, 180, 255),
            .letter_spacing = lm.tou16(@round(2 * ui_scale)),
            .font_size = lm.tou16(@round(12 * ui_scale)),
            .alignment = .center,
        });
    });
}

fn dummyBoonCard(
    boon: Boon,
    card_index: u32,
    card_width_pixels: f32,
    card_height_pixels: f32,
) void {
    const ui_scale = HUD.ui_scale;
    const card_padding_pixels = lm.tou16(@round(16 * ui_scale));
    const card_content_gap_pixels = lm.tou16(@round(6 * ui_scale));
    const icon_size_pixels = @round(96 * ui_scale);
    const letter_spacing = lm.tou16(@max(2, @round(2 * ui_scale)));

    lm.deps.clay.UI()(.{
        .id = .IDI("boon-dummy-card-", card_index),
        .layout = .{
            .sizing = .{
                .w = .fixed(card_width_pixels),
                .h = .fixed(card_height_pixels),
            },
            .direction = .top_to_bottom,
            .padding = .all(card_padding_pixels),
            .child_gap = card_content_gap_pixels,
            .child_alignment = .{ .x = .center },
        },
        .image = ui.image(
            BOON_CARD_SPRITE,
            .init(card_width_pixels, card_height_pixels),
        ) catch .{ .image_data = null },
    })({
        ui.text(
            boon.rarity.toString(),
            .{
                .font_size = lm.tou16(@round(12 * ui_scale)),
                .letter_spacing = letter_spacing,
                .alignment = .center,
                .color = ui.color(100, 105, 120, 160),
            },
        );

        ui.new(.{
            .id = .IDI("boon-dummy-image-", card_index),
            .image = ui.image(
                boon.icon,
                .init(icon_size_pixels, icon_size_pixels),
            ) catch .{ .image_data = null },
            .aspect_ratio = .{ .aspect_ratio = 1 },
            .layout = .{
                .sizing = .{
                    .w = .fixed(icon_size_pixels),
                    .h = .fixed(icon_size_pixels),
                },
            },
        })({});

        ui.text(boon.boon_type.toString(), .{
            .color = ui.color(90, 95, 110, 160),
            .letter_spacing = letter_spacing,
            .font_size = lm.tou16(@round(11 * ui_scale)),
            .alignment = .center,
        });

        ui.text(boon.name, .{
            .color = ui.color(140, 145, 160, 200),
            .letter_spacing = letter_spacing,
            .font_size = lm.tou16(@round(17 * ui_scale)),
            .alignment = .center,
        });

        ui.text(boon.description, .{
            .color = ui.color(110, 115, 130, 170),
            .font_size = lm.tou16(@round(13 * ui_scale)),
            .alignment = .center,
        });

        ui.new(.{
            .id = .IDI("boon-dummy-spacer-", card_index),
            .layout = .{
                .sizing = .{
                    .h = .grow,
                },
            },
        })({});

        renderPurchasedBadge(card_index, ui_scale);
    });
}

fn updateStickAxis(
    axis_value: f32,
    stick_moved: *bool,
    positive_action: *bool,
    negative_action: *bool,
) void {
    if (@abs(axis_value) < 0.2) {
        stick_moved.* = false;
        return;
    }
    if (@abs(axis_value) <= 0.5 or stick_moved.*) return;

    if (axis_value > 0) {
        positive_action.* = true;
    } else {
        negative_action.* = true;
    }
    stick_moved.* = true;
}

fn handleInputNavigation(slot_array: []const BoonSlot, stats: ?*Stats, attack: ?*Attack) void {
    if (lm.keyboard.getKeyDown(.escape)) {
        hide();
        return;
    }

    const card_count = slot_array.len;
    const close_index = card_count;
    if (selected_index > close_index) selected_index = 0;

    var navigate_left = lm.keyboard.getKeyDown(.left) or lm.keyboard.getKeyDown(.a);
    var navigate_right = lm.keyboard.getKeyDown(.right) or lm.keyboard.getKeyDown(.d);
    var navigate_up = lm.keyboard.getKeyDown(.up) or lm.keyboard.getKeyDown(.w);
    var navigate_down = lm.keyboard.getKeyDown(.down) or lm.keyboard.getKeyDown(.s);
    var select_pressed = lm.keyboard.getKeyDown(.enter);

    if (lm.gamepad.isAvailable(0)) {
        if (lm.gamepad.getButtonDown(0, .right_face_right)) {
            hide();
            return;
        }

        const stick_vector = lm.gamepad.getStickVector(0, .left, 0.2);
        navigate_left = navigate_left or lm.gamepad.getButtonDown(0, .left_face_left) or lm.gamepad.getButtonDown(0, .left_trigger_1);
        navigate_right = navigate_right or lm.gamepad.getButtonDown(0, .left_face_right) or lm.gamepad.getButtonDown(0, .right_trigger_1);
        navigate_up = navigate_up or lm.gamepad.getButtonDown(0, .left_face_up);
        navigate_down = navigate_down or lm.gamepad.getButtonDown(0, .left_face_down);

        updateStickAxis(stick_vector.x, &stick_moved_x, &navigate_right, &navigate_left);
        updateStickAxis(stick_vector.y, &stick_moved_y, &navigate_down, &navigate_up);

        select_pressed = select_pressed or lm.gamepad.getButtonDown(0, .right_face_down);
    }

    if (selected_index < card_count) {
        if (navigate_left) {
            selected_index = findNextAvailableIndex(selected_index, -1, slot_array);
        }
        if (navigate_right) {
            selected_index = findNextAvailableIndex(selected_index, 1, slot_array);
        }
        if (navigate_down) {
            selected_index = close_index;
        }
    } else {
        if (navigate_up or navigate_left or navigate_right) {
            selected_index = findFirstAvailableIndex(slot_array);
        }
    }

    if (!select_pressed) return;

    if (selected_index < card_count) {
        selectBoon(selected_index, stats, attack);
        return;
    }

    hide();
}

fn renderMenuHeader(ui_scale: f32) void {
    ui.new(.{
        .id = .ID("boon-menu-header"),
        .layout = .{
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = lm.tou16(@round(4 * ui_scale)),
        },
    })({
        const room_category = RoomManager.getRoomCategory();
        const maybe_category = BoonCategory.getCategoryById(room_category);
        const header_title = if (maybe_category) |category| category.name else "CHOOSE A BOON";
        const header_subtitle = if (maybe_category) |category| category.description else "Select an upgrade to enhance your abilities";

        ui.text(header_title, .{
            .color = ui.color(255, 215, 100, 255),
            .letter_spacing = lm.tou16(@round(3 * ui_scale)),
            .font_size = lm.tou16(@round(22 * ui_scale)),
            .alignment = .center,
        });
        ui.text(header_subtitle, .{
            .color = ui.color(150, 155, 170, 255),
            .letter_spacing = lm.tou16(@round(1 * ui_scale)),
            .font_size = lm.tou16(@round(12 * ui_scale)),
            .alignment = .center,
        });
    });
}

fn renderCardSlot(
    slot: BoonSlot,
    slot_index: usize,
    card_width_pixels: f32,
    card_height_pixels: f32,
    stats: ?*Stats,
    attack: ?*Attack,
    allocator: ?std.mem.Allocator,
) void {
    const card_index = lm.tou32(slot_index);
    if (slot.is_purchased) {
        dummyBoonCard(slot.boon, card_index, card_width_pixels, card_height_pixels);
        return;
    }
    boonCard(slot.boon, card_index, card_width_pixels, card_height_pixels, stats, attack, allocator);
}

fn renderCardRow(
    slot_array: []const BoonSlot,
    card_width_pixels: f32,
    card_height_pixels: f32,
    card_gap_pixels: u16,
    total_cards_width_pixels: f32,
    stats: ?*Stats,
    attack: ?*Attack,
    allocator: ?std.mem.Allocator,
) void {
    ui.new(.{
        .id = .ID("boon-cards-row"),
        .layout = .{
            .direction = .left_to_right,
            .sizing = .{
                .w = .fixed(total_cards_width_pixels),
                .h = .fixed(card_height_pixels),
            },
            .child_alignment = .{ .x = .center, .y = .center },
            .child_gap = card_gap_pixels,
        },
    })({
        for (slot_array, 0..) |slot, slot_index| {
            renderCardSlot(slot, slot_index, card_width_pixels, card_height_pixels, stats, attack, allocator);
        }
    });
}

fn renderCloseButton(ui_scale: f32, close_index: usize) void {
    const is_close_focused = (selected_index == close_index);
    const button_width_pixels = @round(HUD.UTILITY_BUTTON_BASE_W * ui_scale);
    const button_height_pixels = @round(HUD.UTILITY_BUTTON_BASE_H * ui_scale);

    lm.deps.clay.UI()(.{
        .id = .ID("boon-close-button"),
        .layout = .{
            .sizing = .{
                .w = .fixed(button_width_pixels),
                .h = .fixed(button_height_pixels),
            },
            .child_alignment = .{ .x = .center, .y = .center },
        },
        .image = ui.image(
            HUD.getUtilityButtonSprite(lm.deps.clay.hovered() or is_close_focused),
            .init(button_width_pixels, button_height_pixels),
        ) catch .{ .image_data = null },
    })({
        if (lm.deps.clay.hovered()) {
            selected_index = close_index;
        }
        if (lm.deps.clay.hovered() and lm.mouse.getButtonDown(.left)) {
            hide();
        }

        const close_label = if (DevicePrompts.isGamepad()) "B  CLOSE" else "ESC  CLOSE";
        ui.text(close_label, .{
            .color = if (lm.deps.clay.hovered() or is_close_focused) ui.color(255, 255, 255, 255) else ui.color(220, 225, 235, 255),
            .letter_spacing = 1,
            .font_size = lm.tou16(@max(9, @round(11 * ui_scale))),
            .alignment = .center,
        });
    });
}

fn renderFooter(ui_scale: f32) void {
    lm.deps.clay.UI()(.{
        .id = .ID("boon-footer-spacer"),
        .layout = .{ .sizing = .{ .h = .fixed(@round(8 * ui_scale)), .w = .fixed(1) } },
    })({});

    lm.deps.clay.UI()(.{
        .id = .ID("boon-footer-container"),
        .layout = .{ .child_alignment = .{ .x = .center } },
    })({
        const navigation_hint = if (DevicePrompts.isGamepad())
            "Navigate: D-Pad / L-Stick  |  Select: A  |  Close: B"
        else
            "Navigate: WASD / Arrows / Click  |  Select: Enter / Click  |  Close: Esc";

        ui.text(navigation_hint, .{
            .color = ui.color(140, 150, 175, 200),
            .font_size = lm.tou16(@max(9, @round(11 * ui_scale))),
            .letter_spacing = 1,
            .alignment = .center,
        });
    });
}

pub fn draw(
    slot_array: []const BoonSlot,
    stats: ?*Stats,
    attack: ?*Attack,
    allocator: ?std.mem.Allocator,
) void {
    if (slots == null) return;
    DevicePrompts.update();

    handleInputNavigation(slot_array, stats, attack);
    if (!isShowing()) return;

    const ui_scale = HUD.ui_scale;
    const card_width_pixels = calculateCardWidthPixels(ui_scale);
    const card_height_pixels = calculateCardHeightPixels(ui_scale);

    const card_gap_pixels = lm.tou16(@round(16 * ui_scale));
    const container_padding_x_pixels = lm.tou16(@round(24 * ui_scale));
    const container_padding_y_pixels = lm.tou16(@round(20 * ui_scale));
    const container_gap_pixels = lm.tou16(@round(14 * ui_scale));

    const card_count_float: f32 = @floatFromInt(slot_array.len);
    const total_cards_width_pixels = (card_count_float * card_width_pixels) + (@max(0.0, card_count_float - 1.0) * @as(f32, @floatFromInt(card_gap_pixels)));
    const container_width_pixels = total_cards_width_pixels + @as(f32, @floatFromInt(container_padding_x_pixels * 2));
    const close_index = slot_array.len;

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
                .w = .fixed(container_width_pixels),
                .h = .fit,
            },
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = container_gap_pixels,
            .padding = .axes(container_padding_y_pixels, container_padding_x_pixels),
        },
        .background_color = ui.color(18, 20, 26, 235),
        .corner_radius = .all(14 * ui_scale),
        .border = .{
            .color = ui.color(55, 60, 75, 180),
            .width = .outside(1),
        },
    })({
        renderMenuHeader(ui_scale);
        renderCardRow(slot_array, card_width_pixels, card_height_pixels, card_gap_pixels, total_cards_width_pixels, stats, attack, allocator);
        renderCloseButton(ui_scale, close_index);
        renderFooter(ui_scale);
    });
}

test "BoonMenu findFirstAvailableIndex returns first unpurchased card or close index" {
    const dummy_boon = Boon{
        .id = "test_boon",
        .name = "Test",
        .description = "Test desc",
        .icon = "",
        .rarity = .normal,
        .boon_type = .stat,
        .callback = struct {
            fn callback(_: *Stats, _: ?*Attack) void {}
        }.callback,
    };

    var test_slots = [_]BoonSlot{
        .{ .boon = dummy_boon, .is_purchased = true },
        .{ .boon = dummy_boon, .is_purchased = false },
        .{ .boon = dummy_boon, .is_purchased = true },
    };

    try std.testing.expectEqual(@as(usize, 1), findFirstAvailableIndex(&test_slots));

    test_slots[1].is_purchased = true;
    try std.testing.expectEqual(@as(usize, 3), findFirstAvailableIndex(&test_slots));
}

test "BoonMenu findNextAvailableIndex skips purchased dummy cards" {
    const dummy_boon = Boon{
        .id = "test_boon",
        .name = "Test",
        .description = "Test desc",
        .icon = "",
        .rarity = .normal,
        .boon_type = .stat,
        .callback = struct {
            fn callback(_: *Stats, _: ?*Attack) void {}
        }.callback,
    };

    const test_slots = [_]BoonSlot{
        .{ .boon = dummy_boon, .is_purchased = false },
        .{ .boon = dummy_boon, .is_purchased = true },
        .{ .boon = dummy_boon, .is_purchased = false },
    };

    try std.testing.expectEqual(@as(usize, 2), findNextAvailableIndex(0, 1, &test_slots));
    try std.testing.expectEqual(@as(usize, 0), findNextAvailableIndex(2, -1, &test_slots));
    try std.testing.expectEqual(@as(usize, 0), findNextAvailableIndex(2, 1, &test_slots));
}

test "BoonMenu show and hide lifecycle" {
    const dummy_boon = Boon{
        .id = "test_boon",
        .name = "Test",
        .description = "Test desc",
        .icon = "",
        .rarity = .normal,
        .boon_type = .stat,
        .callback = struct {
            fn callback(_: *Stats, _: ?*Attack) void {}
        }.callback,
    };

    const test_slots = [_]BoonSlot{
        .{ .boon = dummy_boon, .is_purchased = false },
    };

    show(&test_slots);
    try std.testing.expect(isShowing());
    try std.testing.expectEqual(@as(usize, 0), selected_index);

    hide();
    try std.testing.expect(!isShowing());
}

test "BoonMenu card dimensions maintain fixed 9:14 aspect ratio and 288x448 at scale 1" {
    const scale: f32 = 1.0;
    const width_pixels = calculateCardWidthPixels(scale);
    const height_pixels = calculateCardHeightPixels(scale);

    try std.testing.expectEqual(@as(f32, 288.0), width_pixels);
    try std.testing.expectEqual(@as(f32, 448.0), height_pixels);
    try std.testing.expectApproxEqAbs(CARD_ASPECT_RATIO, width_pixels / height_pixels, 0.0001);
}

test "BoonMenu getBoonCardSprite selects regular and hovered sprites" {
    try std.testing.expectEqualStrings(BOON_CARD_SPRITE, getBoonCardSprite(false));
    try std.testing.expectEqualStrings(BOON_CARD_HOVER_SPRITE, getBoonCardSprite(true));
}
