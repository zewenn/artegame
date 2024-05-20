from dataclasses import dataclass
from zenyx import Pipe
from result import *
from typing import *
from enums.gui import *


@dataclass
class Vector2:
    """
    Args:
        x (float): horizontal position
        y (float): vertical position
        direction (float): vector direction
    """

    x: float = 0
    y: float = 0


@dataclass
class Vector3:
    x: float = 0
    y: float = 0
    z: float = 0
    direction: float = 0


@dataclass
class Transform:
    position: Vector2
    rotation: Vector3
    scale: Vector2


@dataclass
class Crop:
    start: Vector2
    end: Vector2


@dataclass
class Bone:
    transform: Optional[Transform] = None
    anchor: Optional[Vector2] = None
    sprite: Optional[str] = None
    fill_color: Optional[list[int] | tuple[int]] = None


@dataclass
class Weapon:
    damage: int
    damage_area: Vector2


@dataclass
class Collider:
    transform: Transform
    trigger: bool = False


@dataclass
class Distances:
    left: float = 0
    right: float = 0
    top: float = 0
    bottom: float = 0


@dataclass
class Item:
    # Item identty
    id: str
    tags: Optional[list[str]] = None

    # Transforms
    transform: Optional[Transform] = None
    bones: Optional[dict[str, Bone]] = None

    # Shiny render
    render: bool = True
    sprite: Optional[str] = None
    crop: Optional[Crop] = None
    fill_color: Optional[list[int] | tuple[int]] = None

    # Movement
    can_move: Optional[bool] = None
    base_movement_speed: Optional[int | float] = None
    movement_speed: Optional[int] = None
    # |> Movement -> Dashes
    dash_movement_multiplier: Optional[int] = None
    dash_count: Optional[int] = None
    dashes_remaining: Optional[int] = None
    """@runtime"""
    # |> Movement -> Dashes -> Cooldown Management
    dash_charge_refill_time: Optional[float] = None
    last_dash_charge_refill: Optional[int] = None
    """@runtime"""

    # Inventory
    inventory: Optional[dict[str, Weapon | int]] = None

    # Collision
    can_collide: bool = False
    can_repulse: bool = False
    lightness: int = 1
    trigger_collider: bool = False
    # colliders: Optional[list[Collider]] = None


@dataclass
class Dasher:
    this: Item
    towards: "CompleteMathVector"
    speed_multiplier: float
    time: float
    start_time: float


# ------------------------- Camera System -------------------------


@dataclass
class Camera:
    position: Optional[Vector2] = None
    pixel_unit_ratio: Optional[int] = None


# ---------------------------- Api Data ---------------------------


@dataclass
class ApplicationSettings:
    screen_size: tuple[int]
    is_demo: bool = False
    max_fps: int = 240
    vsync: int = 0
    application_name: str = "fyne"
    icon: Optional[str] = None
    camera: Optional[Camera] = None
    axis_rounding: Optional[int] = 20000
    move_keys: list[list[str], list[str]] = None
    key_repeat: int = 1000000
    scaling: str = "GENERIC"
    save_path: str = "~/artegame"
    demo_save_path: str = "./@artegame-demo-saves"


@dataclass
class Time:
    deltatime: float
    current: float


# ---------------------- Anims and Keyframes ----------------------


@dataclass
class Keyframe:
    # Transform
    position_x: Optional[float] = None
    position_y: Optional[float] = None
    rotation_x: Optional[float] = None
    rotation_y: Optional[float] = None
    rotation_z: Optional[float] = None
    width: Optional[float] = None
    height: Optional[float] = None
    anchor_x: Optional[float] = None
    anchor_y: Optional[float] = None

    sprite: Optional[str] = None
    fill_color: Optional[list[int] | tuple[int]] = None


@dataclass
class Animation:
    target: str
    keyframes: Optional[dict[int, Keyframe]] = None
    length: int = 1000


@dataclass
class AnimationGroup:
    """
    mode:
    - 0 is normal
    - 1 is forwards
    """

    lenght: float = 1
    mode: int = 0
    timing_function: int = 0
    animations: Optional[list[Animation]] = None


@dataclass
class ExpandedAnim:
    start_time: float
    end_time_multipliers: list[float]
    anim: Animation
    keyframe_list: list[Keyframe]
    finished: bool = False
    current_keyframe: int = 0
    end_time: float = 0.001
    duration: float = 0.001


# ---------------------- Maths & Physics ----------------------


@dataclass
class IncompleteMathVector:
    """Incomplete Math Vector. Some attributes might be none. \n
    Make sure to covert it into a `CompleteMathVector`!
    """

    start: Optional[Vector2] = None
    end: Optional[Vector2] = None
    delta: Optional[Vector2] = None
    direction: Optional[float] = None
    magnitude: Optional[float] = None


@dataclass
class CompleteMathVector:
    """A Complete Math Vector. It has every attribute,
    so you can be sure whatever you are trying to access is there
    """

    start: Vector2
    end: Vector2
    delta: Vector2
    direction: float
    magnitude: float


# --------------------------- Events --------------------------


@dataclass
class Event:
    id: str
    callback: Callable


# --------------------------- Saves ---------------------------


@dataclass
class Moment:
    items: list[Item]


# --------------------------- sdtlib --------------------------


class Mishap:
    def __init__(self, msg: str, fatal: bool = False) -> None:
        self.msg: str = f"{'FATAL' if fatal else 'NONFATAL'} :: {msg}"

    def is_fatal(self) -> bool:
        if self.msg.startswith("FATAL"):
            return True
        return False


# ----------------------------- ui ----------------------------


@dataclass
class StyleSheet:
    position: str = POSITION.ABSOLUTE

    bottom: str = "0x"
    right: str = "0x"
    left: str = "0x"
    top: str = "0x"

    width: str = "0x"
    height: str = "0x"

    bg_color: Tuple[int, int, int, int] = (0, 0, 0, 0)
    bg_image: str = None

    color: Tuple[int, int, int, int] = (0, 0, 0, 1)
    font: str = "press_play.ttf"
    font_size: str = FONT_SIZE.EXTRA_SMALL


@dataclass
class GUIElement:
    id: str
    children: list["GUIElement"]
    style: StyleSheet
