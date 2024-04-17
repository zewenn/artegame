
from img import surface_ref_table
from zenyx import printf
from classes import *

import pygame
import pygame._sdl2.controller as pycontroller
import time
import inspect


SETTINGS: ApplicationSettings | None
RUN: bool = True
SCREEN: pygame.Surface | None
CLOCK: pygame.time.Clock | None
TIME: Time = Time(0.016)
CAMERA: Camera = Camera(Vector2(), 1)
CONTROLLERS: list[pycontroller.Controller] = []


def use(settings: ApplicationSettings):
    global SETTINGS, SCREEN, CLOCK, CAMERA, CONTROLLERS
    SETTINGS = settings

    SCREEN = pygame.display.set_mode(
        size=SETTINGS.screen_size,
        flags=(pygame.SCALED),
        vsync=SETTINGS.vsync,
    )
    CLOCK = pygame.time.Clock()
    Application.set_caption(settings.application_name)

    pygame.transform.set_smoothscale_backend(settings.scaling)

    if settings.icon is not None:
        Application.set_icon(settings.icon)

    if settings.camera is not None:
        CAMERA = settings.camera

    if settings.move_keys is None:
        SETTINGS.move_keys = [["a", "d"], ["w", "s"]]

    pygame.key.set_repeat(SETTINGS.key_repeat)


class Application:
    fps_list = []
    last_fps = time.perf_counter()

    @staticmethod
    def get_fps():
        if len(Application.fps_list) < 2:
            return
        return sum(Application.fps_list) / len(Application.fps_list)

    @staticmethod
    def set_icon(img_name: str):
        pygame.display.set_icon(surface_ref_table[img_name])

    @staticmethod
    def set_caption(window_name: str):
        pygame.display.set_caption(window_name)


class Debugger:
    # [min, [avg, count], max]
    fps_info = [10000, [0, 0], 0]
    is_enabled: bool = False

    last_printed_cls = ""
    last_end = "\n"

    @classmethod
    def print(this, *args, **kwargs):
        if not this.is_enabled:
            return

        stack = inspect.stack()[1]
        __cls = stack.frame.f_locals.get("this")
        caller_class = ""

        if __cls is None:
            caller_class = f"<unknown>.{stack.function}"
        else:
            caller_class = __cls.__name__

        if caller_class != this.last_printed_cls:
            if this.last_end == "\r":
                printf("\n", end="")
            printf.full_line(f"{caller_class}")
            this.last_printed_cls = caller_class

        if kwargs.get("end"):
            this.last_end = kwargs.get("end")
        else:
            this.last_end = "\n"

        args = [f"@~{arg}$&" for arg in args]
        printf.full_line(f"  ", *args, **kwargs)

    @classmethod
    def print_resoult(this, func: callable):
        def wrap(*args, **kwargs):
            res = func(*args, **kwargs)
            this.print(f"{func.__qualname__}: {res}")
            return res

        return wrap

    @classmethod
    def time_this(this, func: callable):
        def wrap(*args, **kwargs):
            start = time.perf_counter()
            res = func(*args, **kwargs)
            this.print(f"{func.__qualname__} ran in {time.perf_counter() - start}s")
            return res

        return wrap

    @classmethod
    def start(this):
        this.is_enabled = True
        printf.clear_screen()

        printf("@!")
        printf.title("Debug Console", "┉")
        printf("$&")
        printf(
            "The debug console has 3 phases (Initalisation, Update Sequence, Program End), all based on runtime."
        )

        printf("@~")
        printf.title("@!Initalisation$&@~", "╴")
        printf("$&")

        this.print(f"Detected {len(CONTROLLERS)} controller(s)")
        printf("\n")

        printf("@~")
        printf.title("@!Update Sequence$&@~", "╴")
        printf("$&")

    @classmethod
    def update(this):
        if not this.is_enabled:
            return

        fps = 1 / TIME.deltatime
        Application.fps_list.append(fps)

        render_fps: int = 60
        q_fps: int = Application.get_fps()
        if q_fps is not None:
            render_fps = int(q_fps)

            if render_fps < this.fps_info[0]:
                this.fps_info[0] = render_fps

            this.fps_info[1][0] = int(
                (this.fps_info[1][0] * this.fps_info[1][1] + render_fps)
                / (this.fps_info[1][1] + 1)
            )
            if this.fps_info[1][1] < 9999:
                this.fps_info[1][1] += 1

            if render_fps > this.fps_info[2]:
                this.fps_info[2] = render_fps

        if time.perf_counter() - Application.last_fps > 1:
            this.print(
                f"FPS: {render_fps} | DeltaTime: {TIME.deltatime}     ", end="\r"
            )
            Application.fps_list = []
            Application.last_fps = time.perf_counter()

    @classmethod
    def quit(this):
        if not this.is_enabled:
            return

        printf("@~")
        printf.title("@!Program End$&@~", "╴")
        printf("$&")

        printf(
            f"FPS Info",
            f"@~   Minimum: {this.fps_info[0]}",
            f"   Average: {this.fps_info[1][0]}",
            f"   Maximum: {this.fps_info[2]}$&",
            "\n",
            sep="\n",
        )

