const std = @import("std");
const builtin = @import("builtin");
const lm = @import("loom");
const ui = lm.ui;

const AudioManager = @import("../audio/AudioManager.zig");
const OptionsMenu = @import("OptionsMenu.zig");
const SaveSystem = @import("../save/SaveSystem.zig");
const RoomManager = @import("../RoomManager.zig");
const DevicePrompts = @import("../input/DevicePrompts.zig");
const HUD = @import("../HUD.zig");
const menu_button = @import("buttons/menu_button.zig");

const Self = @This();

/// Screen view state for the main menu.
pub const Screen = enum {
    main,
    options,
};

/// Available actions selectable within the main menu.
pub const MenuAction = enum {
    continue_run,
    new_run,
    play,
    tutorial,
    options,
    map_editor,
    quit,

    /// Text caption displayed on the menu button.
    pub fn caption(self: MenuAction) []const u8 {
        return switch (self) {
            .continue_run => "CONTINUE",
            .new_run => "NEW RUN",
            .play => "PLAY",
            .tutorial => "TUTORIAL",
            .options => "OPTIONS",
            .map_editor => "MAP EDITOR",
            .quit => "QUIT",
        };
    }

    /// Whether this action represents a primary game start action.
    pub fn isPrimary(self: MenuAction) bool {
        return self == .continue_run or self == .play;
    }
};

/// Maximum count of concurrent actions shown on the main menu.
pub const MAX_MENU_ACTIONS: usize = 6;

var active_instance: ?*Self = null;

arena: ?std.heap.ArenaAllocator = null,
allocator: ?std.mem.Allocator = null,

screen: Screen = .main,

selected_index: usize = 0,
previous_selected_index: usize = 0,

pub fn Awake(self: *Self) void {
    active_instance = self;
    self.screen = .main;
    self.selected_index = 0;
    self.previous_selected_index = 0;

    self.arena = .init(lm.allocators.generic());
    self.allocator = self.arena.?.allocator();
}

pub fn Start(self: *Self) void {
    _ = self;
}

pub fn Update(self: *Self) !void {
    DevicePrompts.update();
    if (self.arena) |*arena| _ = arena.reset(.free_all);

    const window_size = lm.window.size.get();
    const ui_scale = HUD.calculateUiScale(window_size);

    if (self.screen == .main) {
        self.handleInput();
    }

    self.drawRootContainer(ui_scale, window_size);

    if (self.selected_index != self.previous_selected_index) {
        AudioManager.playSfxPitched("audio/sfx/click.wav", 0.35, 0.1);
        self.previous_selected_index = self.selected_index;
    }
}

pub fn End(self: *Self) void {
    if (self.arena) |*arena| arena.deinit();
    self.arena = null;
    self.allocator = null;
    if (active_instance == self) {
        active_instance = null;
    }
}

/// Activates the available menu action at the given button index on the active MainMenu instance.
pub fn activateActionAtIndex(index: usize) void {
    const self = active_instance orelse return;
    var action_buffer: [MAX_MENU_ACTIONS]MenuAction = undefined;
    const actions = getAvailableActions(&action_buffer);
    if (index >= actions.len) return;
    self.activateAction(actions[index]);
}

/// Returns currently available menu actions according to save state and build mode.
pub fn getAvailableActions(buffer: *[MAX_MENU_ACTIONS]MenuAction) []const MenuAction {
    var count: usize = 0;
    if (SaveSystem.hasActiveRun()) {
        buffer[count] = .continue_run;
        count += 1;
        buffer[count] = .new_run;
        count += 1;
    } else {
        buffer[count] = .play;
        count += 1;
    }

    if (SaveSystem.isTutorialCompleted()) {
        buffer[count] = .tutorial;
        count += 1;
    }

    buffer[count] = .options;
    count += 1;

    if (builtin.mode == .debug) {
        buffer[count] = .map_editor;
        count += 1;
    }

    buffer[count] = .quit;
    count += 1;

    return buffer[0..count];
}

/// Finds the index of a specific menu action within the currently available actions list.
pub fn findActionIndex(target_action: MenuAction) usize {
    var action_buffer: [MAX_MENU_ACTIONS]MenuAction = undefined;
    const actions = getAvailableActions(&action_buffer);
    for (actions, 0..) |action, action_index| {
        if (action == target_action) return action_index;
    }
    return 0;
}

fn drawRootContainer(self: *Self, ui_scale: f32, window_size: lm.Vector2) void {
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
        self.drawActiveScreen(ui_scale, window_size);
    });
}

fn drawActiveScreen(self: *Self, ui_scale: f32, window_size: lm.Vector2) void {
    switch (self.screen) {
        .main => self.drawMainScreen(ui_scale),
        .options => self.drawOptionsScreen(ui_scale, window_size),
    }
}

fn drawOptionsScreen(self: *Self, ui_scale: f32, window_size: lm.Vector2) void {
    const options_closed = OptionsMenu.draw(ui_scale, window_size, self.allocator);
    if (!options_closed) return;

    self.screen = .main;
    self.selected_index = findActionIndex(.options);
    self.previous_selected_index = self.selected_index;
}

fn drawMainScreen(self: *Self, ui_scale: f32) void {
    drawLogo(ui_scale);
    self.drawStatsBadge(ui_scale);
    drawSpacer("menu-main-spacer", @round(24 * ui_scale));
    self.drawButtonList(ui_scale);
    drawSpacer("menu-footer-spacer", @round(24 * ui_scale));
    drawFooter(ui_scale);
}

fn drawSpacer(comptime id_name: []const u8, height_pixels: f32) void {
    ui.new(.{
        .id = .ID(id_name),
        .layout = .{
            .sizing = .{ .h = .fixed(height_pixels), .w = .fixed(1) },
        },
    })({});
}

fn drawLogo(ui_scale: f32) void {
    const logo_base_height_pixels: f32 = 240;
    const logo_width_pixels = @round((logo_base_height_pixels * 3) * ui_scale);
    const logo_height_pixels = @round(logo_base_height_pixels * ui_scale);

    ui.new(.{
        .id = .ID("menu-logo-container"),
        .layout = .{
            .sizing = .{
                .w = .fixed(logo_width_pixels),
                .h = .fixed(logo_height_pixels),
            },
            .child_alignment = .{ .x = .center, .y = .center },
        },
    })({
        ui.new(.{
            .id = .ID("menu-logo-img"),
            .layout = .{
                .sizing = .{
                    .w = .fixed(logo_width_pixels),
                    .h = .fixed(logo_height_pixels),
                },
            },
            .image = ui.image(
                "ui/branding/amrap_logo_large.png",
                .init(logo_width_pixels, logo_height_pixels),
            ) catch .{ .image_data = null },
        })({});
    });
}

fn drawStatsBadge(self: *Self, ui_scale: f32) void {
    const scores = SaveSystem.getScores();
    if (scores.total_runs_played == 0) return;

    const stats_text = if (self.allocator) |allocator|
        std.fmt.allocPrint(
            allocator,
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
        ui.text(stats_text, .{
            .color = ui.color(140, 215, 255, 230),
            .font_size = lm.tou16(@max(9, @round(10 * ui_scale))),
            .letter_spacing = 1,
            .alignment = .center,
        });
    });
}

fn drawButtonList(self: *Self, ui_scale: f32) void {
    const button_gap_pixels = lm.tou16(@round(14 * ui_scale));
    const font_size = lm.tou16(@max(18, @round(18 * ui_scale)));
    const letter_spacing = lm.tou16(@max(2, @round(1 * ui_scale)));

    ui.new(.{
        .id = .ID("menu-button-list"),
        .layout = .{
            .direction = .top_to_bottom,
            .child_gap = button_gap_pixels,
            .child_alignment = .{ .x = .center },
        },
    })({
        self.renderMenuButtons(font_size, letter_spacing);
    });
}

fn renderMenuButtons(self: *Self, font_size: u16, letter_spacing: u16) void {
    var action_buffer: [MAX_MENU_ACTIONS]MenuAction = undefined;
    const actions = getAvailableActions(&action_buffer);
    for (actions, 0..) |action, action_index| {
        menu_button.draw(
            action_index,
            action.caption(),
            &self.selected_index,
            activateActionAtIndex,
            font_size,
            letter_spacing,
        );
    }
}

fn drawFooter(ui_scale: f32) void {
    ui.new(.{
        .id = .ID("menu-footer-container"),
        .layout = .{
            .child_alignment = .{ .x = .center },
        },
    })({
        const footer_text = if (DevicePrompts.isGamepad())
            "Navigate: D-Pad / L-Stick  |  Select: A"
        else
            "Navigate: WASD / Arrows  |  Select: Enter / Click";

        ui.text(footer_text, .{
            .color = ui.color(140, 150, 175, 220),
            .font_size = lm.tou16(@max(10, @round(12 * ui_scale))),
            .letter_spacing = 1,
            .alignment = .center,
        });
    });
}

fn handleInput(self: *Self) void {
    var action_buffer: [MAX_MENU_ACTIONS]MenuAction = undefined;
    const actions = getAvailableActions(&action_buffer);
    if (actions.len == 0) return;

    const maximum_index: usize = actions.len - 1;

    if (isNavigateUpRequested()) {
        self.selected_index = if (self.selected_index == 0) maximum_index else self.selected_index - 1;
    }
    if (isNavigateDownRequested()) {
        self.selected_index = if (self.selected_index >= maximum_index) 0 else self.selected_index + 1;
    }
    if (isSelectRequested() and self.selected_index < actions.len) {
        self.activateAction(actions[self.selected_index]);
    }
}

fn isNavigateUpRequested() bool {
    var requested = lm.keyboard.getKeyDown(.up) or lm.keyboard.getKeyDown(.w);
    if (!lm.gamepad.isAvailable(0)) return requested;

    requested = requested or lm.gamepad.getButtonDown(0, .left_face_up);
    const stick_vector = lm.gamepad.getStickVector(0, .left, 0.25);
    return requested or (stick_vector.y < -0.5);
}

fn isNavigateDownRequested() bool {
    var requested = lm.keyboard.getKeyDown(.down) or lm.keyboard.getKeyDown(.s);
    if (!lm.gamepad.isAvailable(0)) return requested;

    requested = requested or lm.gamepad.getButtonDown(0, .left_face_down);
    const stick_vector = lm.gamepad.getStickVector(0, .left, 0.25);
    return requested or (stick_vector.y > 0.5);
}

fn isSelectRequested() bool {
    const requested = lm.keyboard.getKeyDown(.enter);
    if (!lm.gamepad.isAvailable(0)) return requested;

    return requested or lm.gamepad.getButtonDown(0, .right_face_down);
}

fn activateAction(self: *Self, action: MenuAction) void {
    switch (action) {
        .continue_run => {
            AudioManager.playSfxPitched("audio/sfx/coin.wav", 0.9, 0.05);
            RoomManager.resume_saved_run = true;
            lm.loadScene("demo_map") catch |load_error| {
                std.log.err("Failed to load demo_map scene: {any}", .{load_error});
            };
        },
        .new_run, .play => {
            SaveSystem.clearRun();
            RoomManager.resume_saved_run = false;
            AudioManager.playSfxPitched("audio/sfx/coin.wav", 0.9, 0.05);
            lm.loadScene("demo_map") catch |load_error| {
                std.log.err("Failed to load demo_map scene: {any}", .{load_error});
            };
        },
        .tutorial => {
            AudioManager.playSfxPitched("audio/sfx/coin.wav", 0.9, 0.05);
            RoomManager.startPracticeTutorial();
            lm.loadScene("demo_map") catch |load_error| {
                std.log.err("Failed to load demo_map scene for practice tutorial: {any}", .{load_error});
            };
        },
        .options => {
            AudioManager.playSfxPitched("audio/sfx/click.wav", 0.6, 0.0);
            OptionsMenu.reset();
            self.screen = .options;
        },
        .map_editor => {
            AudioManager.playSfxPitched("audio/sfx/click.wav", 0.6, 0.0);
            lm.loadScene("map_editor") catch |load_error| {
                std.log.err("Failed to load map_editor scene: {any}", .{load_error});
            };
        },
        .quit => {
            AudioManager.playSfxPitched("audio/sfx/click.wav", 0.6, 0.0);
            lm.quit();
        },
    }
}

test "MainMenu MenuAction captions and primary status" {
    try std.testing.expectEqualStrings("CONTINUE", MenuAction.continue_run.caption());
    try std.testing.expectEqualStrings("NEW RUN", MenuAction.new_run.caption());
    try std.testing.expectEqualStrings("PLAY", MenuAction.play.caption());
    try std.testing.expectEqualStrings("TUTORIAL", MenuAction.tutorial.caption());
    try std.testing.expectEqualStrings("OPTIONS", MenuAction.options.caption());
    try std.testing.expectEqualStrings("MAP EDITOR", MenuAction.map_editor.caption());
    try std.testing.expectEqualStrings("QUIT", MenuAction.quit.caption());

    try std.testing.expect(MenuAction.continue_run.isPrimary());
    try std.testing.expect(MenuAction.play.isPrimary());
    try std.testing.expect(!MenuAction.tutorial.isPrimary());
    try std.testing.expect(!MenuAction.options.isPrimary());
}

test "MainMenu getAvailableActions without active run and incomplete tutorial" {
    SaveSystem.setTutorialCompleted(false);
    defer SaveSystem.setTutorialCompleted(false);

    var buffer: [MAX_MENU_ACTIONS]MenuAction = undefined;
    const actions = getAvailableActions(&buffer);

    try std.testing.expectEqual(MenuAction.play, actions[0]);
    var found_tutorial: bool = false;
    for (actions) |action| {
        if (action == .tutorial) found_tutorial = true;
    }
    try std.testing.expect(!found_tutorial);
}

test "MainMenu getAvailableActions includes tutorial when completed" {
    SaveSystem.setTutorialCompleted(true);
    defer SaveSystem.setTutorialCompleted(false);

    var buffer: [MAX_MENU_ACTIONS]MenuAction = undefined;
    const actions = getAvailableActions(&buffer);

    var found_tutorial: bool = false;
    var tutorial_index: usize = 0;
    for (actions, 0..) |action, action_index| {
        if (action == .tutorial) {
            found_tutorial = true;
            tutorial_index = action_index;
        }
    }
    try std.testing.expect(found_tutorial);
    try std.testing.expectEqual(@as(usize, 1), tutorial_index);
}
