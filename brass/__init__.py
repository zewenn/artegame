from .base import *
from . import (
    animator,
    enums,
    assets,
    audio,
    base,
    collision,
    display,
    events,
    gui,
    inpt,
    items,
    pgapi,
    saves,
    scene,
    structures,
    timeout,
    vectormath,
)
import sys


def init():
    # Setting up pygame
    # pylint: disable=no-member
    pygame.init()
    pycontroller.init()
    pygame.mixer.init()
    # pylint: enable=no-member

    SCREEN_SIZE = Vec2(1600, 900)
    ui_ratio = (SCREEN_SIZE.x / SCREEN_SIZE.y) / (1920 / 1080)

    assets.create_runtime_objects(ui_ratio)

    pgapi.use(
        ApplicationSettings(
            application_name=f"Artegame",
            screen_size=SCREEN_SIZE,
            max_fps=240,
            vsync=1,
            icon="neunyx32x32.png",
            camera=Camera(Vec2(0, 0), 1),
            axis_rounding=12500,
        )
    )

    inpt.init_controllers()

    inpt.bind_buttons(
        enums.base_keybinds.SHOW_PAUSE_MENU, [{"escape"}, {"start@ctrl#0"}], "down"
    )
    inpt.bind_buttons(
        enums.base_keybinds.ACCEPT_MENU, [{"enter"}, {"a@ctrl#0"}], "down"
    )
    inpt.bind_buttons(enums.base_keybinds.BACK, [{"escape"}, {"b@ctrl#0"}], "down")
    inpt.bind_buttons("exit", [{"left shift", "escape"}])

    events.call(events.IDS.awake)

    if pgapi.SETTINGS is not None and not pgapi.SETTINGS.skip_title_screen:
        scene.load(enums.scenes.DEFAULT)
    else:
        scene.load(enums.scenes.GAME)

    events.call(events.IDS.init)

    while pgapi.RUN:
        if pgapi.SCREEN is None:
            continue

        pgapi.SCREEN.size = Vec2(
            pgapi.SCREEN.this.get_width(), pgapi.SCREEN.this.get_height()
        )

        new_ratio = (pgapi.SCREEN.size.x / pgapi.SCREEN.size.y) / (1920 / 1080)
        if ui_ratio != new_ratio:
            ui_ratio = new_ratio
            pgapi.GUI_PIXEL_RATIO = ui_ratio
            assets.create_runtime_objects(ui_ratio)

        for event in pygame.event.get():
            # pylint: disable=no-member
            if event.type == pygame.QUIT:
                # pylint: enable=no-member
                pgapi.RUN = False

        inpt.system_udpate()
        gui.system_update()

        events.system_update()
        collision.system_update()

        pgapi.SCREEN.this.fill("black")
        animator.tick_anims()
        pgapi.system_camera()

        display.render()

        if (
            inpt.active_bind("exit")
            and pgapi.SETTINGS is not None
            and pgapi.SETTINGS.is_demo
        ):
            saves.save()
            pgapi.end()

        if pgapi.CLOCK is not None and pgapi.SETTINGS is not None:
            pgapi.TIME.deltatime = pgapi.CLOCK.tick(pgapi.SETTINGS.max_fps) / 1000
            pgapi.TIME.current = pgapi.time.perf_counter()

    # pylint: disable=no-member
    pygame.quit()
    # pylint: enable=no-member
