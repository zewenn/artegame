const std = @import("std");
const lm = @import("loom");
const ui = lm.ui;

const AudioManager = @import("../audio/AudioManager.zig");
const DevicePrompts = @import("../input/DevicePrompts.zig");
const theme = @import("theme.zig");
const color_scheme = @import("color_scheme.zig");

/// Direction produced when a latched gamepad stick axis crosses the activation threshold.
pub const StickDirection = enum {
    none,
    negative,
    positive,
};

/// Normalized menu navigation inputs sampled from keyboard and gamepad for the current frame.
pub const MenuInput = struct {
    navigate_up: bool = false,
    navigate_down: bool = false,
    navigate_left: bool = false,
    navigate_right: bool = false,
    select_pressed: bool = false,
    back_pressed: bool = false,
    tab_previous: bool = false,
    tab_next: bool = false,
};

/// Shared selection, stick-latching, and open-frame guard state for menu screens.
pub const NavigationState = struct {
    selected_index: usize = 0,
    previous_selected_index: usize = 0,
    stick_moved_x: bool = false,
    stick_moved_y: bool = false,
    just_opened: bool = false,

    /// Resets selection indices and stick latches, optionally arming the first-frame open guard.
    pub fn reset(self: *NavigationState, mark_just_opened: bool) void {
        self.selected_index = 0;
        self.previous_selected_index = 0;
        self.stick_moved_x = false;
        self.stick_moved_y = false;
        self.just_opened = mark_just_opened;
    }

    /// Consumes the first-frame open guard and returns true when input should be skipped this frame.
    pub fn consumeJustOpened(self: *NavigationState) bool {
        if (!self.just_opened) return false;
        self.just_opened = false;
        return true;
    }

    /// Updates and returns the latched horizontal stick direction.
    pub fn readHorizontalStick(self: *NavigationState, stick_x: f32) StickDirection {
        return updateStickAxis(stick_x, &self.stick_moved_x);
    }

    /// Updates and returns the latched vertical stick direction.
    pub fn readVerticalStick(self: *NavigationState, stick_y: f32) StickDirection {
        return updateStickAxis(stick_y, &self.stick_moved_y);
    }

    /// Samples keyboard and latched gamepad navigation inputs for the current frame.
    pub fn readMenuInput(self: *NavigationState) MenuInput {
        var input = readKeyboardInput();
        if (!lm.gamepad.isAvailable(0)) return input;
        self.applyGamepadInput(&input);
        return input;
    }

    /// Updates `selected_index` vertically across `item_count` items with wraparound.
    pub fn applyVerticalNavigation(self: *NavigationState, input: MenuInput, item_count: usize) void {
        if (item_count == 0) return;
        const maximum_index = item_count - 1;
        if (input.navigate_up) {
            self.selected_index = if (self.selected_index == 0) maximum_index else self.selected_index - 1;
        }
        if (input.navigate_down) {
            self.selected_index = if (self.selected_index >= maximum_index) 0 else self.selected_index + 1;
        }
    }

    /// Plays selection change click audio when `selected_index` differs from `previous_selected_index`.
    pub fn syncSelectionAudio(self: *NavigationState) void {
        if (playSelectionChangeAudio(self.selected_index, self.previous_selected_index)) {
            self.previous_selected_index = self.selected_index;
        }
    }

    fn applyGamepadInput(self: *NavigationState, input: *MenuInput) void {
        input.navigate_up = input.navigate_up or lm.gamepad.getButtonDown(0, .left_face_up);
        input.navigate_down = input.navigate_down or lm.gamepad.getButtonDown(0, .left_face_down);
        input.navigate_left = input.navigate_left or lm.gamepad.getButtonDown(0, .left_face_left);
        input.navigate_right = input.navigate_right or lm.gamepad.getButtonDown(0, .left_face_right);
        input.select_pressed = input.select_pressed or lm.gamepad.getButtonDown(0, .right_face_down);
        input.back_pressed = input.back_pressed or
            lm.gamepad.getButtonDown(0, .right_face_right) or
            lm.gamepad.getButtonDown(0, .middle_right) or
            lm.gamepad.getButtonDown(0, .middle);
        input.tab_previous = input.tab_previous or lm.gamepad.getButtonDown(0, .left_trigger_1);
        input.tab_next = input.tab_next or lm.gamepad.getButtonDown(0, .right_trigger_1);

        const stick_vector = lm.gamepad.getStickVector(0, .left, 0.2);
        switch (self.readVerticalStick(stick_vector.y)) {
            .negative => input.navigate_up = true,
            .positive => input.navigate_down = true,
            .none => {},
        }
        switch (self.readHorizontalStick(stick_vector.x)) {
            .negative => input.navigate_left = true,
            .positive => input.navigate_right = true,
            .none => {},
        }
    }
};

fn readKeyboardInput() MenuInput {
    return .{
        .navigate_up = lm.keyboard.getKeyDown(.up) or lm.keyboard.getKeyDown(.w),
        .navigate_down = lm.keyboard.getKeyDown(.down) or lm.keyboard.getKeyDown(.s),
        .navigate_left = lm.keyboard.getKeyDown(.left) or lm.keyboard.getKeyDown(.a),
        .navigate_right = lm.keyboard.getKeyDown(.right) or lm.keyboard.getKeyDown(.d),
        .select_pressed = lm.keyboard.getKeyDown(.enter),
        .back_pressed = lm.keyboard.getKeyDown(.escape),
        .tab_previous = lm.keyboard.getKeyDown(.q),
        .tab_next = lm.keyboard.getKeyDown(.e) or lm.keyboard.getKeyDown(.tab),
    };
}

/// Applies deadzone hysteresis (< 0.2 resets, > 0.5 triggers once) to an analog stick axis.
pub fn updateStickAxis(axis_value: f32, stick_moved: *bool) StickDirection {
    if (@abs(axis_value) < 0.2) {
        stick_moved.* = false;
        return .none;
    }
    if (@abs(axis_value) <= 0.5 or stick_moved.*) {
        return .none;
    }

    stick_moved.* = true;
    return if (axis_value > 0.0) .positive else .negative;
}

/// Plays the menu selection click SFX when `selected_index` changes, returning true if played.
pub fn playSelectionChangeAudio(selected_index: usize, previous_selected_index: usize) bool {
    if (selected_index == previous_selected_index) return false;
    AudioManager.playSfxPitched("audio/sfx/click.wav", 0.35, 0.1);
    return true;
}

/// Renders a device-aware navigation footer hint row.
pub fn drawFooterHint(
    comptime container_id: []const u8,
    gamepad_hint: []const u8,
    keyboard_hint: []const u8,
    ui_scale: f32,
) void {
    ui.new(.{
        .id = .ID(container_id),
        .layout = .{ .child_alignment = .{ .x = .center } },
    })({
        const footer_text = if (DevicePrompts.isGamepad()) gamepad_hint else keyboard_hint;
        ui.text(footer_text, .{
            .color = color_scheme.text_footer,
            .font_size = theme.scaledU16(2.75, 5, ui_scale),
            .letter_spacing = 1,
            .alignment = .center,
            .font_id = theme.regularFontId(),
        });
    });
}

test "menu_navigation updateStickAxis hysteresis latches until deadzone release" {
    var stick_moved = false;

    try std.testing.expectEqual(StickDirection.none, updateStickAxis(0.3, &stick_moved));
    try std.testing.expect(!stick_moved);

    try std.testing.expectEqual(StickDirection.positive, updateStickAxis(0.6, &stick_moved));
    try std.testing.expect(stick_moved);

    try std.testing.expectEqual(StickDirection.none, updateStickAxis(0.8, &stick_moved));
    try std.testing.expectEqual(StickDirection.none, updateStickAxis(0.25, &stick_moved));
    try std.testing.expect(stick_moved);

    try std.testing.expectEqual(StickDirection.none, updateStickAxis(0.1, &stick_moved));
    try std.testing.expect(!stick_moved);

    try std.testing.expectEqual(StickDirection.negative, updateStickAxis(-0.7, &stick_moved));
    try std.testing.expect(stick_moved);
}

test "menu_navigation NavigationState consumeJustOpened and applyVerticalNavigation" {
    var state: NavigationState = .{};
    state.reset(true);

    try std.testing.expect(state.consumeJustOpened());
    try std.testing.expect(!state.consumeJustOpened());

    state.applyVerticalNavigation(.{ .navigate_up = true }, 3);
    try std.testing.expectEqual(@as(usize, 2), state.selected_index);

    state.applyVerticalNavigation(.{ .navigate_down = true }, 3);
    try std.testing.expectEqual(@as(usize, 0), state.selected_index);
}
