from threading import Timer
import pygame

Sound = pygame.mixer.Sound


class Audio:
    def __init__(self, pgaudio: Sound) -> None:
        self.sound = pgaudio
        self.volume = 1
        self.playing: bool = False
        self.maxtimeMS = 0

    def play(self, loop=0, maxtime=0):
        if self.playing:
            return

        if maxtime == 0:
            maxtime = self.maxtimeMS

        self.playing = True
        self.sound.set_volume(self.volume)
        self.sound.play(loops=loop, maxtime=maxtime)

    def stop(self):
        if not self.playing:
            return
        self.playing = False

        self.sound.stop()

    def set_maxtime(self, toMS: int):
        self.maxtime = toMS

    def set_volume(self, to: float):
        self.volume = to
        self.sound.set_volume(self.volume)

    def get_volume(self):
        return self.volume

    def get_length(self):
        return self.sound.get_length

    def fade_in(self, timeMS: int = 0, loop=0, maxtime=0):
        if self.playing:
            return
        self.playing = True

        if maxtime == 0:
            maxtime = self.maxtimeMS

        self.sound.set_volume(self.volume)
        self.sound.play(fade_ms=timeMS, loops=loop, maxtime=maxtime)

    def fade_out(self, timeMS: int = 0):
        if not self.playing:
            return
        self.playing = False

        self.sound.fadeout(timeMS)
        Timer(timeMS, self.sound.stop, ())


class SoundBuffer:
    def __init__(self, max_playing: int = 10, time_out_lengthMS: float = 100) -> None:
        self.buf: list[Audio] = []
        self.max = max_playing
        self.in_timeout: bool = False
        self.timeoutMS = time_out_lengthMS

    def clear_timeout(self):
        self.in_timeout = False

    def play(self, sound: Audio):
        if len(self.buf) >= self.max or self.in_timeout:
            return

        self.buf.append(sound)
        sound.play()
        Timer(sound.get_length(), self.buf.remove, (sound))

        self.in_timeout = True
        Timer(self.timeoutMS, self.clear_timeout, ())
