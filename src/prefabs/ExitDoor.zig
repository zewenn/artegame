const std = @import("std");
const lm = @import("loom");

const Interactable = @import("../components/interaction/Interactable.zig");
const Door = @import("../components/world/Door.zig");
const RoomManager = @import("../global/RoomManager.zig");

pub const RewardKind = Door.RewardKind;
pub const DoorConfig = Door.DoorConfig;

pub fn ExitDoor(position: lm.Vector2, config: DoorConfig) !*lm.Entity {
    const door_index_u32 = @as(u32, @intCast(config.door_index));

    return try lm.makeEntityI("exit-door", door_index_u32, .{
        lm.Transform{
            .position = .init(position.x, position.y, 0),
            .scale = .init(96, 96),
        },
        lm.Renderer.sprite("ui/icons/empty_icon.png"),
        lm.RectangleCollider.initConfig(.{
            .type = .static,
            .transform = .{
                .scale = .init(48, 48),
            },
        }),
        Interactable{
            .action_text = "Enter Next Room",
            .interaction_radius = 110.0,
            .prompt_offset = .init(0, -64.0),
            .can_interact = RoomManager.isReplenish,
            .on_interact = Door.onDoorInteract,
        },
        Door{
            .door_index = config.door_index,
            .category_id = config.category_id,
            .reward_title = config.title,
            .reward_icon = config.icon,
            .reward_kind = config.reward_kind,
            .is_open = config.is_open,
        },
    });
}
