const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const Stats = @import("../../components/Stats.zig");
const Attack = @import("../../components/player/Attack.zig");
const HUD = @import("../HUD.zig");

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

fn spellShower(img: ?[]const u8) void {
    ui.new(.{
        .id = .IDI("spell-", index),
        .image = ui.image(
            if (img) |spell| spell else "backgrounds/neunyx32x32.png",
            .init(HUD.hud_height, HUD.hud_height),
        ) catch .{ .image_data = null },
        .layout = .{
            .sizing = .{
                .h = .fixed(HUD.hud_height),
                .w = .fixed(HUD.hud_height),
            },
        },
    })({});
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
        spellShower(if (attack.equipped_spells[0]) |spell| spell.icon else null);
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
