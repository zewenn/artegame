const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;
const clay = lm.deps.clay;

const AudioManager = @import("../audio/AudioManager.zig");

const Self = @This();

pub const Screen = enum {
    main,
    options,
};

pub const OptionsTab = enum {
    audio,
    display,
    controls,
};

pub const VolumeType = enum {
    master,
    music,
    sfx,
};

// Global Behaviour fields
arena: ?std.heap.ArenaAllocator = null,
alloc: ?std.mem.Allocator = null,

screen: Screen = .main,
options_tab: OptionsTab = .audio,

selected_index: usize = 0,
prev_selected_index: usize = 0,

stick_moved_x: bool = false,
stick_moved_y: bool = false,

pub fn Awake(self: *Self) void {
    self.screen = .main;
    self.options_tab = .audio;
    self.selected_index = 0;
    self.prev_selected_index = 0;
    self.stick_moved_x = false;
    self.stick_moved_y = false;

    self.arena = .init(lm.allocators.generic());
    self.alloc = self.arena.?.allocator();
}

pub fn Start(self: *Self) void {
    _ = self;
}

pub fn Update(self: *Self) !void {
    if (self.arena) |*arena| _ = arena.reset(.free_all);

    const window_size = lm.window.size.get();
    const scale_x = window_size.x / 1280.0;
    const scale_y = window_size.y / 720.0;
    const ui_scale = @max(0.65, @min(2.5, @min(scale_x, scale_y)));

    self.handleInput();

    // Full screen background container
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
            .options => self.drawOptionsScreen(ui_scale, window_size),
        }
    });

    if (self.selected_index != self.prev_selected_index) {
        AudioManager.playSfxPitched("audio/click.wav", 0.35, 0.1);
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
    const logo_w = @round(480 * ui_scale);
    const logo_h = @round(120 * ui_scale);
    const button_w = @round(300 * ui_scale);
    const button_h = @round(52 * ui_scale);
    const button_gap = lm.tou16(@round(14 * ui_scale));
    const font_size = lm.tou16(@max(14, @round(16 * ui_scale)));
    const letter_spacing = lm.tou16(@max(2, @round(3 * ui_scale)));

    // Logo image container
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
                "ui/artegame_logo.png",
                .init(logo_w, logo_h),
            ) catch .{ .image_data = null },
        })({});
    });

    // Subtitle badge
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

    // Spacer
    ui.new(.{
        .id = .ID("menu-main-spacer"),
        .layout = .{
            .sizing = .{ .h = .fixed(@round(32 * ui_scale)), .w = .fixed(1) },
        },
    })({});

    // Button list container
    ui.new(.{
        .id = .ID("menu-button-list"),
        .layout = .{
            .direction = .top_to_bottom,
            .child_gap = button_gap,
            .child_alignment = .{ .x = .center },
        },
    })({
        // PLAY Button
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

        // OPTIONS Button
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

        // QUIT Button
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
    });

    // Version / Help footer
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
        ui.text("Navigate: Arrows / WASD / D-Pad  |  Select: Enter / Space / Gamepad A", .{
            .color = ui.color(120, 128, 148, 200),
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

    clay.UI()(.{
        .id = .IDI("menu-btn-", @intCast(index)),
        .layout = .{
            .sizing = .{
                .w = .fixed(w),
                .h = .fixed(h),
            },
            .child_alignment = .{ .x = .center, .y = .center },
        },
        .background_color = if (clay.hovered() or is_selected)
            if (is_primary) ui.color(52, 60, 80, 255) else ui.color(40, 46, 62, 255)
        else
            ui.color(20, 23, 31, 230),
        .corner_radius = .all(8 * ui_scale),
        .border = .{
            .color = if (clay.hovered() or is_selected)
                ui.color(240, 200, 100, 255)
            else if (is_primary)
                ui.color(200, 165, 80, 180)
            else
                ui.color(50, 56, 72, 180),
            .width = .outside(if (clay.hovered() or is_selected) 2 else 1),
        },
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
// Options Screen Rendering
// --------------------------------------------------------------------------------------------------

fn drawOptionsScreen(self: *Self, ui_scale: f32, window_size: lm.Vector2) void {
    const panel_w = @min(window_size.x - 48, @round(680 * ui_scale));
    const panel_h = @min(window_size.y - 48, @round(540 * ui_scale));
    const panel_padding = lm.tou16(@round(24 * ui_scale));
    const title_font_size = lm.tou16(@max(18, @round(22 * ui_scale)));

    ui.new(.{
        .id = .ID("options-panel"),
        .layout = .{
            .sizing = .{
                .w = .fixed(panel_w),
                .h = .fixed(panel_h),
            },
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = lm.tou16(@round(16 * ui_scale)),
            .padding = .all(panel_padding),
        },
        .background_color = ui.color(16, 18, 24, 250),
        .corner_radius = .all(14 * ui_scale),
        .border = .{
            .color = ui.color(55, 62, 80, 200),
            .width = .outside(1),
        },
    })({
        // Title Header
        ui.new(.{
            .id = .ID("options-header"),
            .layout = .{
                .child_alignment = .{ .x = .center },
            },
        })({
            ui.text("SETTINGS & OPTIONS", .{
                .color = ui.color(240, 200, 100, 255),
                .font_size = title_font_size,
                .letter_spacing = 2,
                .alignment = .center,
            });
        });

        // Tab Navigation Bar
        self.drawOptionsTabs(ui_scale);

        // Active Tab Content
        switch (self.options_tab) {
            .audio => self.drawAudioTab(panel_w, ui_scale),
            .display => self.drawDisplayTab(panel_w, ui_scale),
            .controls => self.drawControlsTab(panel_w, ui_scale),
        }

        // Back Button
        self.drawBackButton(ui_scale);
    });
}

fn drawOptionsTabs(self: *Self, ui_scale: f32) void {
    const tab_h = @round(36 * ui_scale);
    const tab_w = @round(140 * ui_scale);
    const tab_font_size = lm.tou16(@max(12, @round(13 * ui_scale)));

    ui.new(.{
        .id = .ID("options-tabs-bar"),
        .layout = .{
            .direction = .left_to_right,
            .child_gap = lm.tou16(@round(8 * ui_scale)),
            .child_alignment = .{ .y = .center },
        },
    })({
        self.drawTabItem(.audio, "AUDIO", tab_w, tab_h, ui_scale, tab_font_size);
        self.drawTabItem(.display, "DISPLAY", tab_w, tab_h, ui_scale, tab_font_size);
        self.drawTabItem(.controls, "CONTROLS", tab_w, tab_h, ui_scale, tab_font_size);
    });
}

fn drawTabItem(
    self: *Self,
    tab: OptionsTab,
    label: []const u8,
    w: f32,
    h: f32,
    ui_scale: f32,
    font_size: u16,
) void {
    const is_active = (self.options_tab == tab);

    clay.UI()(.{
        .id = .IDI("tab-btn-", @intFromEnum(tab)),
        .layout = .{
            .sizing = .{
                .w = .fixed(w),
                .h = .fixed(h),
            },
            .child_alignment = .{ .x = .center, .y = .center },
        },
        .background_color = if (is_active)
            ui.color(38, 44, 60, 255)
        else if (clay.hovered())
            ui.color(28, 32, 44, 255)
        else
            ui.color(18, 20, 28, 200),
        .corner_radius = .all(6 * ui_scale),
        .border = .{
            .color = if (is_active)
                ui.color(240, 200, 100, 255)
            else if (clay.hovered())
                ui.color(120, 130, 155, 180)
            else
                ui.color(40, 45, 60, 160),
            .width = .outside(if (is_active) 2 else 1),
        },
    })({
        if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
            self.setTab(tab);
        }

        ui.text(label, .{
            .color = if (is_active)
                ui.color(255, 235, 170, 255)
            else if (clay.hovered())
                ui.color(255, 255, 255, 255)
            else
                ui.color(160, 168, 185, 255),
            .font_size = font_size,
            .letter_spacing = 1,
            .alignment = .center,
        });
    });
}

fn drawAudioTab(self: *Self, panel_w: f32, ui_scale: f32) void {
    const content_w = panel_w - @round(48 * ui_scale);
    const row_h = @round(44 * ui_scale);

    ui.new(.{
        .id = .ID("audio-tab-content"),
        .layout = .{
            .sizing = .{
                .w = .fixed(content_w),
            },
            .direction = .top_to_bottom,
            .child_gap = lm.tou16(@round(10 * ui_scale)),
            .child_alignment = .{ .x = .center },
        },
    })({
        // Master Volume (index 0)
        self.drawVolumeRow(0, .master, "Master Volume", AudioManager.master_volume, content_w, row_h, ui_scale);

        // Music Volume (index 1)
        self.drawVolumeRow(1, .music, "Music Volume", AudioManager.music_volume, content_w, row_h, ui_scale);

        // SFX Volume (index 2)
        self.drawVolumeRow(2, .sfx, "SFX Volume", AudioManager.sfx_volume, content_w, row_h, ui_scale);

        // Mute Audio Toggle (index 3)
        self.drawMuteRow(3, content_w, row_h, ui_scale);
    });
}

fn drawVolumeRow(
    self: *Self,
    index: usize,
    kind: VolumeType,
    label: []const u8,
    value: f32,
    row_w: f32,
    row_h: f32,
    ui_scale: f32,
) void {
    const is_selected = (self.selected_index == index);
    const pct = @as(u32, @intFromFloat(@round(value * 100.0)));
    const btn_size = @round(32 * ui_scale);
    const bar_total_w = @round(160 * ui_scale);
    const bar_filled_w = @max(0.0, bar_total_w * value);
    const bar_unfilled_w = @max(0.0, bar_total_w - bar_filled_w);
    const bar_h = @round(12 * ui_scale);

    const pct_str = if (self.alloc) |a|
        std.fmt.allocPrint(a, "{d}%", .{pct}) catch "0%"
    else
        "0%";

    clay.UI()(.{
        .id = .IDI("volume-row-", @intCast(index)),
        .layout = .{
            .sizing = .{
                .w = .fixed(row_w),
                .h = .fixed(row_h),
            },
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .padding = .axes(
                lm.tou16(@round(4 * ui_scale)),
                lm.tou16(@round(16 * ui_scale)),
            ),
        },
        .background_color = if (clay.hovered() or is_selected)
            ui.color(28, 33, 46, 220)
        else
            ui.color(20, 23, 31, 160),
        .corner_radius = .all(6 * ui_scale),
        .border = .{
            .color = if (clay.hovered() or is_selected)
                ui.color(240, 200, 100, 200)
            else
                ui.color(40, 46, 60, 120),
            .width = .outside(if (clay.hovered() or is_selected) 2 else 1),
        },
    })({
        if (clay.hovered()) self.selected_index = index;

        // Label
        ui.new(.{
            .id = .IDI("vol-label-wrap-", @intCast(index)),
            .layout = .{
                .sizing = .{ .w = .fixed(@round(180 * ui_scale)) },
            },
        })({
            ui.text(label, .{
                .color = if (is_selected) ui.color(255, 235, 170, 255) else ui.color(220, 225, 235, 255),
                .font_size = lm.tou16(@max(12, @round(14 * ui_scale))),
                .letter_spacing = 1,
            });
        });

        // Decrement button
        clay.UI()(.{
            .id = .IDI("vol-dec-btn-", @intCast(index)),
            .layout = .{
                .sizing = .{
                    .w = .fixed(btn_size),
                    .h = .fixed(btn_size),
                },
                .child_alignment = .{ .x = .center, .y = .center },
            },
            .background_color = if (clay.hovered()) ui.color(50, 58, 78, 255) else ui.color(30, 35, 48, 220),
            .corner_radius = .all(4 * ui_scale),
            .border = .{
                .color = if (clay.hovered()) ui.color(240, 200, 100, 220) else ui.color(60, 68, 88, 160),
                .width = .outside(1),
            },
        })({
            if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
                self.selected_index = index;
                adjustVolume(kind, -0.05);
            }
            ui.text("-", .{
                .color = ui.color(255, 255, 255, 255),
                .font_size = lm.tou16(@max(14, @round(16 * ui_scale))),
                .alignment = .center,
            });
        });

        // Spacer
        ui.new(.{
            .id = .IDI("vol-gap-1-", @intCast(index)),
            .layout = .{ .sizing = .{ .w = .fixed(@round(10 * ui_scale)) } },
        })({});

        // Progress bar container
        ui.new(.{
            .id = .IDI("vol-bar-bg-", @intCast(index)),
            .layout = .{
                .sizing = .{
                    .w = .fixed(bar_total_w),
                    .h = .fixed(bar_h),
                },
                .direction = .left_to_right,
            },
            .background_color = ui.color(24, 28, 38, 255),
            .corner_radius = .all(4 * ui_scale),
            .border = .{
                .color = ui.color(55, 62, 80, 160),
                .width = .outside(1),
            },
        })({
            if (bar_filled_w > 0.5) {
                ui.new(.{
                    .id = .IDI("vol-bar-fill-", @intCast(index)),
                    .layout = .{
                        .sizing = .{
                            .w = .fixed(bar_filled_w),
                            .h = .fixed(bar_h),
                        },
                    },
                    .background_color = if (AudioManager.mute)
                        ui.color(140, 60, 60, 220)
                    else if (is_selected)
                        ui.color(240, 200, 100, 255)
                    else
                        ui.color(70, 140, 230, 255),
                    .corner_radius = .all(4 * ui_scale),
                })({});
            }
            if (bar_unfilled_w > 0.5) {
                ui.new(.{
                    .id = .IDI("vol-bar-empty-", @intCast(index)),
                    .layout = .{
                        .sizing = .{
                            .w = .fixed(bar_unfilled_w),
                            .h = .fixed(bar_h),
                        },
                    },
                })({});
            }
        });

        // Spacer
        ui.new(.{
            .id = .IDI("vol-gap-2-", @intCast(index)),
            .layout = .{ .sizing = .{ .w = .fixed(@round(10 * ui_scale)) } },
        })({});

        // Increment button
        clay.UI()(.{
            .id = .IDI("vol-inc-btn-", @intCast(index)),
            .layout = .{
                .sizing = .{
                    .w = .fixed(btn_size),
                    .h = .fixed(btn_size),
                },
                .child_alignment = .{ .x = .center, .y = .center },
            },
            .background_color = if (clay.hovered()) ui.color(50, 58, 78, 255) else ui.color(30, 35, 48, 220),
            .corner_radius = .all(4 * ui_scale),
            .border = .{
                .color = if (clay.hovered()) ui.color(240, 200, 100, 220) else ui.color(60, 68, 88, 160),
                .width = .outside(1),
            },
        })({
            if (clay.hovered() and lm.mouse.getButtonDown(.left)) {
                self.selected_index = index;
                adjustVolume(kind, 0.05);
            }
            ui.text("+", .{
                .color = ui.color(255, 255, 255, 255),
                .font_size = lm.tou16(@max(14, @round(16 * ui_scale))),
                .alignment = .center,
            });
        });

        // Percentage text
        ui.new(.{
            .id = .IDI("vol-pct-wrap-", @intCast(index)),
            .layout = .{
                .sizing = .{ .w = .fixed(@round(60 * ui_scale)) },
                .child_alignment = .{ .x = .right, .y = .center },
            },
        })({
            ui.text(pct_str, .{
                .color = if (is_selected) ui.color(240, 200, 100, 255) else ui.color(180, 185, 200, 255),
                .font_size = lm.tou16(@max(12, @round(14 * ui_scale))),
                .alignment = .right,
            });
        });
    });
}

fn drawMuteRow(self: *Self, index: usize, row_w: f32, row_h: f32, ui_scale: f32) void {
    const is_selected = (self.selected_index == index);
    const is_mute = AudioManager.mute;

    clay.UI()(.{
        .id = .IDI("mute-row-", @intCast(index)),
        .layout = .{
            .sizing = .{
                .w = .fixed(row_w),
                .h = .fixed(row_h),
            },
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .padding = .axes(
                lm.tou16(@round(4 * ui_scale)),
                lm.tou16(@round(16 * ui_scale)),
            ),
        },
        .background_color = if (clay.hovered() or is_selected)
            ui.color(28, 33, 46, 220)
        else
            ui.color(20, 23, 31, 160),
        .corner_radius = .all(6 * ui_scale),
        .border = .{
            .color = if (clay.hovered() or is_selected)
                ui.color(240, 200, 100, 200)
            else
                ui.color(40, 46, 60, 120),
            .width = .outside(if (clay.hovered() or is_selected) 2 else 1),
        },
    })({
        if (clay.hovered()) {
            self.selected_index = index;
            if (lm.mouse.getButtonDown(.left)) {
                toggleMuteAudio();
            }
        }

        ui.new(.{
            .id = .ID("mute-label-wrap"),
            .layout = .{
                .sizing = .{ .w = .fixed(@round(180 * ui_scale)) },
            },
        })({
            ui.text("Mute All Audio", .{
                .color = if (is_selected) ui.color(255, 235, 170, 255) else ui.color(220, 225, 235, 255),
                .font_size = lm.tou16(@max(12, @round(14 * ui_scale))),
                .letter_spacing = 1,
            });
        });

        // Toggle badge button
        ui.new(.{
            .id = .ID("mute-badge-btn"),
            .layout = .{
                .sizing = .{
                    .w = .fixed(@round(120 * ui_scale)),
                    .h = .fixed(@round(32 * ui_scale)),
                },
                .child_alignment = .{ .x = .center, .y = .center },
            },
            .background_color = if (is_mute) ui.color(160, 45, 45, 240) else ui.color(35, 110, 65, 240),
            .corner_radius = .all(4 * ui_scale),
            .border = .{
                .color = if (is_selected) ui.color(240, 200, 100, 255) else ui.color(200, 210, 230, 140),
                .width = .outside(1),
            },
        })({
            ui.text(if (is_mute) "MUTED" else "UNMUTED", .{
                .color = ui.color(255, 255, 255, 255),
                .font_size = lm.tou16(@max(11, @round(12 * ui_scale))),
                .letter_spacing = 1,
                .alignment = .center,
            });
        });
    });
}

fn drawDisplayTab(self: *Self, panel_w: f32, ui_scale: f32) void {
    const content_w = panel_w - @round(48 * ui_scale);
    const row_h = @round(48 * ui_scale);
    const is_selected = (self.selected_index == 0);
    const is_fs = lm.window.fullscreen.get();

    ui.new(.{
        .id = .ID("display-tab-content"),
        .layout = .{
            .sizing = .{
                .w = .fixed(content_w),
            },
            .direction = .top_to_bottom,
            .child_gap = lm.tou16(@round(12 * ui_scale)),
            .child_alignment = .{ .x = .center },
        },
    })({
        clay.UI()(.{
            .id = .ID("fullscreen-row"),
            .layout = .{
                .sizing = .{
                    .w = .fixed(content_w),
                    .h = .fixed(row_h),
                },
                .direction = .left_to_right,
                .child_alignment = .{ .y = .center },
                .padding = .axes(
                    lm.tou16(@round(4 * ui_scale)),
                    lm.tou16(@round(16 * ui_scale)),
                ),
            },
            .background_color = if (clay.hovered() or is_selected)
                ui.color(28, 33, 46, 220)
            else
                ui.color(20, 23, 31, 160),
            .corner_radius = .all(6 * ui_scale),
            .border = .{
                .color = if (clay.hovered() or is_selected)
                    ui.color(240, 200, 100, 200)
                else
                    ui.color(40, 46, 60, 120),
                .width = .outside(if (clay.hovered() or is_selected) 2 else 1),
            },
        })({
            if (clay.hovered()) {
                self.selected_index = 0;
                if (lm.mouse.getButtonDown(.left)) {
                    toggleFullscreenMode();
                }
            }

            ui.new(.{
                .id = .ID("fs-label-wrap"),
                .layout = .{
                    .sizing = .{ .w = .fixed(@round(220 * ui_scale)) },
                },
            })({
                ui.text("Display Mode", .{
                    .color = if (is_selected) ui.color(255, 235, 170, 255) else ui.color(220, 225, 235, 255),
                    .font_size = lm.tou16(@max(12, @round(14 * ui_scale))),
                    .letter_spacing = 1,
                });
            });

            ui.new(.{
                .id = .ID("fs-toggle-btn"),
                .layout = .{
                    .sizing = .{
                        .w = .fixed(@round(160 * ui_scale)),
                        .h = .fixed(@round(34 * ui_scale)),
                    },
                    .child_alignment = .{ .x = .center, .y = .center },
                },
                .background_color = if (is_fs) ui.color(45, 75, 125, 240) else ui.color(35, 40, 52, 240),
                .corner_radius = .all(4 * ui_scale),
                .border = .{
                    .color = if (is_selected) ui.color(240, 200, 100, 255) else ui.color(70, 80, 105, 160),
                    .width = .outside(1),
                },
            })({
                ui.text(if (is_fs) "FULLSCREEN" else "WINDOWED", .{
                    .color = ui.color(255, 255, 255, 255),
                    .font_size = lm.tou16(@max(11, @round(12 * ui_scale))),
                    .letter_spacing = 1,
                    .alignment = .center,
                });
            });
        });

        // Resolution hint
        ui.new(.{
            .id = .ID("resolution-hint-wrap"),
            .layout = .{
                .padding = .all(lm.tou16(@round(8 * ui_scale))),
            },
        })({
            ui.text("Base resolution: 1280x720 (Dynamically adapts to window resize)", .{
                .color = ui.color(140, 148, 168, 200),
                .font_size = lm.tou16(@max(10, @round(12 * ui_scale))),
                .letter_spacing = 1,
                .alignment = .center,
            });
        });
    });
}

fn drawControlsTab(self: *Self, panel_w: f32, ui_scale: f32) void {
    _ = self;
    const content_w = panel_w - @round(48 * ui_scale);
    const header_font_size = lm.tou16(@max(11, @round(12 * ui_scale)));
    const row_font_size = lm.tou16(@max(10, @round(12 * ui_scale)));

    const Bind = struct { action: []const u8, kbm: []const u8, pad: []const u8 };
    const bindings = [_]Bind{
        .{ .action = "Move", .kbm = "W, A, S, D", .pad = "Left Stick" },
        .{ .action = "Aim / Look", .kbm = "Mouse Cursor", .pad = "Right Stick" },
        .{ .action = "Light Attack", .kbm = "Left Mouse Button", .pad = "Right Trigger (RT)" },
        .{ .action = "Heavy Attack", .kbm = "Right Mouse Button", .pad = "Left Trigger (LT)" },
        .{ .action = "Dash", .kbm = "Spacebar", .pad = "A Button (South)" },
        .{ .action = "Cast Spell 1", .kbm = "Q Key", .pad = "Left Bumper (LB)" },
        .{ .action = "Cast Spell 2", .kbm = "E Key", .pad = "Right Bumper (RB)" },
        .{ .action = "Interact / Shrine", .kbm = "F Key", .pad = "X Button (West)" },
        .{ .action = "Pause / Back", .kbm = "Escape", .pad = "Start / Options" },
    };

    ui.new(.{
        .id = .ID("controls-tab-content"),
        .layout = .{
            .sizing = .{
                .w = .fixed(content_w),
            },
            .direction = .top_to_bottom,
            .child_gap = lm.tou16(@round(4 * ui_scale)),
        },
    })({
        // Table Header
        ui.new(.{
            .id = .ID("controls-tbl-header"),
            .layout = .{
                .sizing = .{ .w = .fixed(content_w), .h = .fixed(@round(26 * ui_scale)) },
                .direction = .left_to_right,
                .child_alignment = .{ .y = .center },
                .padding = .axes(0, lm.tou16(@round(10 * ui_scale))),
            },
            .background_color = ui.color(25, 30, 42, 220),
            .corner_radius = .all(4 * ui_scale),
        })({
            ui.new(.{
                .id = .ID("tbl-h-col-1"),
                .layout = .{ .sizing = .{ .w = .fixed(@round(180 * ui_scale)) } },
            })({
                ui.text("ACTION", .{
                    .color = ui.color(240, 200, 100, 255),
                    .font_size = header_font_size,
                    .letter_spacing = 1,
                });
            });

            ui.new(.{
                .id = .ID("tbl-h-col-2"),
                .layout = .{ .sizing = .{ .w = .fixed(@round(200 * ui_scale)) } },
            })({
                ui.text("KEYBOARD & MOUSE", .{
                    .color = ui.color(240, 200, 100, 255),
                    .font_size = header_font_size,
                    .letter_spacing = 1,
                });
            });

            ui.new(.{
                .id = .ID("tbl-h-col-3"),
                .layout = .{ .sizing = .{ .w = .grow } },
            })({
                ui.text("CONTROLLER", .{
                    .color = ui.color(240, 200, 100, 255),
                    .font_size = header_font_size,
                    .letter_spacing = 1,
                });
            });
        });

        // Rows
        for (bindings, 0..) |bind, i| {
            const is_even = (i % 2 == 0);
            ui.new(.{
                .id = .IDI("ctrl-row-", @intCast(i)),
                .layout = .{
                    .sizing = .{ .w = .fixed(content_w), .h = .fixed(@round(24 * ui_scale)) },
                    .direction = .left_to_right,
                    .child_alignment = .{ .y = .center },
                    .padding = .axes(0, lm.tou16(@round(10 * ui_scale))),
                },
                .background_color = if (is_even) ui.color(18, 21, 28, 180) else ui.color(14, 16, 22, 180),
            })({
                ui.new(.{
                    .id = .IDI("ctrl-c1-", @intCast(i)),
                    .layout = .{ .sizing = .{ .w = .fixed(@round(180 * ui_scale)) } },
                })({
                    ui.text(bind.action, .{
                        .color = ui.color(225, 230, 240, 255),
                        .font_size = row_font_size,
                    });
                });

                ui.new(.{
                    .id = .IDI("ctrl-c2-", @intCast(i)),
                    .layout = .{ .sizing = .{ .w = .fixed(@round(200 * ui_scale)) } },
                })({
                    ui.text(bind.kbm, .{
                        .color = ui.color(165, 175, 195, 255),
                        .font_size = row_font_size,
                    });
                });

                ui.new(.{
                    .id = .IDI("ctrl-c3-", @intCast(i)),
                    .layout = .{ .sizing = .{ .w = .grow } },
                })({
                    ui.text(bind.pad, .{
                        .color = ui.color(165, 175, 195, 255),
                        .font_size = row_font_size,
                    });
                });
            });
        }
    });
}

fn drawBackButton(self: *Self, ui_scale: f32) void {
    const back_index = self.getBackIndex();
    const is_selected = (self.selected_index == back_index);
    const btn_w = @round(180 * ui_scale);
    const btn_h = @round(40 * ui_scale);

    clay.UI()(.{
        .id = .ID("options-back-btn"),
        .layout = .{
            .sizing = .{
                .w = .fixed(btn_w),
                .h = .fixed(btn_h),
            },
            .child_alignment = .{ .x = .center, .y = .center },
        },
        .background_color = if (clay.hovered() or is_selected)
            ui.color(45, 52, 70, 255)
        else
            ui.color(24, 28, 38, 220),
        .corner_radius = .all(6 * ui_scale),
        .border = .{
            .color = if (clay.hovered() or is_selected)
                ui.color(240, 200, 100, 255)
            else
                ui.color(60, 68, 88, 180),
            .width = .outside(if (clay.hovered() or is_selected) 2 else 1),
        },
    })({
        if (clay.hovered()) {
            self.selected_index = back_index;
            if (lm.mouse.getButtonDown(.left)) {
                self.goBackToMain();
            }
        }

        ui.text("BACK", .{
            .color = if (clay.hovered() or is_selected)
                ui.color(255, 255, 255, 255)
            else
                ui.color(200, 205, 220, 255),
            .font_size = lm.tou16(@max(12, @round(14 * ui_scale))),
            .letter_spacing = 2,
            .alignment = .center,
        });
    });
}

// --------------------------------------------------------------------------------------------------
// Input & State Actions
// --------------------------------------------------------------------------------------------------

fn handleInput(self: *Self) void {
    var nav_up = lm.keyboard.getKeyDown(.up) or lm.keyboard.getKeyDown(.w);
    var nav_down = lm.keyboard.getKeyDown(.down) or lm.keyboard.getKeyDown(.s);
    var nav_left = lm.keyboard.getKeyDown(.left) or lm.keyboard.getKeyDown(.a);
    var nav_right = lm.keyboard.getKeyDown(.right) or lm.keyboard.getKeyDown(.d);
    var select_pressed = lm.keyboard.getKeyDown(.enter) or lm.keyboard.getKeyDown(.space);
    var back_pressed = lm.keyboard.getKeyDown(.escape);
    var tab_prev = lm.keyboard.getKeyDown(.q);
    var tab_next = lm.keyboard.getKeyDown(.e) or lm.keyboard.getKeyDown(.tab);

    if (lm.gamepad.isAvailable(0)) {
        nav_up = nav_up or lm.gamepad.getButtonDown(0, .left_face_up);
        nav_down = nav_down or lm.gamepad.getButtonDown(0, .left_face_down);
        nav_left = nav_left or lm.gamepad.getButtonDown(0, .left_face_left);
        nav_right = nav_right or lm.gamepad.getButtonDown(0, .left_face_right);
        select_pressed = select_pressed or lm.gamepad.getButtonDown(0, .right_face_down);
        back_pressed = back_pressed or lm.gamepad.getButtonDown(0, .right_face_right);
        tab_prev = tab_prev or lm.gamepad.getButtonDown(0, .left_trigger_1);
        tab_next = tab_next or lm.gamepad.getButtonDown(0, .right_trigger_1);

        const stick = lm.gamepad.getStickVector(0, .left, 0.25);
        if (@abs(stick.y) > 0.5) {
            if (!self.stick_moved_y) {
                if (stick.y < -0.5) nav_up = true;
                if (stick.y > 0.5) nav_down = true;
                self.stick_moved_y = true;
            }
        } else {
            self.stick_moved_y = false;
        }

        if (@abs(stick.x) > 0.5) {
            if (!self.stick_moved_x) {
                if (stick.x < -0.5) nav_left = true;
                if (stick.x > 0.5) nav_right = true;
                self.stick_moved_x = true;
            }
        } else {
            self.stick_moved_x = false;
        }
    }

    if (self.screen == .main) {
        const max_index = 2; // 0: Play, 1: Options, 2: Quit
        if (nav_up) {
            if (self.selected_index == 0) self.selected_index = max_index else self.selected_index -= 1;
        }
        if (nav_down) {
            if (self.selected_index >= max_index) self.selected_index = 0 else self.selected_index += 1;
        }
        if (select_pressed) {
            self.activateAction(self.selected_index);
        }
    } else {
        // In Options Screen
        if (back_pressed) {
            self.goBackToMain();
            return;
        }

        if (tab_prev) {
            self.cycleTab(-1);
            return;
        }
        if (tab_next) {
            self.cycleTab(1);
            return;
        }

        const back_index = self.getBackIndex();

        if (nav_up) {
            if (self.selected_index == 0) self.selected_index = back_index else self.selected_index -= 1;
        }
        if (nav_down) {
            if (self.selected_index >= back_index) self.selected_index = 0 else self.selected_index += 1;
        }

        switch (self.options_tab) {
            .audio => {
                if (nav_left) {
                    switch (self.selected_index) {
                        0 => adjustVolume(.master, -0.05),
                        1 => adjustVolume(.music, -0.05),
                        2 => adjustVolume(.sfx, -0.05),
                        3 => toggleMuteAudio(),
                        else => {},
                    }
                }
                if (nav_right) {
                    switch (self.selected_index) {
                        0 => adjustVolume(.master, 0.05),
                        1 => adjustVolume(.music, 0.05),
                        2 => adjustVolume(.sfx, 0.05),
                        3 => toggleMuteAudio(),
                        else => {},
                    }
                }
                if (select_pressed) {
                    if (self.selected_index == 3) {
                        toggleMuteAudio();
                    } else if (self.selected_index == back_index) {
                        self.goBackToMain();
                    }
                }
            },
            .display => {
                if (nav_left or nav_right or select_pressed) {
                    if (self.selected_index == 0) {
                        toggleFullscreenMode();
                    } else if (self.selected_index == back_index) {
                        self.goBackToMain();
                    }
                }
            },
            .controls => {
                if (select_pressed and self.selected_index == back_index) {
                    self.goBackToMain();
                }
            },
        }
    }
}

fn activateAction(self: *Self, index: usize) void {
    switch (index) {
        0 => {
            // PLAY
            AudioManager.playSfxPitched("audio/coin.wav", 0.9, 0.05);
            lm.loadScene("demo_map") catch |err| {
                std.log.err("Failed to load demo_map scene: {any}", .{err});
            };
        },
        1 => {
            // OPTIONS
            AudioManager.playSfxPitched("audio/click.wav", 0.6, 0.0);
            self.screen = .options;
            self.options_tab = .audio;
            self.selected_index = 0;
            self.prev_selected_index = 0;
        },
        2 => {
            // QUIT
            AudioManager.playSfxPitched("audio/click.wav", 0.6, 0.0);
            lm.quit();
        },
        else => {},
    }
}

fn goBackToMain(self: *Self) void {
    AudioManager.playSfxPitched("audio/click.wav", 0.5, 0.0);
    self.screen = .main;
    self.selected_index = 1; // Highlight OPTIONS button on return
    self.prev_selected_index = 1;
}

fn setTab(self: *Self, tab: OptionsTab) void {
    if (self.options_tab != tab) {
        AudioManager.playSfxPitched("audio/click.wav", 0.45, 0.05);
        self.options_tab = tab;
        self.selected_index = 0;
        self.prev_selected_index = 0;
    }
}

fn cycleTab(self: *Self, delta: i32) void {
    const current = @as(i32, @intCast(@intFromEnum(self.options_tab)));
    const count: i32 = 3;
    const next_val = @mod(current + delta, count);
    self.setTab(@enumFromInt(@as(usize, @intCast(next_val))));
}

fn getBackIndex(self: *Self) usize {
    return switch (self.options_tab) {
        .audio => 4, // 0: Master, 1: Music, 2: SFX, 3: Mute, 4: Back
        .display => 1, // 0: Fullscreen, 1: Back
        .controls => 0, // 0: Back
    };
}

pub fn adjustVolume(kind: VolumeType, delta: f32) void {
    switch (kind) {
        .master => AudioManager.setMasterVolume(AudioManager.master_volume + delta),
        .music => AudioManager.setMusicVolume(AudioManager.music_volume + delta),
        .sfx => AudioManager.setSfxVolume(AudioManager.sfx_volume + delta),
    }
    AudioManager.playSfxPitched("audio/click.wav", 0.35, 0.15);
}

pub fn toggleMuteAudio() void {
    AudioManager.toggleMute();
    AudioManager.playSfxPitched("audio/click.wav", 0.5, 0.05);
}

pub fn toggleFullscreenMode() void {
    lm.window.fullscreen.toggle();
    AudioManager.playSfxPitched("audio/click.wav", 0.5, 0.05);
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

    // Nav down in main
    const max_main: usize = 2;
    menu.selected_index = if (menu.selected_index >= max_main) 0 else menu.selected_index + 1;
    try std.testing.expectEqual(@as(usize, 1), menu.selected_index);

    menu.selected_index = if (menu.selected_index >= max_main) 0 else menu.selected_index + 1;
    try std.testing.expectEqual(@as(usize, 2), menu.selected_index);

    // Wrap to top
    menu.selected_index = if (menu.selected_index >= max_main) 0 else menu.selected_index + 1;
    try std.testing.expectEqual(@as(usize, 0), menu.selected_index);

    // Nav up wrap to bottom
    menu.selected_index = if (menu.selected_index == 0) max_main else menu.selected_index - 1;
    try std.testing.expectEqual(@as(usize, 2), menu.selected_index);
}

test "MainMenu options screen and tab cycling" {
    var menu = Self{};
    menu.Awake();
    defer menu.End();

    menu.screen = .options;
    menu.options_tab = .audio;
    try std.testing.expectEqual(@as(usize, 4), menu.getBackIndex());

    menu.cycleTab(1);
    try std.testing.expectEqual(OptionsTab.display, menu.options_tab);
    try std.testing.expectEqual(@as(usize, 1), menu.getBackIndex());

    menu.cycleTab(1);
    try std.testing.expectEqual(OptionsTab.controls, menu.options_tab);
    try std.testing.expectEqual(@as(usize, 0), menu.getBackIndex());

    menu.cycleTab(1);
    try std.testing.expectEqual(OptionsTab.audio, menu.options_tab);

    menu.cycleTab(-1);
    try std.testing.expectEqual(OptionsTab.controls, menu.options_tab);
}

test "MainMenu volume adjustment clamping" {
    AudioManager.setMasterVolume(0.95);
    adjustVolume(.master, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), AudioManager.master_volume, 0.001);

    adjustVolume(.master, -1.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), AudioManager.master_volume, 0.001);

    AudioManager.setMasterVolume(1.0);
}
