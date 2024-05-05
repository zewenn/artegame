from events import Events
from classes import Item, Vector2, Vector3
from entities import *
from pgapi import TIME, Debugger, SCENES
from vectormath import MathVectorToolkit, CompleteMathVector
from files import asset
from audio_helper import Audio, SoundBuffer
from repulse import Collision

import pygame

from input import Input

player: Item
box: Item
hand: Bone

music: Audio
walk: Audio

move_vec: Vector2 = Vector2()
move_math_vec: CompleteMathVector


@SCENES.default.initalise
def start():
    global player, hand, music, walk, box

    Input.bind_buttons("music-off", ["1", "dpad-down@ctrl#0"])
    Input.bind_buttons("music-on", ["2", "dpad-up@ctrl#0"])
    Input.bind_buttons("check-colision", ["e", "b@ctrl#0"])

    walk = Audio(asset("walking.mp3"))
    walk.set_volume(0.1)

    music = Audio(asset("background.mp3"))
    music.set_volume(0.1)
    music.fade_in(1000, 1)

    player_res = Items.get("player")
    box_res = Items.get("box")
    hand_res = Items.get("player->left_hand")
    if player_res:
        player = player_res
    if box_res:
        box = box_res
    if hand_res:
        hand = hand_res

    # Debugger.print("player.transform:", player.transform)


@SCENES.default.update
def update():
    global music, walk, walkbuffer

    move_vec.y = Input.vertical()
    move_vec.x = Input.horizontal()

    match move_vec.y != 0 or move_vec.x != 0:
        case True:
            walk.play(1)
        case False:
            walk.fade_out(200)
    

    if Input.active_bind("music-on"):
        music.fade_in(1000)

    if Input.active_bind("music-off"):
        music.fade_out(1000)

    if Input.active_bind("check-colision"):
        print("Collision:", Collision.collides(player, box))

    move_math_vec = MathVectorToolkit.normalise(MathVectorToolkit.new(move_vec))

    player.transform.position.y += 500 * TIME.deltatime * move_math_vec.end.y
    player.transform.position.x += 500 * TIME.deltatime * move_math_vec.end.x
