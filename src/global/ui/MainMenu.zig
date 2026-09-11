const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;
const clay = lm.deps.clay;

const AudioManager = @import("../audio/AudioManager.zig");
const OptionsMenu = @import("OptionsMenu.zig");
const SaveSystem = @import("../save/SaveSystem.zig");
const RoomManager = @import("../RoomManager.zig");
const InputHelper = @import("../input/InputHelper.zig");
const HUD = @import("../HUD.zig");

const Self = @This();

pub const Screen = enum {
    main,
    options,
};

// Global Behaviour fields
arena: ?std.heap.ArenaAllocator = null,
alloc: ?std.mem.Allocator = null,

screen: Screen = .main,

selected_index: usize = 0,
prev_selected_index: usize = 0,

pub fn Awake(self: *Self) void {
    self.screen = .main;
    self.selected_index = 0;
    self.prev_selected_index = 0;

    self.arena = .init(lm.allocators.generic());
    self.alloc = self.arena.?.allocator();
}

pub fn Start(self: *Self) void {
    _ = self;
}

pub fn Update(self: *Self) !void {
    InputHelper.update();
    if (self.arena) |*arena| _ = arena.reset(.free_all);

    const window_size = lm.window.size.get();
    const ui_scale = HUD.calculateUiScale(window_size);

    if (self.screen == .main) {
        self.handleInput();
    }

    ui.new(.{
        .id = .ID("main-menu-root"),
        .floating = .{
            .attach_to = .to_root,
            .attach_points = .{
                .element = .left_top,
                .parent = .left_top,
            },
        },
        .layout = .{
            .sizing = .{
                .w = .fixed(window_size.x),
                .h = .fixed(window_size.y),
            },
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center, .y = .center },
            .padding = .all(lm.tou16(@round(24 * ui_scale))),
        },
        .background_color = ui.color(10, 12, 16, 255),
    })({
        switch (self.screen) {
            .main => self.drawMainScreen(ui_scale, window_size),
            .options => {
                if (OptionsMenu.draw(ui_scale, window_size, self.alloc)) {
                    self.screen = .main;
                    self.selected_index = 1;
                    self.prev_selected_index = 1;
                }
            },
        }
    });

    if (self.selected_index != self.prev_selected_index) {
        AudioManager.playSfxPitched("audio/sfx/click.wav", 0.35, 0.1);
        self.prev_selected_index = self.selected_index;
    }
}

pub fn End(self: *Self) void {
    if (self.arena) |*arena| arena.deinit();
    self.arena = null;
    self.alloc = null;
}

// --------------------------------------------------------------------------------------------------
// Main Screen Rendering
// --------------------------------------------------------------------------------------------------

fn drawMainScreen(self: *Self, ui_scale: f32, window_size: lm.Vector2) void {
    _ = window_size;

    const logo_base_height = 240;

    const logo_w = @round((logo_base_height * 3) * ui_scale);
    const logo_h = @round(logo_base_height * ui_scale);
    const button_w = @round(HUD.MENU_BUTTON_BASE_W * ui_scale);
    const button_h = @round(HUD.MENU_BUTTON_BASE_H * ui_scale);
    const button_gap = lm.tou16(@round(14 * ui_scale));
    const font_size = lm.tou16(@max(14, @round(16 * ui_scale)));
    const letter_spacing = lm.tou16(@max(2, @round(3 * ui_scale)));

    ui.new(.{
        .id = .ID("menu-logo-container"),
        .layout = .{
            .sizing = .{
                .w = .fixed(logo_w),
                .h = .fixed(logo_h),
            },
            .child_alignment = .{ .x = .center, .y = .center },
        },
    })({
        ui.new(.{
            .id = .ID("menu-logo-img"),
            .layout = .{
                .sizing = .{
                    .w = .fixed(logo_w),
                    .h = .fixed(logo_h),
                },
            },
            .image = ui.image(
                "ui/branding/artegame_reimagined_logo.png",
                .init(logo_w, logo_h),
            ) catch .{ .image_data = null },
        })({});
    });

    ui.new(.{
        .id = .ID("menu-subtitle-badge"),
        .layout = .{
            .padding = .axes(
                lm.tou16(@round(4 * ui_scale)),
                lm.tou16(@round(14 * ui_scale)),
            ),
            .child_alignment = .{ .x = .center, .y = .center },
        },
        .background_color = ui.color(20, 24, 32, 200),
        .corner_radius = .all(6 * ui_scale),
        .border = .{
            .color = ui.color(240, 200, 100, 120),
            .width = .outside(1),
        },
    })({
        ui.text("ACTION ROGUELIKE", .{
            .color = ui.color(240, 200, 100, 220),
            .font_size = lm.tou16(@max(10, @round(11 * ui_scale))),
            .letter_spacing = 2,
            .alignment = .center,
        });
    });

    const scores = SaveSystem.getScores();
    if (scores.total_runs_played > 0) {
        const stats_str = if (self.alloc) |a|
            std.fmt.allocPrint(
                a,
                "HIGH SCORE: {d} XP  |  BEST ROUND: {d}  |  TOTAL KILLS: {d}",
                .{ scores.high_score, scores.highest_round, scores.total_enemies_killed },
            ) catch "HIGH SCORE: 0 XP"
        else
            "HIGH SCORE: 0 XP";

        ui.new(.{
            .id = .ID("menu-stats-badge-spacer"),
            .layout = .{ .sizing = .{ .h = .fixed(@round(8 * ui_scale)), .w = .fixed(1) } },
        })({});

        ui.new(.{
            .id = .ID("menu-stats-badge"),
            .layout = .{
                .padding = .axes(
                    lm.tou16(@round(3 * ui_scale)),
                    lm.tou16(@round(14 * ui_scale)),
                ),
                .child_alignment = .{ .x = .center, .y = .center },
            },
            .background_color = ui.color(16, 20, 28, 220),
            .corner_radius = .all(6 * ui_scale),
            .border = .{
                .color = ui.color(100, 200, 255, 120),
                .width = .outside(1),
            },
        })({
            ui.text(stats_str, .{
                .color = ui.color(140, 215, 255, 230),
                .font_size = lm.tou16(@max(9, @round(10 * ui_scale))),
                .letter_spacing = 1,
                .alignment = .center,
            });
        });
    }

    ui.new(.{
        .id = .ID("menu-main-spacer"),
        .layout = .{
            .sizing = .{ .h = .fixed(@round(24 * ui_scale)), .w = .fixed(1) },
        },
    })({});

    ui.new(.{
        .id = .ID("menu-button-list"),
        .layout = .{
            .direction = .top_to_bottom,
            .child_gap = button_gap,
            .child_alignment = .{ .x = .center },
        },
    })({
        if (SaveSystem.hasActiveRun()) {
            self.drawMenuButton(
                0,
                "CONTINUE",
                button_w,
                button_h,
                ui_scale,
                font_size,
                letter_spacing,
                true,
            );

            self.drawMenuButton(
                1,
                "NEW RUN",
                button_w,
                button_h,
                ui_scale,
                font_size,
                letter_spacing,
                false,
            );

            self.drawMenuButton(
                2,
                "OPTIONS",
                button_w,
                button_h,
                ui_scale,
                font_size,
                letter_spacing,
                false,
            );

            self.drawMenuButton(
                3,
                "QUIT",
                button_w,
                button_h,
                ui_scale,
                font_size,
                letter_spacing,
                false,
            );
        } else {
            self.drawMenuButton(
                0,
                "PLAY",
                button_w,
                button_h,
                ui_scale,
                font_size,
                letter_spacing,
                true,
            );

            self.drawMenuButton(
                1,
                "OPTIONS",
                button_w,
                button_h,
                ui_scale,
                font_size,
                letter_spacing,
                false,
            );

            self.drawMenuButton(
                2,
                "QUIT",
                button_w,
                button_h,
                ui_scale,
                font_size,
                letter_spacing,
                false,
            );
        }
    });

    ui.new(.{
        .id = .ID("menu-footer-spacer"),
        .layout = .{
            .sizing = .{ .h = .fixed(@round(24 * ui_scale)), .w = .fixed(1) },
        },
    })({});

    ui.new(.{
        .id = .ID("menu-footer-container"),
        .layout = .{
            .child_alignment = .{ .x = .center },
        },
    })({
        const footer_text = if (InputHelper.isGamepad())
            "Navigate: D-Pad / L-Stick  |  Select: A"
        else
            "Navigate: WASD / Arrows  |  Select: Enter / Space / Click";

        ui.text(footer_text, .{
            .color = ui.color(140, 150, 175, 220),
            .font_size = lm.tou16(@max(10, @round(12 * ui_scale))),
            .letter_spacing = 1,
            .alignment = .center,
        });
    });
}

fn drawMenuButton(
    self: *Self,
    index: usize,
    caption: []const u8,
    w: f32,
    h: f32,
    ui_scale: f32,
    font_size: u16,
    letter_spacing: u16,
    is_primary: bool,
) void {
    const is_selected = (self.selected_index == index);

    _ = ui_scale;
    clay.UI()(.{
        .id = .IDI("menu-btn-", @intCast(index)),
        .layout = .{
            .sizing = .{
                .w = .fixed(w),
                .h = .fixed(h),
            },
            .child_alignment = .{ .x = .center, .y = .center },
        },
        .image = ui.image(HUD.getMenuButtonSprite(clay.hovered() or is_selected), .init(w, h)) catch .{ .image_data = null },
    })({
        if (clay.hovered()) {
            self.selected_index = index;
            if (lm.mouse.getButtonDown(.left)) {
                self.activateAction(index);
            }
        }

        ui.text(caption, .{
            .color = if (clay.hovered() or is_selected)
                ui.color(255, 255, 255, 255)
            else if (is_primary)
                ui.color(255, 235, 170, 255)
            else
                ui.color(200, 205, 220, 255),
            .font_size = font_size,
            .letter_spacing = letter_spacing,
            .alignment = .center,
        });
    });
}

// --------------------------------------------------------------------------------------------------
// Input & Actions
// --------------------------------------------------------------------------------------------------

fn handleInput(self: *Self) void {
    var nav_up = lm.keyboard.getKeyDown(.up) or lm.keyboard.getKeyDown(.w);
    var nav_down = lm.keyboard.getKeyDown(.down) or lm.keyboard.getKeyDown(.s);
    var select_pressed = lm.keyboard.getKeyDown(.enter) or lm.keyboard.getKeyDown(.space);

    if (lm.gamepad.isAvailable(0)) {
        nav_up = nav_up or lm.gamepad.getButtonDown(0, .left_face_up);
        nav_down = nav_down or lm.gamepad.getButtonDown(0, .left_face_down);
        select_pressed = select_pressed or lm.gamepad.getButtonDown(0, .right_face_down);

        const stick = lm.gamepad.getStickVector(0, .left, 0.25);
        if (stick.y < -0.5) nav_up = true;
        if (stick.y > 0.5) nav_down = true;
    }

    const max_index: usize = if (SaveSystem.hasActiveRun()) 3 else 2;
    if (nav_up) {
        if (self.selected_index == 0) self.selected_index = max_index else self.selected_index -= 1;
    }
    if (nav_down) {
        if (self.selected_index >= max_index) self.selected_index = 0 else self.selected_index += 1;
    }
    if (select_pressed) {
        self.activateAction(self.selected_index);
    }
}

fn activateAction(self: *Self, index: usize) void {
    if (SaveSystem.hasActiveRun()) {
        switch (index) {
            0 => {
                AudioManager.playSfxPitched("audio/sfx/coin.wav", 0.9, 0.05);
                RoomManager.resume_saved_run = true;
                lm.loadScene("demo_map") catch |err| {
                    std.log.err("Failed to load demo_map scene: {any}", .{err});
                };
            },
            1 => {
                SaveSystem.clearRun();
                RoomManager.resume_saved_run = false;
                AudioManager.playSfxPitched("audio/sfx/coin.wav", 0.9, 0.05);
                lm.loadScene("demo_map") catch |err| {
                    std.log.err("Failed to load demo_map scene: {any}", .{err});
                };
            },
            2 => {
                AudioManager.playSfxPitched("audio/sfx/click.wav", 0.6, 0.0);
                OptionsMenu.reset();
                self.screen = .options;
            },
            3 => {
                AudioManager.playSfxPitched("audio/sfx/click.wav", 0.6, 0.0);
                lm.quit();
            },
            else => {},
        }
    } else {
        switch (index) {
            0 => {
                RoomManager.resume_saved_run = false;
                AudioManager.playSfxPitched("audio/sfx/coin.wav", 0.9, 0.05);
                lm.loadScene("demo_map") catch |err| {
                    std.log.err("Failed to load demo_map scene: {any}", .{err});
                };
            },
            1 => {
                AudioManager.playSfxPitched("audio/sfx/click.wav", 0.6, 0.0);
                OptionsMenu.reset();
                self.screen = .options;
            },
            2 => {
                AudioManager.playSfxPitched("audio/sfx/click.wav", 0.6, 0.0);
                lm.quit();
            },
            else => {},
        }
    }
}

// --------------------------------------------------------------------------------------------------
// Unit Tests
// --------------------------------------------------------------------------------------------------

test "MainMenu navigation index wrapping" {
    var menu = Self{};
    menu.Awake();
    defer menu.End();

    try std.testing.expectEqual(Screen.main, menu.screen);
    try std.testing.expectEqual(@as(usize, 0), menu.selected_index);

    const max_main: usize = 2;
    menu.selected_index = if (menu.selected_index >= max_main) 0 else menu.selected_index + 1;
    try std.testing.expectEqual(@as(usize, 1), menu.selected_index);

    menu.selected_index = if (menu.selected_index >= max_main) 0 else menu.selected_index + 1;
    try std.testing.expectEqual(@as(usize, 2), menu.selected_index);

    menu.selected_index = if (menu.selected_index >= max_main) 0 else menu.selected_index + 1;
    try std.testing.expectEqual(@as(usize, 0), menu.selected_index);

    menu.selected_index = if (menu.selected_index == 0) max_main else menu.selected_index - 1;
    try std.testing.expectEqual(@as(usize, 2), menu.selected_index);
}
