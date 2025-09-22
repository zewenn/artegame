from .base import *

from threading import Timer

# Sound = pygame.mixer.Sound


def play(audio: Audio, loop=0, maxtime=0):
    if audio.playing:
        return

    if maxtime == 0:
        maxtime = audio.maxtimeMS

    audio.playing = True
    audio.sound.set_volume(audio.volume)
    audio.sound.play(loops=loop, maxtime=maxtime)


def stop(audio: Audio):
    if not audio.playing:
        return
    audio.playing = False

    audio.sound.stop()


def set_maxtime(audio: Audio, toMS: int):
    audio.maxtime = toMS


def set_volume(audio: Audio, to: float):
    audio.volume = to
    audio.sound.set_volume(audio.volume)


def get_volume(audio: Audio):
    return audio.volume


def get_length(audio: Audio):
    return audio.sound.get_length()


def fade_in(audio: Audio, timeMS: int = 0, loop=0, maxtime=0):
    if audio.playing:
        return
    audio.playing = True

    if maxtime == 0:
        maxtime = audio.maxtimeMS

    audio.sound.set_volume(audio.volume)
    audio.sound.play(fade_ms=timeMS, loops=loop, maxtime=maxtime)


def fade_out(audio: Audio, timeMS: int = 0):
    if not audio.playing:
        return
    audio.playing = False

    audio.sound.fadeout(timeMS)


def clone(audio: Audio) -> Audio:
    sound_data = audio.sound.get_raw()
    new_sound = pygame.mixer.Sound(buffer=sound_data)

    return Audio(new_sound, audio.volume, audio.playing, audio.maxtimeMS)
