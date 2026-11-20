const lm = @import("loom");
const ui = lm.ui;

const Interactable = @import("../../components/interaction/Interactable.zig");
const DevicePrompts = @import("../input/DevicePrompts.zig");
const theme = @import("theme.zig");
const color_scheme = @import("color_scheme.zig");

/// Renders the world-space interaction prompt badge and action caption above the focused interactable.
pub fn draw(maybe_camera: ?*lm.Camera, interactable: *Interactable, ui_scale: f32) void {
    const camera = maybe_camera orelse return;
    const transform = interactable.transform orelse return;

    const world_position = lm.vec3ToVec2(transform.position).add(interactable.prompt_offset);
    const screen_position = camera.worldToScreenPos(world_position);

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
        .corner_radius = .all(lm.tou16(@round(1.0 * ui_scale))),
        .background_color = color_scheme.prompt_background,
        .layout = .{
            .direction = .left_to_right,
            .child_alignment = .{ .y = .center },
            .child_gap = lm.tou16(@round(1.5 * ui_scale)),
            .padding = .axes(
                lm.tou16(@round(1.0 * ui_scale)),
                lm.tou16(@round(2.0 * ui_scale)),
            ),
        },
    })({
        drawPromptBadge(ui_scale);
        drawPromptActionText(interactable.action_text, ui_scale);
    });
}

fn drawPromptBadge(ui_scale: f32) void {
    const is_gamepad = DevicePrompts.isGamepad();
    const prompt = DevicePrompts.getActionPrompt(.interact);

    ui.new(.{
        .id = .ID("interaction-prompt-key-badge"),
        .background_color = prompt.badge_background_color,
        .corner_radius = .all(if (is_gamepad) 2.0 * ui_scale else 1.0 * ui_scale),
        .border = .{
            .color = prompt.badge_border_color,
            .width = .outside(1),
        },
        .layout = .{
            .padding = .axes(
                lm.tou16(@round(0.5 * ui_scale)),
                lm.tou16(@round(if (is_gamepad) 1.75 * ui_scale else 1.5 * ui_scale)),
            ),
            .child_alignment = .{ .x = .center, .y = .center },
        },
    })({
        ui.text(prompt.label, .{
            .color = prompt.text_color,
            .font_size = theme.scaledU16(3.25, 6, ui_scale),
            .letter_spacing = 1,
            .font_id = theme.boldFontId(),
        });
    });
}

fn drawPromptActionText(action_text: []const u8, ui_scale: f32) void {
    ui.new(.{
        .id = .ID("interaction-prompt-action-text"),
    })({
        ui.text(action_text, .{
            .color = color_scheme.text_primary,
            .font_size = theme.scaledU16(3.25, 6, ui_scale),
            .letter_spacing = 1,
            .font_id = theme.regularFontId(),
        });
    });
}
