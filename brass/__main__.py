from base import *


# Importing scripts, so they can run
import enums
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
import scene
import enums
import threading
import screeninfo

def render_loop() -> None:
    while pgapi.RUN:
        pgapi.SCREEN.this.fill("black")
        animator.tick_anims()
        pgapi.system_camera()

        render.render()
        pygame.display.flip()



def init():
    # Setting up pygame
    pygame.init()
    pycontroller.init()
    pygame.mixer.init()

    assets.create_runtime_objects()

    monitor = screeninfo.get_monitors()[0]
    pgapi.use(
        ApplicationSettings(
            application_name=f"Artegame - DEMO",
            # screen_size=Vec2(1600, 900),
            screen_size=Vec2(monitor.width, monitor.height),
            max_fps=240,
            vsync=0,
            icon="neunyx32x32.png",
            camera=Camera(Vec2(0, 0), 1),
            is_demo=True,
            # axis_rounding=10
        )
    )

    pgapi.set_screen_flags(pygame.NOFRAME | pygame.SCALED)



    inpt.init_controllers()

    # inpt.bind_buttons("exit", ["escape"])
    inpt.bind_buttons(enums.keybinds.SHOW_MENU, ["escape", "back@ctrl#0"], "down")
    inpt.bind_buttons(enums.keybinds.ACCEPT_MENU, ["enter", "a@ctrl#0"], "down")
    inpt.bind_buttons(enums.keybinds.BACK, ["escape", "b@ctrl#0"], "down")

    scene.load(enums.scenes.DEFAULT)
    events.call(events.IDS.awake)
    events.call(events.IDS.init)

    RENDER_THREAD = threading.Thread(target=render_loop, args=(), daemon=True)
    RENDER_THREAD.start()

    while pgapi.RUN:
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                pgapi.RUN = False

        # Demo exit
        # if inpt.active_bind("exit"):
        #     pgapi.RUN = False

        inpt.system_udpate()
        events.system_update()
        gui.system_update()
        collision.system_update()

        pgapi.TIME.deltatime = pgapi.CLOCK.tick(pgapi.SETTINGS.max_fps) / 1000
        pgapi.TIME.current = pgapi.time.perf_counter()

    pygame.quit()
    saves.save()


if __name__ == "__main__":
    init()
