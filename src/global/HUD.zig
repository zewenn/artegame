const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const Stats = @import("../components/Stats.zig");
const Objectives = @import("../components/player/Objectives.zig");
const Attack = @import("../components/player/Attack.zig");
const Self = @This();

player: ?*lm.Entity = null,
player_stats: ?*Stats = null,
player_objectives: ?*Objectives = null,
player_attack: ?*Attack = null,

experience_count_string: ?[]u8 = null,

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

pub fn Awake(self: *Self) void {
    self.player = null;
    self.player_stats = null;
    self.player_objectives = null;
}

pub fn Update(self: *Self, scene: *lm.Scene) !void {
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
}

pub fn End(self: *Self) void {
    if (self.experience_count_string) |str| lm.allocators.generic().free(str);
}
