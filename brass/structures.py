from dataclasses import dataclass
from zenyx import Pipe
from result import *
from typing import *

import pygame


Sound = pygame.mixer.Sound
Surface = pygame.Surface
Font = pygame.font.Font
Number = int | float
string = str


@dataclass
class Vec2:
    """
    Args:
        x (float): horizontal position
        y (float): vertical position
    """

    x: float = 0
    y: float = 0


@dataclass
class Vec3:
    x: float = 0
    y: float = 0
    z: float = 0


@dataclass
class Transform:
    position: Vec2
    rotation: Vec3
    scale: Vec2


@dataclass
class Crop:
    start: Vec2
    end: Vec2


@dataclass
class Bone:
    transform: Optional[Transform] = None
    anchor: Optional[Vec2] = None
    sprite: Optional[str] = None
    fill_color: Optional[list[int] | tuple[int]] = None


@dataclass
class Weapon:
    damage: int
    damage_area: Vec2


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
    id: string
    tags: Optional[list[string]] = None
    uuid: string = None

    # Transforms
    transform: Optional[Transform] = None
    transform_cache: Optional[Transform] = None
    bones: Optional[dict[str, Bone]] = None
    facing: Number = None

    # Shiny render
    render: bool = True
    sprite: Optional[str] = None
    surface: Optional[Surface] = None
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

    # Projectiles
    is_projectile: bool = False
    lifetime_seconds: Optional[Number] = None
    life_start: Optional[Number] = None
    team: Optional[Literal["Player", "Enemy"]] = None
    projectile_damage: Optional[Number] = None

    # Combat // Alive
    max_hitpoints: Optional[Number] = None
    hitpoints: Optional[Number] = None
    max_mana: Optional[Number] = None
    mana: Optional[Number] = None
    invulnerable: bool = False
    can_attack: bool = False
    dashing: bool = False



@dataclass
class Dasher:
    this: Item
    towards: "CompleteMathVector"
    speed_multiplier: float
    time: float
    start_time: float


# ------------------------- Audio System --------------------------


@dataclass
class Audio:
    sound: Sound
    volume: float
    playing: bool
    maxtimeMS: int


# ------------------------- Camera System -------------------------


@dataclass
class Camera:
    position: Optional[Vec2] = None
    pixel_unit_ratio: Optional[int] = None


# ---------------------------- Api Data ---------------------------


@dataclass
class ApplicationSettings:
    screen_size: Vec2
    is_demo: bool = False
    """
    Controls the save dir.
    - True: this.save_path
    - False: this.demo_save_path
    """
    max_fps: int = 240
    vsync: int = 0
    application_name: str = "fyne"
    icon: Optional[str] = None
    camera: Optional[Camera] = None
    axis_rounding: Optional[int] = 20000
    move_keys: list[list[str], list[str]] = None
    key_repeat: int = 1000000
    sprite_scaling: Literal["GENERIC"] = "GENERIC"
    save_path: str = "~/artegame"
    demo_save_path: str = "./@artegame-demo-saves"
    menu_mode: bool = False
    """
    If enabled dpad jumps between menupoints
    """
    input_mode: Literal["Controller", "MouseAndKeyboard"] = "MouseAndKeyboard"
    background_image: Surface = None


@dataclass
class Time:
    deltatime: float
    current: float


@dataclass
class Screen:
    this: pygame.Surface
    size: Vec2
    flags: int
    vsync: bool


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

    id: string
    length: float = 1
    mode: Literal["Normal", "Forwards"] = "Normal"
    timing_function: Callable[[Number, Number, Number], Number] = None
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


@dataclass
class PlayObject:
    group: AnimationGroup
    anims: list[ExpandedAnim]
    finished: bool


# ---------------------- Maths & Physics ----------------------


@dataclass
class IncompleteMathVector:
    """Incomplete Math Vector. Some attributes might be none. \n
    Make sure to covert it into a `CompleteMathVector`!
    """

    start: Optional[Vec2] = None
    end: Optional[Vec2] = None
    delta: Optional[Vec2] = None
    direction: Optional[float] = None
    magnitude: Optional[float] = None


@dataclass
class CompleteMathVector:
    """A Complete Math Vector. It has every attribute,
    so you can be sure whatever you are trying to access is there
    """

    start: Vec2
    end: Vec2
    delta: Vec2
    direction: float
    magnitude: float


# --------------------------- Events --------------------------


@dataclass
class Event:
    id: str
    callback: Callable


# --------------------------- sdtlib --------------------------


class Mishap:
    def __init__(self, msg: str, fatal: bool = False) -> None:
        self.msg: str = msg
        self.fatal = fatal

    def is_fatal(self) -> bool:
        return self.fatal


# ----------------------------- ui ----------------------------


@dataclass
class StyleSheet:
    display: Literal["block", "none"] = None
    position: Literal["absolute", "relative"] = None

    bottom: str = None
    right: str = None
    left: str = None
    top: str = None

    width: str = None
    height: str = None

    bg_color: Tuple[int, int, int, int] = None
    bg_image: str = None

    color: Tuple[int, int, int, int] = None
    font_family: str = None
    font_size: str = None
    font_variant: list[Literal["bold", "italic"]] = None
    gap: str = None


@dataclass
class GUIElement:
    id: str
    children: list["GUIElement"]
    style: StyleSheet
    hover: StyleSheet = None
    current_style: StyleSheet = None
    parent: Optional["GUIElement"] = None
    onclick: Optional[Callable[[], None]] = None
    transform: Optional[Transform] = None
    button: bool = False


Colour = Tuple[int, int, int, float]
