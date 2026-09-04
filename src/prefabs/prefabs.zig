pub const Player = @import("Player.zig").Player;
pub const Background = @import("Background.zig").Background;
pub const enemies = struct {
    pub const Basic = @import("enemies/Basic.zig").BasicEnemy;
};
pub const items = struct {
    pub const ExperienceOrb = @import("items/ExperienceOrb.zig").ExperienceOrb;
};
