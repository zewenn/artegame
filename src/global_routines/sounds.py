from brass.base import *

from brass import audio, scene, enums, assets, events
import random

AUDIO_AMBIENT: Optional[Audio] = None
FIGHT_AUDIOS: list[Optional[Audio]] = []
playing_fight_music: Optional[Audio] = None

PUNCH: Optional[Audio] = None
PICKUP: Optional[Audio] = None

VOLUME = 0.2


@events.awake
def awk() -> None:
    global AUDIO_AMBIENT, FIGHT_AUDIOS, PUNCH, PICKUP

    AUDIO_AMBIENT = assets.use("audio__ambient.mp3")
    AUDIO_FIGHT_0 = assets.use("audio__fight_0.mp3")
    AUDIO_FIGHT_1 = assets.use("audio__fight_1.mp3")
    AUDIO_FIGHT_2 = assets.use("audio__fight_2.mp3")
    AUDIO_FIGHT_3 = assets.use("audio__fight_3.mp3")

    FIGHT_AUDIOS = [AUDIO_FIGHT_0, AUDIO_FIGHT_1, AUDIO_FIGHT_2, AUDIO_FIGHT_3]

    PUNCH = assets.use("punch.mp3")
    PICKUP = assets.use("pickup.mp3")

    if PUNCH is None or PICKUP is None:
        return

    audio.set_volume(PUNCH, VOLUME)
    audio.set_volume(PICKUP, VOLUME)


def start_combat_round() -> None:
    global playing_fight_music

    index = random.randint(0, len(FIGHT_AUDIOS) - 1)

    if AUDIO_AMBIENT is not None:
        audio.fade_out(AUDIO_AMBIENT, 1000)

    fight_audio: Optional[Audio] = FIGHT_AUDIOS[index]
    if fight_audio is None:
        return

    playing_fight_music = fight_audio
    audio.fade_in(fight_audio)


def end_combat_round() -> None:
    global playing_fight_music

    if playing_fight_music is not None:
        audio.fade_out(playing_fight_music, 1000)
        playing_fight_music = None

    if AUDIO_AMBIENT is not None:
        audio.fade_in(AUDIO_AMBIENT, 1000)


@scene.spawn(enums.scenes.DEFAULT)
def _() -> None:
    if playing_fight_music is None or AUDIO_AMBIENT is None:
        return

    audio.fade_out(playing_fight_music, 1000)
    audio.set_volume(AUDIO_AMBIENT, VOLUME)
    audio.fade_in(AUDIO_AMBIENT, 500, 1)


@scene.spawn(enums.scenes.DEFEAT)
def _() -> None:
    if playing_fight_music is None or AUDIO_AMBIENT is None:
        return

    audio.fade_out(playing_fight_music, 1000)
    audio.set_volume(AUDIO_AMBIENT, VOLUME)
    audio.fade_in(AUDIO_AMBIENT, 500, 1)


@events.update
def update() -> None:
    if playing_fight_music is not None:
        audio.set_volume(playing_fight_music, VOLUME)

    if AUDIO_AMBIENT is not None:
        audio.set_volume(AUDIO_AMBIENT, VOLUME)

    if PUNCH is not None:
        audio.set_volume(PUNCH, VOLUME * 0.5)

    if PICKUP is not None:
        audio.set_volume(PICKUP, VOLUME * 0.5)
