from .base import *
from . import assets

import pygame._sdl2.controller as pycontroller
import time


SETTINGS: Optional[ApplicationSettings] = None
RUN: bool = True
SCREEN: Optional[Screen]
CLOCK: Optional[pygame.time.Clock]
TIME: Time = Time(0.016, time.perf_counter())
CAMERA: Camera = Camera(Vec2(1000), 1)
CONTROLLERS: list[pycontroller.Controller] = []
NEXT_CAMERA_POS: Optional[Vec2] = None
MOUSE_POSITION: Vec2 = Vec2()
LAST_MOUSE_POSITION: Vec2 = Vec2()
GUI_PIXEL_RATIO = 1


fps_list = []
last_fps = time.perf_counter()


def use(settings: ApplicationSettings):
    global SETTINGS, SCREEN, CLOCK, CAMERA, GUI_PIXEL_RATIO

    if settings.max_fps > 240:
        settings.max_fps = 240

    SETTINGS = settings

    SCREEN = Screen(
        this=None, size=SETTINGS.screen_size, flags=(pygame.SCALED), vsync=False
    )
    set_screen_mode()

    CLOCK = pygame.time.Clock()

    pygame.display.set_caption(settings.application_name)

    pygame.transform.set_smoothscale_backend(settings.sprite_scaling)

    if settings.icon is not None:
        pygame.display.set_icon(assets.use(settings.icon))

    if settings.camera is not None:
        CAMERA = settings.camera

    if settings.move_keys is None:
        SETTINGS.move_keys = [["a", "d"], ["w", "s"]]

    pygame.key.set_repeat(SETTINGS.key_repeat)

    
    GUI_PIXEL_RATIO = SCREEN.size.y / 1080


def system_camera() -> None:
    if NEXT_CAMERA_POS is None:
        return

    CAMERA.position.x = NEXT_CAMERA_POS.x
    CAMERA.position.y = NEXT_CAMERA_POS.y


def set_screen_mode() -> None:
    SCREEN.this = pygame.display.set_mode(
        size=(SCREEN.size.x, SCREEN.size.y),
        flags=SCREEN.flags,
        vsync=1 if SCREEN.vsync else 0,
    )


def set_screen_flags(to: int) -> None:
    SCREEN.flags = to
    set_screen_mode()


def set_screen_size(to: Vec2):
    SCREEN.size = to
    set_screen_mode()


def get_screen_size() -> Vec2:
    return SCREEN.size


def get_camera() -> Camera:
    return CAMERA if not SETTINGS.camera else SETTINGS.camera


def move_camera(to: Vec2) -> None:
    global NEXT_CAMERA_POS
    NEXT_CAMERA_POS = to


def get_fps() -> Optional[float]:
    if len(fps_list) < 2:
        return
    return sum(fps_list) / len(fps_list)


def as_menu() -> None:
    if SETTINGS is None:
        return

    SETTINGS.menu_mode = True


def use_background(surf: Surface, size: Optional[Vec2] = None) -> None:
    if size is not None:
        surf = pygame.transform.scale(surf, (size.x, size.y))
    
    SETTINGS.background_image = surf

    SETTINGS.background_size = Vec2(surf.get_width(), surf.get_height())


def end() -> Never:
    global RUN
    RUN = False
    