from events import Events

# Importing scripts, so they can run
from src.imports import *

import files as files, render
import pgapi
from repulse import Collision
from entities import *
from classes import *
from animator import animator
from input_handler import Input
import pygame
import pygame._sdl2.controller as pycontroller
from saves import Loader


def init():
    # Setting up pygame
    pygame.init()
    pycontroller.init()
    pygame.mixer.init()

    files.init()

    pgapi.use(
        ApplicationSettings(
            application_name="Artegame - v1.1",
            screen_size=(1600, 720),
            max_fps=240,
            vsync=0,
            icon="neunyx32x32.png",
            camera=Camera(Vector2(1000, 0), 1.05),
        )
    )
    Input.init_controllers()
    Input.bind_buttons("exit", ["escape", "x@ctrl#0"])

    # pgapi.Debugger.start()
    # Currently loading objects from test_load.py
    # zenyx implementation coming later
    # load.load()
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

        render.render()
        pygame.display.flip()
        pgapi.TIME.deltatime = pgapi.CLOCK.tick(pgapi.SETTINGS.max_fps) / 1000

        # pgapi.Debugger.update()

    pygame.quit()
    # pgapi.Debugger.quit()
    Loader.save()


if __name__ == "__main__":
    init()
