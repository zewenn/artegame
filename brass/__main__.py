from base import *


# Importing scripts, so they can run
import enums.scenes
from src.imports import *

import events
import assets
import render
import pgapi
import collision
import gui
import animator
import inpt
import saves
import pygame
import pygame._sdl2.controller as pycontroller
import scene
import enums


def init():
    # Setting up pygame
    pygame.init()
    pycontroller.init()
    pygame.mixer.init()

    assets.create_runtime_objects()

    pgapi.use(
        ApplicationSettings(
            application_name="Artegame - v1.1",
            screen_size=Vector2(1600, 900),
            max_fps=240,
            vsync=0,
            icon="neunyx32x32.png",
            camera=Camera(Vector2(0, 0), 1),
            is_demo=True,
            # axis_rounding=10
        )
    )
    # pgapi.set_screen_flags(pygame.NOFRAME | pygame.SCALED)

    inpt.init_controllers()

    inpt.bind_buttons("exit", ["escape", "back@ctrl#0"])

    scene.load(enums.scenes.DEFAULT)
    events.call(events.IDS.awake)
    events.call(events.IDS.init)

    while pgapi.RUN:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pgapi.RUN = False

        # Demo exit
        if inpt.active_bind("exit"):
            pgapi.RUN = False

        pgapi.SCREEN.this.fill("black")
        gui.system_update()

        events.system_update()
        animator.tick_anims()
        collision.system_update()

        pgapi.system_camera()

        render.render()
        pygame.display.flip()
        pgapi.TIME.deltatime = pgapi.CLOCK.tick(pgapi.SETTINGS.max_fps) / 1000
        pgapi.TIME.current = pgapi.time.perf_counter()

    pygame.quit()
    saves.save()


if __name__ == "__main__":
    init()
