const lm = @import("loom");

const SaveSystem = @import("save/SaveSystem.zig");

pub fn Awake() !void {
    SaveSystem.init();
    try lm.loadScene("main_menu");
}
