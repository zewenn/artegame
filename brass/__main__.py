from events import Events

# Importing scripts, so they can run
from src.script_import import *

from zenyx import printf
import img, render
import load
import pgapi
from entities import *
from classes import *
from animator import Animator
from input import Input
import pygame, keyboard
import pygame._sdl2.controller as pycontroller
import os
from saves import Loader


def init():
    # Setting up pygame
    pygame.init()
    pycontroller.init()

    img.init()

    pgapi.use(
        ApplicationSettings(
            screen_size=(1600, 720),
            max_fps=3000,
            vsync=0,
            icon="neunyx32x32.png",
            camera=Camera(Vector2(0, 0), 1.05),
        )
    )
    Input.init_controllers()
    Input.bind_buttons("exit", ["escape", "x@ctrl#0"])

    pgapi.Debugger.start()
    # Currently loading objects from test_load.py
    # zenyx implementation coming later

    # load.load()
    Events.awake()
    Events.init()

    while pgapi.RUN:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                Loader.save()
                pgapi.RUN = False

        # Demo exit
        if Input.active_bind("exit"):
            Loader.save()
            pgapi.RUN = False

        pgapi.SCREEN.fill("black")

        Events.update()
        Animator.tick_anims()

        render.render()
        pygame.display.flip()
        pgapi.TIME.deltatime = pgapi.CLOCK.tick(pgapi.SETTINGS.max_fps) / 1000

        pgapi.Debugger.update()

    pygame.quit()
    pgapi.Debugger.quit()


if __name__ == "__main__":
    init()
