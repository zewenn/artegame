from events import *
from classes import *
import items
from vectormath import MathVectorToolkit, CompleteMathVector
import assets
from audio_helper import Audio
from input_handler import Input
from pgapi import TIME
import gui
import pgapi
from scenenum import SCENES

camera: Camera
player: Item
box: Item
hand: Bone

music: Audio
walk: Audio

move_vec: Vector2 = Vector2()
move_math_vec: CompleteMathVector


@init
def _s():
    global player, hand, music, walk, box, camera, text_elem

    camera = pgapi.get_camera()

    Input.bind_buttons("music-off", ["1", "dpad-down@ctrl#0"])
    Input.bind_buttons("music-on", ["2", "dpad-up@ctrl#0"])

    walk = Audio(assets.use("walking.mp3"))
    walk.set_volume(0.1)

    music = Audio(assets.use("background.mp3"))
    music.set_volume(0.05)
    music.fade_in(1000, 1)

    player_res = items.get("player")
    box_res = items.get("box")
    hand_res = items.get("player->left_hand")

    if player_res:
        player = player_res
    if box_res:
        box = box_res
    if hand_res:
        hand = hand_res


@update
def _u():
    global music, walk, walkbuffer, camera, move_math_vec

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

    # if Input.get_button("k"):

    move_math_vec = MathVectorToolkit.normalise(MathVectorToolkit.new(move_vec))

    player.transform.position.y += 500 * TIME.deltatime * move_math_vec.end.y
    player.transform.position.x += 500 * TIME.deltatime * move_math_vec.end.x

    pgapi.move_camera(player.transform.position)

    # print(CAMERA)
