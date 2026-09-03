const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const Stats = @import("../components/Stats.zig");
const Objectives = @import("../components/player/Objectives.zig");
const Attack = @import("../components/player/Attack.zig");

const Boon = @import("boons/Boon.zig");

const Self = @This();

player: ?*lm.Entity = null,
player_stats: ?*Stats = null,
player_objectives: ?*Objectives = null,
player_attack: ?*Attack = null,

experience_count_string: ?[]u8 = null,
arena: ?std.heap.ArenaAllocator = null,
alloc: ?std.mem.Allocator = null,

pub fn Awake(self: *Self) void {
    self.player = null;
    self.player_stats = null;
    self.player_objectives = null;

    self.arena = .init(lm.allocators.generic());
    self.alloc = self.arena.?.allocator();
}

pub fn Update(self: *Self, scene: *lm.Scene) !void {
    if (self.arena) |*arena| _ = arena.reset(.free_all);

    if (self.player == null or self.player_stats == null or self.player_objectives == null) {
        const player = scene.getEntityById("player") orelse {
            self.player = null;
            self.player_stats = null;
            self.player_objectives = null;
            return;
        };

        self.player = player;
        self.player_stats = player.getComponentUnsafe(Stats).result;
        self.player_objectives = player.getComponent(Objectives);
        self.player_attack = player.getComponent(Attack);
    }

    const window_size = lm.window.size.get();
    const scaler = @max(1, @round(@min(window_size.x, window_size.y) / 540));
    playerStats.hud_height = scaler * 32;
    playerStats.scale = scaler;

    playerStats.draw(self);
    self.objectiveUI();

    boonMenu.draw(self, window_size);
}

pub fn End(self: *Self) void {
    if (self.experience_count_string) |str| lm.allocators.generic().free(str);
    boonMenu.boons = null;
}

pub fn showBoons(boons: []const Boon) void {
    boonMenu.boons = boons;
    boonMenu.selected_index = 0;
}

fn objectiveUI(self: *Self) void {
    const objectives = self.player_objectives orelse return;
    const tracking = objectives.trackingObjective() orelse return;

    const window_size = lm.window.size.get();

    ui.new(.{
        .id = .ID("objective-container"),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{ .x = 0, .y = window_size.y * 0.3 },
            .attach_points = .{
                .element = .right_top,
                .parent = .right_top,
            },
        },
        .background_color = ui.color(50, 50, 50, 128),
        .layout = .{
            .direction = .top_to_bottom,
            .child_gap = 5,
            .padding = .all(10),
        },
    })({
        ui.new(.{
            .id = .ID("name"),
        })({
            ui.text(tracking.name, .{
                .color = ui.color(255, 255, 255, 255),
                .font_size = 32,
                .letter_spacing = 1,
            });
        });
        ui.new(.{
            .id = .ID("desc"),
        })({
            ui.text(tracking.description, .{
                .color = ui.color(255, 255, 255, 255),
                .font_size = 16,
                .letter_spacing = 1,
            });
        });
    });
}

const boonMenu = struct {
    pub var boons: ?[]const Boon = null;
    pub var selected_index: usize = 0;
    var stick_moved_x: bool = false;
    var stick_moved_y: bool = false;

    fn selectBoon(self: *Self, boon: Boon) void {
        const stats = self.player_stats orelse return;
        const cost = boon.cost();
        if (stats.current.experience >= cost) {
            stats.current.experience -= cost;
            boon.applyTo(stats, self.player_attack);
            boons = null;
        }
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

    fn boonCard(self: *Self, boon: Boon, index: u32, card_w: f32, ui_scale: f32) void {
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
                    selectBoon(self, boon);
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
                const price_text = if (self.alloc) |alloc| std.fmt.allocPrint(alloc, "{d}", .{boon.cost()}) catch "0" else "0";

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

    fn draw(self: *Self, window_size: lm.Vector2) void {
        const boon_array = boons orelse return;
        if (boon_array.len == 0) return;

        const num_cards = boon_array.len;
        const skip_index = num_cards;
        if (selected_index > skip_index) selected_index = 0;

        // Handle Gamepad 0 inputs
        if (lm.gamepad.isAvailable(0)) {
            // Quick cancel/skip with B button
            if (lm.gamepad.getButtonDown(0, .right_face_right)) {
                boons = null;
                return;
            }

            // Analog stick navigation with hysteresis
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

            // Directional selection updates
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

            // Confirm selection with A button
            if (lm.gamepad.getButtonDown(0, .right_face_down)) {
                if (selected_index < num_cards) {
                    selectBoon(self, boon_array[selected_index]);
                    if (boons == null) return;
                } else {
                    boons = null;
                    return;
                }
            }
        }

        const scale_x = window_size.x / 1280.0;
        const scale_y = window_size.y / 720.0;
        const base_scale = @min(scale_x, scale_y);
        const ui_scale = @max(0.65, @min(2.5, base_scale));

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
                    boonCard(self, boon, lm.tou32(index), card_w, ui_scale);
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
                        boons = null;
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
};

const playerStats = struct {
    var index: u32 = 0;
    pub var hud_height: f32 = 64;
    pub var scale: f32 = 1;

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

    fn spellShower(img: ?[]const u8) void {
        ui.new(.{
            .id = .IDI("spell-", index),
            .image = ui.image(
                if (img) |spell| spell else "backgrounds/neunyx32x32.png",
                .init(hud_height, hud_height),
            ) catch .{ .image_data = null },
            .layout = .{
                .sizing = .{
                    .h = .fixed(hud_height),
                    .w = .fixed(hud_height),
                },
            },
        })({});
    }

    pub fn draw(self: *Self) void {
        const stats: *Stats = self.player_stats orelse return;
        const attack: *Attack = self.player_attack orelse return;
        const hud_width: f32 = hud_height * 8;

        ui.new(.{
            .id = .ID("experience-counter"),
            .background_color = ui.color(50, 50, 50, 128),
            .floating = .{
                .attach_to = .to_root,
                .attach_points = .{
                    .element = .right_bottom,
                    .parent = .right_bottom,
                },
                .offset = .{ .x = -1 * hud_height / 2, .y = -1.5 * hud_height / 2 },
            },
            .layout = .{
                .padding = .axes(5, 10),
                .child_gap = lm.tou16(10),
                .direction = .left_to_right,
            },
        })({
            if (self.experience_count_string) |str| string_alloc: {
                const new_string = std.fmt.allocPrint(lm.allocators.generic(), "{d}", .{stats.current.experience}) catch break :string_alloc;

                lm.allocators.generic().free(str);
                self.experience_count_string = new_string;
            } else {
                self.experience_count_string = std.fmt.allocPrint(lm.allocators.generic(), "{d}", .{stats.current.experience}) catch null;
            }

            ui.new(.{
                .id = .ID("experience-img"),
                .layout = .{
                    .sizing = .{
                        .h = .fixed(hud_height / 2),
                        .w = .fixed(hud_height / 2),
                    },
                },
                .image = ui.image(
                    "ui/sleep_icon.png",
                    .init(hud_height, hud_height),
                ) catch .{ .image_data = null },
            })({});

            if (self.experience_count_string) |str|
                ui.text(str, .{
                    .font_size = lm.tou16(hud_height / 2),
                    .letter_spacing = 2,
                    .color = ui.color(255, 255, 255, 255),
                })
            else
                ui.text("0", .{
                    .font_size = lm.tou16(hud_height / 2),
                    .letter_spacing = 2,
                    .color = ui.color(255, 255, 255, 255),
                });
        });

        ui.new(.{
            .id = .ID("player-hud"),
            .floating = .{
                .attach_to = .to_root,
                .attach_points = .{ .element = .center_bottom, .parent = .center_bottom },
                .offset = .{ .x = 0, .y = -1 * hud_height / 2 },
            },
            .layout = .{
                .child_gap = 5,
                .padding = .all(5),
                .direction = .left_to_right,
            },
        })({
            spellShower(if (attack.equipped_spells[0]) |spell| spell.icon else null);
            ui.new(.{
                .id = .ID("player-hud-progress-bars"),
                .layout = .{
                    .sizing = .{ .h = .fixed(hud_height), .w = .fixed(hud_width) },
                    .direction = .top_to_bottom,
                    .child_gap = 5,
                    .padding = .axes(lm.tou16(scale * 6), lm.tou16(scale * 6)),
                },
                .background_color = ui.color(50, 50, 50, 255),
                .image = ui.image("ui/HUD/background.png", .init(hud_width, hud_height)) catch .{ .image_data = null },
            })({
                progressBar(
                    stats.current.health,
                    stats.max.health,
                    .init(50, 50, 50, 255),
                    .init(220, 20, 120, 255),
                    0.4,
                );
                progressBar(
                    stats.current.mana,
                    stats.max.mana,
                    .init(50, 50, 50, 255),
                    .init(20, 120, 220, 255),
                    0.4,
                );
                progressBar(
                    stats.current.stamina,
                    stats.max.stamina,
                    .init(50, 50, 50, 255),
                    .init(220, 220, 220, 255),
                    0.2,
                );
            });
            spellShower(if (attack.equipped_spells[1]) |spell| spell.icon else null);
        });
    }
};
