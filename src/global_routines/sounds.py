from brass.base import *

from brass import audio, scene, enums, assets, events

GAME_MUSIC: Optional[Audio] = None
MENU_MUSIC: Optional[Audio] = None
PUNCH: Optional[Audio] = None
PICKUP: Optional[Audio] = None

VOLUME = 0.05


@events.awake
def awk() -> None:
    global GAME_MUSIC, MENU_MUSIC, PUNCH, PICKUP

    GAME_MUSIC = assets.use("doom.mp3")
    MENU_MUSIC = assets.use("menu.mp3")
    PUNCH = assets.use("punch.mp3")
    PICKUP = assets.use("pickup.mp3")

    audio.set_volume(PUNCH, VOLUME)


@scene.spawn(enums.scenes.GAME)
def game_spawn() -> None:
    global GAME_MUSIC, MENU_MUSIC, PUNCH

    audio.fade_out(MENU_MUSIC, 1000)

    audio.set_volume(GAME_MUSIC, VOLUME)
    audio.fade_in(GAME_MUSIC, 500, 1)


@scene.spawn(enums.scenes.DEFAULT)
def game_spawn() -> None:
    global GAME_MUSIC, MENU_MUSIC

    audio.fade_out(GAME_MUSIC, 1000)

    audio.set_volume(MENU_MUSIC, VOLUME)
    audio.fade_in(MENU_MUSIC, 500, 1)


@scene.spawn(enums.scenes.DEFEAT)
def game_spawn() -> None:
    global GAME_MUSIC, MENU_MUSIC

    audio.fade_out(GAME_MUSIC, 1000)

    audio.set_volume(MENU_MUSIC, VOLUME)
    audio.fade_in(MENU_MUSIC, 500, 1)


@events.update
def update() -> None:
    global GAME_MUSIC, MENU_MUSIC, PUNCH, PI
    audio.set_volume(MENU_MUSIC, VOLUME)
    audio.set_volume(GAME_MUSIC, VOLUME)
    audio.set_volume(PUNCH, VOLUME * 0.5)
    audio.set_volume(PICKUP, VOLUME * 0.5)
