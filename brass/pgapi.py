from base import *

import pygame._sdl2.controller as pycontroller
import assets
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

fps_list = []
last_fps = time.perf_counter()


def use(settings: ApplicationSettings):
    global SETTINGS, SCREEN, CLOCK, CAMERA, CONTROLLERS

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


def system_camera() -> None:
    global NEXT_CAMERA_POS

    if NEXT_CAMERA_POS is None:
        return

    CAMERA.position.x = NEXT_CAMERA_POS.x
    CAMERA.position.y = NEXT_CAMERA_POS.y


def set_screen_mode() -> None:
    global SCREEN

    SCREEN.this = pygame.display.set_mode(
        size=(SCREEN.size.x, SCREEN.size.y),
        flags=SCREEN.flags,
        vsync=1 if SCREEN.vsync else 0,
    )


def set_screen_flags(to: int) -> None:
    global SCREEN

    SCREEN.flags = to
    set_screen_mode()


def set_screen_size(to: Vec2):
    global SCREEN

    SCREEN.size = to
    set_screen_mode()


def get_screen_size() -> Vec2:
    global SCREEN
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
    global SETTINGS
    SETTINGS.menu_mode = True

def exit() -> Never:
    global RUN
    RUN = False