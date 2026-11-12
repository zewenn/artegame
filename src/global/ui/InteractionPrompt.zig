const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const Interactable = @import("../../components/interaction/Interactable.zig");
const HUD = @import("../HUD.zig");
const DevicePrompts = @import("../input/DevicePrompts.zig");
const color_scheme = @import("color_scheme.zig");

pub fn draw(maybe_camera: ?*lm.Camera, interactable: *Interactable) void {
    const camera = maybe_camera orelse return;
    const transform = interactable.transform orelse return;

    const world_position = lm.vec3ToVec2(transform.position).add(interactable.prompt_offset);
    const screen_position = camera.worldToScreenPos(world_position);

    const ui_scale = HUD.ui_scale;
    const is_gamepad = DevicePrompts.isGamepad();
    const prompt = DevicePrompts.getActionPrompt(.interact);

    ui.new(.{
        .id = .ID("interaction-prompt-container"),
        .floating = .{
            .attach_to = .to_root,
            .offset = .{
                .x = screen_position.x,
                .y = screen_position.y,
            },
            .attach_points = .{
                .element = .center_bottom,
                .parent = .left_top,
            },
        },
        .background_color = color_scheme.prompt_background,
        .corner_radius = .all(6 * ui_scale),
        .border = .{
            .color = color_scheme.prompt_border,
            .width = .outside(1),
        },
        .layout = .{
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .child_gap = lm.tou16(@round(6 * ui_scale)),
            .padding = .axes(
                lm.tou16(@round(4 * ui_scale)),
                lm.tou16(@round(8 * ui_scale)),
            ),
        },
    })({
        ui.new(.{
            .id = .ID("interaction-prompt-key-badge"),
            .background_color = prompt.badge_background_color,
            .corner_radius = .all(if (is_gamepad) 8 * ui_scale else 4 * ui_scale),
            .border = .{
                .color = prompt.badge_border_color,
                .width = .outside(1),
            },
            .layout = .{
                .padding = .axes(
                    lm.tou16(@round(2 * ui_scale)),
                    lm.tou16(@round(if (is_gamepad) 7 * ui_scale else 6 * ui_scale)),
                ),
                .child_alignment = .{ .x = .center, .y = .center },
            },
        })({
            ui.text(prompt.label, .{
                .color = prompt.text_color,
                .font_size = lm.tou16(@round(13 * ui_scale)),
                .letter_spacing = 1,
            });
        });

        ui.new(.{
            .id = .ID("interaction-prompt-action-text"),
        })({
            ui.text(interactable.action_text, .{
                .color = color_scheme.text_primary,
                .font_size = lm.tou16(@round(13 * ui_scale)),
                .letter_spacing = 1,
            });
        });
    });
}
