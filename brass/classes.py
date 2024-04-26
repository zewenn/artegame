from dataclasses import dataclass
import math
from typing import Optional


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
    transform: Transform | None = None
    anchor: Vector2 | None = None
    sprite: str | None = None
    fill_color: list[int] | tuple[int] | None = None


@dataclass
class Item:
    # Item identty
    id: str
    tags: Optional[list[str]] = None

    # Transforms
    transform: Transform | None = None
    bones: dict[str, Bone] | None = None

    # Shiny render
    sprite: str | None = None
    crop: Crop | None = None
    fill_color: list[int] | tuple[int] | None = None

    # Movement
    can_move: bool | None = None
    movement_speed: int | None = None


# ------------------------- Camera System -------------------------


@dataclass
class Camera:
    position: Vector2 | None = None
    pixel_unit_ratio: int | None = None


# ---------------------------- Api Data ---------------------------


@dataclass
class ApplicationSettings:
    screen_size: tuple[int]
    max_fps: int
    vsync: int = 0
    application_name: str = "fyne"
    icon: str | None = None
    camera: Camera | None = None
    axis_rounding: int | None = 500
    move_keys: list[list[str], list[str]] = None
    key_repeat: int = 1000000
    scaling: str = "GENERIC"


@dataclass
class Time:
    deltatime: float


# ---------------------- Anims and Keyframes ----------------------


@dataclass
class Keyframe:
    # Transform
    position_x: float | None = None
    position_y: float | None = None
    rotation_x: float | None = None
    rotation_y: float | None = None
    rotation_z: float | None = None
    width: float | None = None
    height: float | None = None
    anchor_x: float | None = None
    anchor_y: float | None = None

    sprite: str | None = None
    fill_color: list[int] | tuple[int] | None = None


@dataclass
class Animation:
    target: str
    keyframes: dict[int, Keyframe] | None = None
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
    animations: list[Animation] | None = None


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

    start: Vector2 | None = None
    end: Vector2 | None = None
    delta: Vector2 | None = None
    direction: float | None = None
    magnitude: float | None = None


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
    callback: callable


# --------------------------- Saves ---------------------------


@dataclass
class Moment:
    items: list[Item]
