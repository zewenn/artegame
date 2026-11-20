pub const Player = @import("Player.zig").Player;
pub const ExitDoor = @import("ExitDoor.zig").ExitDoor;
pub const enemies = struct {
    pub const Melee = @import("enemies/Melee.zig").MeleeEnemy;
    pub const Ranged = @import("enemies/Ranged.zig").RangedEnemy;
    pub const Elite = @import("enemies/Elite.zig").EliteEnemy;
    pub const TrainingDummy = @import("enemies/TrainingDummy.zig").TrainingDummy;
    pub const Knight = @import("enemies/Knight.zig").KnightEnemy;
    pub const Bishop = @import("enemies/Bishop.zig").BishopEnemy;
    pub const Shaman = @import("enemies/Shaman.zig").ShamanEnemy;
    pub const Magician = @import("enemies/Magician.zig").MagicianEnemy;
    pub const Lifeliner = @import("enemies/Lifeliner.zig").LifelinerEnemy;
    pub const Angler = @import("enemies/Angler.zig").AnglerEnemy;
    pub const Tank = @import("enemies/Tank.zig").TankEnemy;
    pub const King = @import("enemies/King.zig").KingEnemy;
    pub const Queen = @import("enemies/Queen.zig").QueenEnemy;
};
pub const items = struct {
    pub const ExperienceOrb = @import("items/ExperienceOrb.zig").ExperienceOrb;
    pub const BoonDrop = @import("items/BoonDrop.zig").BoonDrop;
};
pub const modules = struct {
    pub const ExitDoor = @import("ExitDoor.zig");
    pub const Player = @import("Player.zig");
    pub const Projectile = @import("Projectile.zig");
    pub const enemies = struct {
        pub const Angler = @import("enemies/Angler.zig");
        pub const Bishop = @import("enemies/Bishop.zig");
        pub const Elite = @import("enemies/Elite.zig");
        pub const King = @import("enemies/King.zig");
        pub const Knight = @import("enemies/Knight.zig");
        pub const Lifeliner = @import("enemies/Lifeliner.zig");
        pub const Magician = @import("enemies/Magician.zig");
        pub const Melee = @import("enemies/Melee.zig");
        pub const Queen = @import("enemies/Queen.zig");
        pub const Ranged = @import("enemies/Ranged.zig");
        pub const Shaman = @import("enemies/Shaman.zig");
        pub const Tank = @import("enemies/Tank.zig");
        pub const TrainingDummy = @import("enemies/TrainingDummy.zig");
    };
    pub const items = struct {
        pub const BoonDrop = @import("items/BoonDrop.zig");
        pub const ExperienceOrb = @import("items/ExperienceOrb.zig");
    };
};
