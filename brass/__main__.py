from base import *


# Importing scripts, so they can run
import enums
from src.imports import *

import pygame
import pygame._sdl2.controller
import events
import assets
import display
import pgapi
import collision
import gui
import animator
import inpt
import saves
import scene
import enums
import screeninfo


def init():
    # Setting up pygame
    pygame.init()
    pycontroller.init()
    pygame.mixer.init()


    monitor = screeninfo.get_monitors()[0]

    SCREEN_SIZE = Vec2(1600, 900)
    # SCREEN_SIZE = Vec2(monitor.width, monitor.height)
    UI_RATIO = SCREEN_SIZE.y / 1080

    assets.create_runtime_objects(UI_RATIO)

    pgapi.use(
        ApplicationSettings(
            application_name=f"Artegame - DEMO",
            screen_size=SCREEN_SIZE,
            # screen_size=Vec2(monitor.width, monitor.height),
            # screen_size=Vec2(1920, 1080),
            max_fps=240,
            vsync=1,
            icon="neunyx32x32.png",
            camera=Camera(Vec2(0, 0), 1),
            is_demo=True,
            # skip_title_screen=True,
            axis_rounding=12500
            # axis_rounding=10
        )
    )

    pgapi.set_screen_flags(pygame.NOFRAME | pygame.SCALED | pygame.DOUBLEBUF)
    # pgapi.set_screen_flags(pygame.FULLSCREEN | pygame.SCALED | pygame.DOUBLEBUF)

    inpt.init_controllers()

    inpt.bind_buttons(enums.keybinds.SHOW_PAUSE_MENU, [{"escape"}, {"start@ctrl#0"}], "down")
    inpt.bind_buttons(enums.keybinds.ACCEPT_MENU, [{"enter"}, {"a@ctrl#0"}], "down")
    inpt.bind_buttons(enums.keybinds.BACK, [{"escape"}, {"b@ctrl#0"}], "down")
    inpt.bind_buttons("exit", [{"left shift", "escape"}])

    events.call(events.IDS.awake)
    if not pgapi.SETTINGS.skip_title_screen:
        scene.load(enums.scenes.DEFAULT)
    else:
        scene.load(enums.scenes.GAME)
    events.call(events.IDS.init)

    while pgapi.RUN:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pgapi.RUN = False

        # DO NOT SWITCH THESE UP
        # I JUST SUFFERED FOR 1.5 HOURS TRYING TO FIX THIS SH*T
        # INPT -> GUI -> EVENTS -> COLLISION
        # THERE IS NO OTHER WAY
        inpt.system_udpate()
        gui.system_update()

        events.system_update()
        collision.system_update()

        pgapi.SCREEN.this.fill("black")
        animator.tick_anims()
        pgapi.system_camera()

        display.render()

        if inpt.active_bind("exit"):
            pgapi.exit()

        pgapi.TIME.deltatime = pgapi.CLOCK.tick(pgapi.SETTINGS.max_fps) / 1000
        pgapi.TIME.current = pgapi.time.perf_counter()

    pygame.quit()
    # saves.save()


if __name__ == "__main__":
    init()
