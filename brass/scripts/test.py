from events import Events
from classes import Item, Vector2, Vector3
from entities import *
from pgapi import TIME, Debugger, SCENES
from vectormath import MathVectorToolkit, CompleteMathVector
from files import asset
from audio_helper import Audio, SoundBuffer

import pygame

from input import Input

player: Item
hand: Bone
audio: Audio

walkbuffer: SoundBuffer = SoundBuffer(10, 200)
walk: Audio

move_vec: Vector2 = Vector2()
move_math_vec: CompleteMathVector


@SCENES.default.initalise
def start():
    global player, hand, audio, walk

    Input.bind_buttons("music-off", ["1", "dpad-down@ctrl#0"])
    Input.bind_buttons("music-on", ["2", "dpad-up@ctrl#0"])

    walk = Audio(asset("walking.mp3"))
    walk.set_volume(0.1)

    audio = Audio(asset("background.mp3"))

    audio.set_volume(0.1)
    audio.fade_in(1000, 1)

    query_res = Items.get("player")
    hand_res = Items.get("player->left_hand")
    if query_res:
        player = query_res
    if hand_res:
        hand = hand_res

    # Debugger.print("player.transform:", player.transform)


@SCENES.default.update
def update():
    global audio, walk, walkbuffer

    move_vec.y = Input.vertical()
    move_vec.x = Input.horizontal()

    match move_vec.y != 0 or move_vec.x != 0:
        case True:
            walk.play(1)
        case False:
            walk.fade_out(200)
    

    if Input.active_bind("music-on"):
        audio.fade_in(1000)

    if Input.active_bind("music-off"):
        audio.fade_out(1000)

    move_math_vec = MathVectorToolkit.normalise(MathVectorToolkit.new(move_vec))

    player.transform.position.y += 500 * TIME.deltatime * move_math_vec.end.y
    player.transform.position.x += 500 * TIME.deltatime * move_math_vec.end.x
