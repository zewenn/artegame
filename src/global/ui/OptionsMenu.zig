const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;
const clay = lm.deps.clay;

const AudioManager = @import("../audio/AudioManager.zig");
const SaveSystem = @import("../save/SaveSystem.zig");

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

pub var options_tab: OptionsTab = .audio;
pub var selected_index: usize = 0;
pub var prev_selected_index: usize = 0;

var stick_moved_x: bool = false;
var stick_moved_y: bool = false;
var just_opened: bool = false;

pub fn reset() void {
    options_tab = .audio;
    selected_index = 0;
    prev_selected_index = 0;
    stick_moved_x = false;
    stick_moved_y = false;
    just_opened = true;
}

/// Renders the shared Options & Settings panel.
/// Returns `true` if the player activated the BACK action (via button click, Enter, Esc, or Gamepad B).
pub fn draw(ui_scale: f32, window_size: lm.Vector2, alloc: ?std.mem.Allocator) bool {
    const should_exit = if (just_opened) should_exit: {
        just_opened = false;
        break :should_exit false;
    } else handleInput();

    const panel_w = @min(window_size.x - 48, @round(680 * ui_scale));
    const panel_h = @min(window_size.y - 48, @round(520 * ui_scale));
    const panel_padding = lm.tou16(@round(20 * ui_scale));
    const title_font_size = lm.tou16(@max(18, @round(20 * ui_scale)));

    var back_clicked = false;

    ui.new(.{
        .id = .ID("shared-options-panel"),
        .layout = .{
            .sizing = .{
                .w = .fixed(panel_w),
                .h = .fixed(panel_h),
            },
            .direction = .top_to_bottom,
            .child_alignment = .{ .x = .center },
            .child_gap = lm.tou16(@round(14 * ui_scale)),
            .padding = .all(panel_padding),
        },
        .background_color = ui.color(16, 18, 25, 250),
        .corner_radius = .all(12 * ui_scale),
        .border = .{
            .color = ui.color(55, 62, 80, 200),
            .width = .outside(1),
        },
    })({
        ui.new(.{
            .id = .ID("opt-title-wrap"),
            .layout = .{ .child_alignment = .{ .x = .center } },
        })({
            ui.text("SETTINGS & OPTIONS", .{
                .color = ui.color(240, 200, 100, 255),
                .font_size = title_font_size,
                .letter_spacing = 2,
                .alignment = .center,
            });
        });

        drawOptionsTabs(ui_scale);

        switch (options_tab) {
            .audio => drawAudioTab(panel_w, ui_scale, alloc),
            .display => drawDisplayTab(panel_w, ui_scale),
            .controls => drawControlsTab(panel_w, ui_scale),
        }

        if (drawBackButton(ui_scale)) {
            back_clicked = true;
        }
    });

    if (selected_index != prev_selected_index) {
        AudioManager.playSfxPitched("audio/sfx/click.wav", 0.35, 0.1);
        prev_selected_index = selected_index;
    }

    if (should_exit or back_clicked) {
        AudioManager.playSfxPitched("audio/sfx/click.wav", 0.5, 0.0);
        return true;
    }

    return false;
}

// --------------------------------------------------------------------------------------------------
// Tabs & Content
// --------------------------------------------------------------------------------------------------

fn drawOptionsTabs(ui_scale: f32) void {
    const tab_h = @round(34 * ui_scale);
    const tab_w = @round(130 * ui_scale);
    const tab_font_size = lm.tou16(@max(11, @round(13 * ui_scale)));

    ui.new(.{
        .id = .ID("opt-tabs-bar"),
        .layout = .{
            .direction = .left_to_right,
            .child_gap = lm.tou16(@round(8 * ui_scale)),
            .child_alignment = .{ .y = .center },
        },
    })({
        drawTabItem(.audio, "AUDIO", tab_w, tab_h, ui_scale, tab_font_size);
        drawTabItem(.display, "DISPLAY", tab_w, tab_h, ui_scale, tab_font_size);
        drawTabItem(.controls, "CONTROLS", tab_w, tab_h, ui_scale, tab_font_size);
    });
}

fn drawTabItem(
    tab: OptionsTab,
    label: []const u8,
    w: f32,
    h: f32,
    ui_scale: f32,
    font_size: u16,
) void {
    const is_active = (options_tab == tab);

    clay.UI()(.{
        .id = .IDI("opt-tab-", @intFromEnum(tab)),
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
            setTab(tab);
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

fn drawAudioTab(panel_w: f32, ui_scale: f32, alloc: ?std.mem.Allocator) void {
    const content_w = panel_w - @round(48 * ui_scale);
    const row_h = @round(42 * ui_scale);

    ui.new(.{
        .id = .ID("opt-audio-content"),
        .layout = .{
            .sizing = .{ .w = .fixed(content_w) },
            .direction = .top_to_bottom,
            .child_gap = lm.tou16(@round(8 * ui_scale)),
            .child_alignment = .{ .x = .center },
        },
    })({
        drawVolumeRow(0, .master, "Master Volume", AudioManager.master_volume, content_w, row_h, ui_scale, alloc);
        drawVolumeRow(1, .music, "Music Volume", AudioManager.music_volume, content_w, row_h, ui_scale, alloc);
        drawVolumeRow(2, .sfx, "SFX Volume", AudioManager.sfx_volume, content_w, row_h, ui_scale, alloc);
        drawMuteRow(3, content_w, row_h, ui_scale);
    });
}

fn drawVolumeRow(
    index: usize,
    kind: VolumeType,
    label: []const u8,
    value: f32,
    row_w: f32,
    row_h: f32,
    ui_scale: f32,
    alloc: ?std.mem.Allocator,
) void {
    const is_selected = (selected_index == index);
    const pct = @as(u32, @intFromFloat(@round(value * 100.0)));
    const btn_size = @round(30 * ui_scale);
    const bar_total_w = @round(160 * ui_scale);
    const bar_filled_w = @max(0.0, bar_total_w * value);
    const bar_unfilled_w = @max(0.0, bar_total_w - bar_filled_w);
    const bar_h = @round(10 * ui_scale);

    const pct_str = if (alloc) |a|
        std.fmt.allocPrint(a, "{d}%", .{pct}) catch "0%"
    else
        "0%";

    clay.UI()(.{
        .id = .IDI("opt-vol-row-", @intCast(index)),
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
        if (clay.hovered()) selected_index = index;

        ui.new(.{
            .id = .IDI("opt-vol-lbl-", @intCast(index)),
            .layout = .{ .sizing = .{ .w = .fixed(@round(180 * ui_scale)) } },
        })({
            ui.text(label, .{
                .color = if (is_selected) ui.color(255, 235, 170, 255) else ui.color(220, 225, 235, 255),
                .font_size = lm.tou16(@max(12, @round(13 * ui_scale))),
                .letter_spacing = 1,
            });
        });

        clay.UI()(.{
            .id = .IDI("opt-vol-dec-", @intCast(index)),
            .layout = .{
                .sizing = .{ .w = .fixed(btn_size), .h = .fixed(btn_size) },
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
                selected_index = index;
                adjustVolume(kind, -0.05);
            }
            ui.text("-", .{
                .color = ui.color(255, 255, 255, 255),
                .font_size = lm.tou16(@max(14, @round(16 * ui_scale))),
                .alignment = .center,
            });
        });

        ui.new(.{
            .id = .IDI("opt-vol-g1-", @intCast(index)),
            .layout = .{ .sizing = .{ .w = .fixed(@round(10 * ui_scale)) } },
        })({});

        ui.new(.{
            .id = .IDI("opt-vol-bar-", @intCast(index)),
            .layout = .{
                .sizing = .{ .w = .fixed(bar_total_w), .h = .fixed(bar_h) },
                .direction = .left_to_right,
            },
            .background_color = ui.color(24, 28, 38, 255),
            .corner_radius = .all(4 * ui_scale),
            .border = .{ .color = ui.color(55, 62, 80, 160), .width = .outside(1) },
        })({
            if (bar_filled_w > 0.5) {
                ui.new(.{
                    .id = .IDI("opt-vol-fill-", @intCast(index)),
                    .layout = .{ .sizing = .{ .w = .fixed(bar_filled_w), .h = .fixed(bar_h) } },
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
                    .id = .IDI("opt-vol-empty-", @intCast(index)),
                    .layout = .{ .sizing = .{ .w = .fixed(bar_unfilled_w), .h = .fixed(bar_h) } },
                })({});
            }
        });

        ui.new(.{
            .id = .IDI("opt-vol-g2-", @intCast(index)),
            .layout = .{ .sizing = .{ .w = .fixed(@round(10 * ui_scale)) } },
        })({});

        clay.UI()(.{
            .id = .IDI("opt-vol-inc-", @intCast(index)),
            .layout = .{
                .sizing = .{ .w = .fixed(btn_size), .h = .fixed(btn_size) },
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
                selected_index = index;
                adjustVolume(kind, 0.05);
            }
            ui.text("+", .{
                .color = ui.color(255, 255, 255, 255),
                .font_size = lm.tou16(@max(14, @round(16 * ui_scale))),
                .alignment = .center,
            });
        });

        ui.new(.{
            .id = .IDI("opt-vol-pct-", @intCast(index)),
            .layout = .{
                .sizing = .{ .w = .fixed(@round(56 * ui_scale)) },
                .child_alignment = .{ .x = .right, .y = .center },
            },
        })({
            ui.text(pct_str, .{
                .color = if (is_selected) ui.color(240, 200, 100, 255) else ui.color(180, 185, 200, 255),
                .font_size = lm.tou16(@max(12, @round(13 * ui_scale))),
                .alignment = .right,
            });
        });
    });
}

fn drawMuteRow(index: usize, row_w: f32, row_h: f32, ui_scale: f32) void {
    const is_selected = (selected_index == index);
    const is_mute = AudioManager.mute;

    clay.UI()(.{
        .id = .IDI("opt-mute-row-", @intCast(index)),
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
            selected_index = index;
            if (lm.mouse.getButtonDown(.left)) {
                toggleMuteAudio();
            }
        }

        ui.new(.{
            .id = .ID("opt-mute-lbl-wrap"),
            .layout = .{ .sizing = .{ .w = .fixed(@round(180 * ui_scale)) } },
        })({
            ui.text("Mute All Audio", .{
                .color = if (is_selected) ui.color(255, 235, 170, 255) else ui.color(220, 225, 235, 255),
                .font_size = lm.tou16(@max(12, @round(13 * ui_scale))),
                .letter_spacing = 1,
            });
        });

        ui.new(.{
            .id = .ID("opt-mute-badge-btn"),
            .layout = .{
                .sizing = .{
                    .w = .fixed(@round(110 * ui_scale)),
                    .h = .fixed(@round(30 * ui_scale)),
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

fn drawDisplayTab(panel_w: f32, ui_scale: f32) void {
    const content_w = panel_w - @round(48 * ui_scale);
    const row_h = @round(44 * ui_scale);
    const is_selected = (selected_index == 0);
    const is_fs = lm.window.fullscreen.get();

    ui.new(.{
        .id = .ID("opt-display-content"),
        .layout = .{
            .sizing = .{ .w = .fixed(content_w) },
            .direction = .top_to_bottom,
            .child_gap = lm.tou16(@round(10 * ui_scale)),
            .child_alignment = .{ .x = .center },
        },
    })({
        clay.UI()(.{
            .id = .ID("opt-fullscreen-row"),
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
                selected_index = 0;
                if (lm.mouse.getButtonDown(.left)) {
                    toggleFullscreenMode();
                }
            }

            ui.new(.{
                .id = .ID("opt-fs-label-wrap"),
                .layout = .{ .sizing = .{ .w = .fixed(@round(220 * ui_scale)) } },
            })({
                ui.text("Display Mode", .{
                    .color = if (is_selected) ui.color(255, 235, 170, 255) else ui.color(220, 225, 235, 255),
                    .font_size = lm.tou16(@max(12, @round(13 * ui_scale))),
                    .letter_spacing = 1,
                });
            });

            ui.new(.{
                .id = .ID("opt-fs-badge-btn"),
                .layout = .{
                    .sizing = .{
                        .w = .fixed(@round(150 * ui_scale)),
                        .h = .fixed(@round(32 * ui_scale)),
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
    });
}

fn drawControlsTab(panel_w: f32, ui_scale: f32) void {
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
        .{ .action = "Pause / Menu", .kbm = "Escape", .pad = "Start / Options" },
    };

    ui.new(.{
        .id = .ID("opt-controls-content"),
        .layout = .{
            .sizing = .{ .w = .fixed(content_w) },
            .direction = .top_to_bottom,
            .child_gap = lm.tou16(@round(3 * ui_scale)),
        },
    })({
        ui.new(.{
            .id = .ID("opt-ctrl-header"),
            .layout = .{
                .sizing = .{ .w = .fixed(content_w), .h = .fixed(@round(24 * ui_scale)) },
                .direction = .left_to_right,
                .child_alignment = .{ .y = .center },
                .padding = .axes(0, lm.tou16(@round(8 * ui_scale))),
            },
            .background_color = ui.color(25, 30, 42, 220),
            .corner_radius = .all(4 * ui_scale),
        })({
            ui.new(.{
                .id = .ID("opt-tbl-h1"),
                .layout = .{ .sizing = .{ .w = .fixed(@round(160 * ui_scale)) } },
            })({
                ui.text("ACTION", .{
                    .color = ui.color(240, 200, 100, 255),
                    .font_size = header_font_size,
                    .letter_spacing = 1,
                });
            });

            ui.new(.{
                .id = .ID("opt-tbl-h2"),
                .layout = .{ .sizing = .{ .w = .fixed(@round(190 * ui_scale)) } },
            })({
                ui.text("KEYBOARD & MOUSE", .{
                    .color = ui.color(240, 200, 100, 255),
                    .font_size = header_font_size,
                    .letter_spacing = 1,
                });
            });

            ui.new(.{
                .id = .ID("opt-tbl-h3"),
                .layout = .{ .sizing = .{ .w = .grow } },
            })({
                ui.text("CONTROLLER", .{
                    .color = ui.color(240, 200, 100, 255),
                    .font_size = header_font_size,
                    .letter_spacing = 1,
                });
            });
        });

        for (bindings, 0..) |bind, i| {
            const is_even = (i % 2 == 0);
            ui.new(.{
                .id = .IDI("opt-crow-", @intCast(i)),
                .layout = .{
                    .sizing = .{ .w = .fixed(content_w), .h = .fixed(@round(22 * ui_scale)) },
                    .direction = .left_to_right,
                    .child_alignment = .{ .y = .center },
                    .padding = .axes(0, lm.tou16(@round(8 * ui_scale))),
                },
                .background_color = if (is_even) ui.color(18, 21, 28, 180) else ui.color(14, 16, 22, 180),
            })({
                ui.new(.{
                    .id = .IDI("opt-c1-", @intCast(i)),
                    .layout = .{ .sizing = .{ .w = .fixed(@round(160 * ui_scale)) } },
                })({
                    ui.text(bind.action, .{
                        .color = ui.color(225, 230, 240, 255),
                        .font_size = row_font_size,
                    });
                });

                ui.new(.{
                    .id = .IDI("opt-c2-", @intCast(i)),
                    .layout = .{ .sizing = .{ .w = .fixed(@round(190 * ui_scale)) } },
                })({
                    ui.text(bind.kbm, .{
                        .color = ui.color(165, 175, 195, 255),
                        .font_size = row_font_size,
                    });
                });

                ui.new(.{
                    .id = .IDI("opt-c3-", @intCast(i)),
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

fn drawBackButton(ui_scale: f32) bool {
    const back_index = getBackIndex();
    const is_selected = (selected_index == back_index);
    const btn_w = @round(160 * ui_scale);
    const btn_h = @round(38 * ui_scale);
    var clicked = false;

    clay.UI()(.{
        .id = .ID("opt-back-btn"),
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
            selected_index = back_index;
            if (lm.mouse.getButtonDown(.left)) {
                clicked = true;
            }
        }

        ui.text("BACK", .{
            .color = if (clay.hovered() or is_selected)
                ui.color(255, 255, 255, 255)
            else
                ui.color(200, 205, 220, 255),
            .font_size = lm.tou16(@max(12, @round(13 * ui_scale))),
            .letter_spacing = 2,
            .alignment = .center,
        });
    });

    return clicked;
}

// --------------------------------------------------------------------------------------------------
// Input & State Handling
// --------------------------------------------------------------------------------------------------

fn handleInput() bool {
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
        back_pressed = back_pressed or lm.gamepad.getButtonDown(0, .right_face_right) or
            lm.gamepad.getButtonDown(0, .middle_right) or lm.gamepad.getButtonDown(0, .middle);
        tab_prev = tab_prev or lm.gamepad.getButtonDown(0, .left_trigger_1);
        tab_next = tab_next or lm.gamepad.getButtonDown(0, .right_trigger_1);

        const stick = lm.gamepad.getStickVector(0, .left, 0.25);
        if (@abs(stick.y) > 0.5) {
            if (!stick_moved_y) {
                if (stick.y < -0.5) nav_up = true;
                if (stick.y > 0.5) nav_down = true;
                stick_moved_y = true;
            }
        } else {
            stick_moved_y = false;
        }

        if (@abs(stick.x) > 0.5) {
            if (!stick_moved_x) {
                if (stick.x < -0.5) nav_left = true;
                if (stick.x > 0.5) nav_right = true;
                stick_moved_x = true;
            }
        } else {
            stick_moved_x = false;
        }
    }

    if (back_pressed) {
        return true;
    }

    if (tab_prev) {
        cycleTab(-1);
        return false;
    }
    if (tab_next) {
        cycleTab(1);
        return false;
    }

    const back_index = getBackIndex();

    if (nav_up) {
        if (selected_index == 0) selected_index = back_index else selected_index -= 1;
    }
    if (nav_down) {
        if (selected_index >= back_index) selected_index = 0 else selected_index += 1;
    }

    switch (options_tab) {
        .audio => {
            if (nav_left) {
                switch (selected_index) {
                    0 => adjustVolume(.master, -0.05),
                    1 => adjustVolume(.music, -0.05),
                    2 => adjustVolume(.sfx, -0.05),
                    3 => toggleMuteAudio(),
                    else => {},
                }
            }
            if (nav_right) {
                switch (selected_index) {
                    0 => adjustVolume(.master, 0.05),
                    1 => adjustVolume(.music, 0.05),
                    2 => adjustVolume(.sfx, 0.05),
                    3 => toggleMuteAudio(),
                    else => {},
                }
            }
            if (select_pressed) {
                if (selected_index == 3) {
                    toggleMuteAudio();
                } else if (selected_index == back_index) {
                    return true;
                }
            }
        },
        .display => {
            if (nav_left or nav_right or select_pressed) {
                if (selected_index == 0) {
                    toggleFullscreenMode();
                } else if (selected_index == back_index) {
                    return true;
                }
            }
        },
        .controls => {
            if (select_pressed and selected_index == back_index) {
                return true;
            }
        },
    }

    return false;
}

pub fn setTab(tab: OptionsTab) void {
    if (options_tab != tab) {
        AudioManager.playSfxPitched("audio/sfx/click.wav", 0.45, 0.05);
        options_tab = tab;
        selected_index = 0;
        prev_selected_index = 0;
    }
}

pub fn cycleTab(delta: i32) void {
    const current = @as(i32, @intCast(@intFromEnum(options_tab)));
    const count: i32 = 3;
    const next_val = @mod(current + delta, count);
    setTab(@enumFromInt(@as(usize, @intCast(next_val))));
}

pub fn getBackIndex() usize {
    return switch (options_tab) {
        .audio => 4,
        .display => 1,
        .controls => 0,
    };
}

pub fn adjustVolume(kind: VolumeType, delta: f32) void {
    switch (kind) {
        .master => AudioManager.setMasterVolume(AudioManager.master_volume + delta),
        .music => AudioManager.setMusicVolume(AudioManager.music_volume + delta),
        .sfx => AudioManager.setSfxVolume(AudioManager.sfx_volume + delta),
    }
    SaveSystem.updateSettings(
        AudioManager.master_volume,
        AudioManager.music_volume,
        AudioManager.sfx_volume,
        AudioManager.mute,
    );
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.35, 0.15);
}

pub fn toggleMuteAudio() void {
    AudioManager.toggleMute();
    SaveSystem.updateSettings(
        AudioManager.master_volume,
        AudioManager.music_volume,
        AudioManager.sfx_volume,
        AudioManager.mute,
    );
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.5, 0.05);
}

pub fn toggleFullscreenMode() void {
    lm.window.fullscreen.toggle();
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.5, 0.05);
}

// --------------------------------------------------------------------------------------------------
// Unit Tests
// --------------------------------------------------------------------------------------------------

test "OptionsMenu tab cycling and back index resolution" {
    reset();
    try std.testing.expectEqual(OptionsTab.audio, options_tab);
    try std.testing.expectEqual(@as(usize, 4), getBackIndex());

    cycleTab(1);
    try std.testing.expectEqual(OptionsTab.display, options_tab);
    try std.testing.expectEqual(@as(usize, 1), getBackIndex());

    cycleTab(1);
    try std.testing.expectEqual(OptionsTab.controls, options_tab);
    try std.testing.expectEqual(@as(usize, 0), getBackIndex());

    cycleTab(1);
    try std.testing.expectEqual(OptionsTab.audio, options_tab);

    cycleTab(-1);
    try std.testing.expectEqual(OptionsTab.controls, options_tab);
}

test "OptionsMenu volume clamping bounds" {
    AudioManager.setMasterVolume(0.95);
    adjustVolume(.master, 0.1);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), AudioManager.master_volume, 0.001);

    adjustVolume(.master, -1.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), AudioManager.master_volume, 0.001);

    AudioManager.setMasterVolume(1.0);
}
