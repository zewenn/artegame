const lm = @import("loom");
const std = @import("std");

pub fn main() !void {
    lm.project(.{
        .window = .{
            .title = "artegame",
            .resizable = true,
            .restore_state = true,
            .size = .init(1280, 720),
        },
        .asset_paths = .{
            .debug = "src/assets/",
        },
    })({
        lm.scene("default")({
            std.debug.print("Hello World!", .{});
        });
    });
}
