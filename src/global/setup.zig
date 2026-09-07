const std = @import("std");
const lm = @import("loom");

const Player = @import("../prefabs/Player.zig").Player;
const Anchor = @import("../prefabs/Anchor.zig").Anchor;
const BasicEnemy = @import("../prefabs/enemies/Basic.zig").BasicEnemy;
const Projectile = @import("../prefabs/Projectile.zig").Projectile;
const Background = @import("../prefabs/Background.zig").Background;
const SaveSystem = @import("save/SaveSystem.zig");

pub fn Awake() !void {
    SaveSystem.init();
    try lm.loadScene("main_menu");
}
