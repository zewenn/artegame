from events import Events

# Importing scripts, so they can run
from src.imports import *

import assets
import render
import pgapi
from repulse import Collision
import items
from classes import *
from animator import animator
from input_handler import Input
import saves
import pygame
import pygame._sdl2.controller as pycontroller
from scenenum import SCENES


def init():
    # Setting up pygame
    pygame.init()
    pycontroller.init()
    pygame.mixer.init()

    assets.create_runtime_objects()

    pgapi.use(
        ApplicationSettings(
            application_name="Artegame - v1.1",
            screen_size=(1600, 720),
            max_fps=240,
            vsync=0,
            icon="neunyx32x32.png",
            camera=Camera(Vector2(0, 0), 1),
            is_demo=True,
            # axis_rounding=10
        )
    )

    Input.init_controllers()
    Input.bind_buttons("exit", ["escape", "x@ctrl#0"])

    SCENES.default.load()
    Events.call(Events.ids.awake)
    Events.call(Events.ids.initalise)

    while pgapi.RUN:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pgapi.RUN = False

        # Demo exit
        if Input.active_bind("exit"):
            pgapi.RUN = False

        pgapi.SCREEN.fill("black")

        Events.system_update()
        animator.tick_anims()
        Collision.repulse()

        pgapi.system_update_camera()

        render.render()
        pygame.display.flip()
        pgapi.TIME.deltatime = pgapi.CLOCK.tick(pgapi.SETTINGS.max_fps) / 1000
        pgapi.TIME.current = pgapi.time.perf_counter()

    pygame.quit()
    saves.save()


if __name__ == "__main__":
    init()
