const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const Boon = @import("../boons/Boon.zig");
const BoonPool = @import("../boons/BoonPool.zig");
const BoonCategory = @import("../boons/BoonCategory.zig");
const theme = @import("theme.zig");
const AudioManager = @import("../audio/AudioManager.zig");
const RoomManager = @import("../RoomManager.zig");
const sprite_button = @import("buttons/sprite_button.zig");
const menu_navigation = @import("menu_navigation.zig");
const color_scheme = @import("color_scheme.zig");

pub const BoonSlot = BoonPool.BoonSlot;

pub const BASE_CARD_WIDTH_PIXELS: f32 = 72.0;
pub const BASE_CARD_HEIGHT_PIXELS: f32 = 112.0;

pub const BOON_CARD_SPRITE: []const u8 = "ui/hud/boon_card.png";
pub const BOON_CARD_HOVER_SPRITE: []const u8 = "ui/hud/boon_card_hovered.png";

pub var slots: ?[]const BoonSlot = null;
pub var navigation: menu_navigation.NavigationState = .{};

pub fn getBoonCardSprite(is_active: bool) []const u8 {
    return if (is_active) BOON_CARD_HOVER_SPRITE else BOON_CARD_SPRITE;
}

pub fn calculateCardWidthPixels(ui_scale: f32) f32 {
    return @round(BASE_CARD_WIDTH_PIXELS * ui_scale);
}

pub fn calculateCardHeightPixels(ui_scale: f32) f32 {
    return @round(BASE_CARD_HEIGHT_PIXELS * ui_scale);
}

pub fn findFirstAvailableIndex(slot_array: []const BoonSlot) usize {
    for (slot_array, 0..) |slot, slot_index| {
        if (!slot.is_purchased) return slot_index;
    }
    return slot_array.len;
}

pub fn findNextAvailableIndex(current_index: usize, direction: i32, slot_array: []const BoonSlot) usize {
    const card_count = slot_array.len;
    if (card_count == 0) return 0;

    const step: isize = if (direction >= 0) 1 else -1;
    const count_isize: isize = @intCast(card_count);
    var offset: isize = 1;
    while (offset <= count_isize) : (offset += 1) {
        const candidate_index: usize = @intCast(@mod(@as(isize, @intCast(current_index)) + step * offset, count_isize));
        if (!slot_array[candidate_index].is_purchased) return candidate_index;
    }
    return card_count;
}

pub fn show(slots_to_show: []const BoonSlot) void {
    slots = slots_to_show;
    navigation.reset(false);
    navigation.selected_index = findFirstAvailableIndex(slots_to_show);
    navigation.previous_selected_index = navigation.selected_index;
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
            navigation.selected_index = findNextAvailableIndex(slot_index, 1, updated_slots);
        }
        return;
    }

    hide();
}

fn renderBoonCostBox(card_index: u32, cost: usize, ui_scale: f32, letter_spacing: u16) void {
    const cost_box_padding_x_pixels = lm.tou16(@round(3.0 * ui_scale));
    const cost_box_padding_y_pixels = lm.tou16(@round(1.25 * ui_scale));
    const cost_image_size_pixels = @round(4.5 * ui_scale);

    ui.new(.{
        .id = .IDI("boon-cost-box-", card_index),
        .background_color = color_scheme.surface_elevated,
        .corner_radius = .all(1.5 * ui_scale),
        .border = .{
            .color = color_scheme.panel_border,
            .width = .outside(1),
        },
        .layout = .{
            .padding = .axes(cost_box_padding_y_pixels, cost_box_padding_x_pixels),
            .child_gap = lm.tou16(@round(1.5 * ui_scale)),
            .child_alignment = .{ .y = .center },
            .direction = .left_to_right,
        },
    })({
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
        ui.textFmt("{d}", .{cost}, .{
            .color = color_scheme.text_bright,
            .letter_spacing = letter_spacing,
            .font_size = theme.scaledU16(3.5, 7, ui_scale),
            .alignment = .center,
            .font_id = theme.regularFontId(),
        });
    });
}

fn renderBoonRarityBadge(rarity: Boon.Rarity, card_index: u32, ui_scale: f32, letter_spacing: u16) void {
    const rarity_icon_size_pixels = @round(4.0 * ui_scale);
    const badge_padding_pixels = lm.tou16(@round(1.0 * ui_scale));
    const badge_gap_pixels = lm.tou16(@round(1.0 * ui_scale));

    ui.new(.{
        .id = .IDI("boon-rarity-", card_index),
        .background_color = color_scheme.badge_rarity_background,
        .corner_radius = .all(1.0 * ui_scale),
        .layout = .{
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .child_gap = badge_gap_pixels,
            .padding = .all(badge_padding_pixels),
        },
    })({
        ui.new(.{
            .id = .IDI("boon-rarity-image-", card_index),
            .layout = .{ .sizing = .{ .h = .fixed(rarity_icon_size_pixels), .w = .fixed(rarity_icon_size_pixels) } },
            .image = ui.image(rarity.spritePath(), .init(rarity_icon_size_pixels, rarity_icon_size_pixels)) catch .{ .image_data = null },
        })({});

        ui.text(rarity.toString(), .{
            .font_size = theme.scaledU16(4.0, 8, ui_scale),
            .letter_spacing = letter_spacing,
            .alignment = .center,
            .color = color_scheme.rarityColor(rarity),
            .font_id = theme.regularFontId(),
        });
    });
}

fn renderPurchasedBadge(card_index: u32, ui_scale: f32) void {
    const badge_padding_x_pixels = lm.tou16(@round(3.5 * ui_scale));
    const badge_padding_y_pixels = lm.tou16(@round(1.5 * ui_scale));

    ui.new(.{
        .id = .IDI("boon-dummy-badge-", card_index),
        .background_color = color_scheme.badge_purchased_background,
        .corner_radius = .all(1.5 * ui_scale),
        .border = .{
            .color = color_scheme.badge_purchased_border,
            .width = .outside(1),
        },
        .layout = .{
            .padding = .axes(badge_padding_y_pixels, badge_padding_x_pixels),
            .child_alignment = .{ .x = .center, .y = .center },
        },
    })({
        ui.text("PURCHASED", .{
            .color = color_scheme.badge_purchased_text,
            .letter_spacing = theme.scaledU16(0.5, 1, ui_scale),
            .font_size = theme.scaledU16(3.0, 6, ui_scale),
            .alignment = .center,
            .font_id = theme.regularFontId(),
        });
    });
}

fn handleCardPointer(
    card_index: u32,
    is_purchased: bool,
    stats: ?*Stats,
    attack: ?*Attack,
) void {
    if (is_purchased or !lm.deps.clay.hovered()) return;
    navigation.selected_index = card_index;
    if (lm.mouse.getButtonDown(.left)) {
        selectBoon(card_index, stats, attack);
    }
}

fn renderCardRarityHeader(boon: Boon, card_index: u32, is_purchased: bool, ui_scale: f32, letter_spacing: u16) void {
    if (!is_purchased) {
        renderBoonRarityBadge(boon.rarity, card_index, ui_scale, letter_spacing);
        return;
    }

    ui.text(boon.rarity.toString(), .{
        .font_size = theme.scaledU16(3.0, 6, ui_scale),
        .letter_spacing = letter_spacing,
        .alignment = .center,
        .color = color_scheme.text_disabled_muted,
        .font_id = theme.regularFontId(),
    });
}

fn renderBoonCard(
    slot: BoonSlot,
    card_index: u32,
    card_width_pixels: f32,
    card_height_pixels: f32,
    ui_scale: f32,
    stats: ?*Stats,
    attack: ?*Attack,
) void {
    const boon = slot.boon;
    const is_purchased = slot.is_purchased;
    const card_padding_scale: f32 = if (is_purchased) 4.0 else 6.0;
    const card_padding_pixels = lm.tou16(@round(card_padding_scale * ui_scale));
    const card_content_gap_pixels = lm.tou16(@round(1.5 * ui_scale));
    const icon_size_pixels = @round(24.0 * ui_scale);
    const letter_spacing = theme.scaledU16(0.5, 1, ui_scale);

    const card_id = lm.deps.clay.ElementId.IDI("boon-card-", card_index);
    const is_hovered = lm.deps.clay.pointerOver(card_id);
    const is_focused = !is_purchased and (navigation.selected_index == card_index);
    const is_active = !is_purchased and (is_hovered or is_focused);

    lm.deps.clay.UI()(.{
        .id = card_id,
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
            getBoonCardSprite(is_active),
            .init(card_width_pixels, card_height_pixels),
        ) catch .{ .image_data = null },
    })({
        handleCardPointer(card_index, is_purchased, stats, attack);
        renderCardRarityHeader(boon, card_index, is_purchased, ui_scale, letter_spacing);

        ui.new(.{
            .id = .IDI("boon-image-", card_index),
            .image = ui.image(boon.icon, .init(icon_size_pixels, icon_size_pixels)) catch .{ .image_data = null },
            .aspect_ratio = .{ .aspect_ratio = 1 },
            .layout = .{
                .sizing = .{ .w = .fixed(icon_size_pixels), .h = .fixed(icon_size_pixels) },
            },
        })({});

        ui.text(boon.boon_type.toString(), .{
            .color = if (is_purchased) color_scheme.text_disabled_subtle else color_scheme.text_subtle,
            .letter_spacing = letter_spacing,
            .font_size = theme.scaledU16(2.75, 5, ui_scale),
            .alignment = .center,
            .font_id = theme.regularFontId(),
        });

        ui.text(boon.name, .{
            .color = if (is_purchased) color_scheme.text_disabled_title else color_scheme.text_bright,
            .letter_spacing = letter_spacing,
            .font_size = theme.scaledU16(4.25, 8, ui_scale),
            .alignment = .center,
            .font_id = theme.boldFontId(),
        });

        ui.text(boon.description, .{
            .color = if (is_purchased) color_scheme.text_disabled_body else color_scheme.text_body,
            .font_size = theme.scaledU16(3.25, 6, ui_scale),
            .alignment = .center,
            .font_id = theme.regularFontId(),
        });

        ui.new(.{
            .id = .IDI("boon-card-spacer-", card_index),
            .layout = .{ .sizing = .{ .h = .grow } },
        })({});

        if (is_purchased) {
            renderPurchasedBadge(card_index, ui_scale);
        } else {
            renderBoonCostBox(card_index, boon.cost(), ui_scale, letter_spacing);
        }
    });
}

fn handleInputNavigation(slot_array: []const BoonSlot, stats: ?*Stats, attack: ?*Attack) void {
    const input = navigation.readMenuInput();
    if (input.back_pressed) {
        hide();
        return;
    }

    const card_count = slot_array.len;
    const close_index = card_count;
    if (navigation.selected_index > close_index) navigation.selected_index = 0;

    applyCardGridNavigation(input, slot_array);

    if (!input.select_pressed) return;
    if (navigation.selected_index < card_count) {
        selectBoon(navigation.selected_index, stats, attack);
        return;
    }
    hide();
}

fn applyCardGridNavigation(input: menu_navigation.MenuInput, slot_array: []const BoonSlot) void {
    const card_count = slot_array.len;
    if (navigation.selected_index < card_count) {
        const move_left = input.navigate_left or input.tab_previous;
        const move_right = input.navigate_right or input.tab_next;
        if (move_left) {
            navigation.selected_index = findNextAvailableIndex(navigation.selected_index, -1, slot_array);
        }
        if (move_right) {
            navigation.selected_index = findNextAvailableIndex(navigation.selected_index, 1, slot_array);
        }
        if (input.navigate_down) {
            navigation.selected_index = card_count;
        }
        return;
    }

    if (input.navigate_up or input.navigate_left or input.navigate_right) {
        navigation.selected_index = findFirstAvailableIndex(slot_array);
    }
}

fn renderMenuHeader(ui_scale: f32) void {
    ui.new(.{
        .id = .ID("boon-menu-header"),
        .layout = .{
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = lm.tou16(@round(1.0 * ui_scale)),
        },
    })({
        const room_category = RoomManager.getRoomCategory();
        const maybe_category = BoonCategory.getCategoryById(room_category);
        const header_title = if (maybe_category) |category| category.name else "CHOOSE A BOON";
        const header_subtitle = if (maybe_category) |category| category.description else "Select an upgrade to enhance your abilities";

        ui.text(header_title, .{
            .color = color_scheme.accent_gold_bright,
            .letter_spacing = theme.scaledU16(0.75, 1, ui_scale),
            .font_size = theme.scaledU16(5.5, 11, ui_scale),
            .alignment = .center,
            .font_id = theme.boldFontId(),
        });
        ui.text(header_subtitle, .{
            .color = color_scheme.text_subtle,
            .letter_spacing = theme.scaledU16(0.25, 1, ui_scale),
            .font_size = theme.scaledU16(3.0, 6, ui_scale),
            .alignment = .center,
            .font_id = theme.regularFontId(),
        });
    });
}

fn renderCardRow(
    slot_array: []const BoonSlot,
    card_width_pixels: f32,
    card_height_pixels: f32,
    card_gap_pixels: u16,
    total_cards_width_pixels: f32,
    ui_scale: f32,
    stats: ?*Stats,
    attack: ?*Attack,
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
            renderBoonCard(slot, lm.tou32(slot_index), card_width_pixels, card_height_pixels, ui_scale, stats, attack);
        }
    });
}

fn renderCloseButton(ui_scale: f32, close_index: usize) void {
    sprite_button.draw(
        .utility,
        close_index,
        "CLOSE",
        &navigation.selected_index,
        activateCloseButton,
        ui_scale,
        .{ .font_size_override = theme.scaledU16(2.75, 5, ui_scale) },
    );
}

fn activateCloseButton(_: usize) void {
    hide();
}

fn renderFooter(ui_scale: f32) void {
    lm.deps.clay.UI()(.{
        .id = .ID("boon-footer-spacer"),
        .layout = .{ .sizing = .{ .h = .fixed(@round(2.0 * ui_scale)), .w = .fixed(1) } },
    })({});

    menu_navigation.drawFooterHint(
        "boon-footer-container",
        "Navigate: D-Pad / L-Stick | Select: A | Close: B",
        "Navigate: WASD / Arrows / Click | Select: Enter / Click | Close: Esc",
        ui_scale,
    );
}

pub fn draw(slot_array: []const BoonSlot, stats: ?*Stats, attack: ?*Attack) void {
    if (slots == null) return;

    handleInputNavigation(slot_array, stats, attack);
    if (!isShowing()) return;

    const ui_scale = theme.calculateUiScale(lm.window.size.get());
    const card_width_pixels = calculateCardWidthPixels(ui_scale);
    const card_height_pixels = calculateCardHeightPixels(ui_scale);

    const card_gap_pixels = lm.tou16(@round(4.0 * ui_scale));
    const container_padding_x_pixels = lm.tou16(@round(6.0 * ui_scale));
    const container_padding_y_pixels = lm.tou16(@round(5.0 * ui_scale));
    const container_gap_pixels = lm.tou16(@round(3.5 * ui_scale));

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
        .background_color = color_scheme.panel_translucent_background,
        .corner_radius = .all(3.5 * ui_scale),
        .border = .{
            .color = color_scheme.panel_subtle_border,
            .width = .outside(1),
        },
    })({
        renderMenuHeader(ui_scale);
        renderCardRow(slot_array, card_width_pixels, card_height_pixels, card_gap_pixels, total_cards_width_pixels, ui_scale, stats, attack);
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
    defer hide();
    try std.testing.expect(isShowing());
    try std.testing.expectEqual(@as(usize, 0), navigation.selected_index);

    hide();
    try std.testing.expect(!isShowing());
}
