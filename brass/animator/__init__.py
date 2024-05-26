from base import *

# fmt: off
from uuid import uuid4
from . import (
    play_objects, 
    interpolation, 
    store
)

import enums
import items
import time
# fmt: on


# --------------------------- Public ---------------------------


playing_groups: dict[str, PlayObject] = {}


def reset_anim(id: string) -> None:
    for anim in playing_groups[id].group.animations:
        render_keyframe(anim.target, list(anim.keyframes.values())[0])


def tick_anims() -> None:
    finished: list[Tuple[str, PlayObject]] = []
    for id, play_obj in playing_groups.items():
        if play_obj is None:
            continue

        if play_obj.finished:
            finished.append((play_obj.group.id, play_obj))
            continue

        finished_count: int = 0

        for anim in play_obj.anims:
            if anim.finished:
                finished_count += 1
                render_keyframe(anim.anim.target, anim.keyframe_list[-1])
                continue

            if time.perf_counter() > anim.end_time:
                x = play_objects.next(play_obj, anim)
                if x is False:
                    continue

            t = (time.perf_counter() - anim.start_time) / (
                play_obj.group.lenght
                * (anim.end_time_multipliers[anim.current_keyframe + 1] + 0.001)
            )
            t = max(0, min(1, t))

            interpolated_keyframe = interpolation.interpolate_keyframes(
                play_obj.group.timing_function,
                anim.keyframe_list[anim.current_keyframe],
                anim.keyframe_list[anim.current_keyframe + 1],
                t,
            )

            render_keyframe(anim.anim.target, interpolated_keyframe)

        if len(play_obj.anims) == finished_count:
            play_obj.finished = True

    for id, po in finished:
        if po.group.mode == enums.animations.MODES.NORMAL:
            reset_anim(id)
        del playing_groups[id]
        del po
    del finished


def play(anim: AnimationGroup) -> None:
    if (anim.id not in playing_groups):
        playing_groups[anim.id] = play_objects.new(anim)


def stop(anim: AnimationGroup) -> None:
    if playing_groups[anim.id].group.mode == enums.animations.MODES.NORMAL:
        reset_anim(anim.id)
    del playing_groups[anim.id]


def set_mode(anim: AnimationGroup, mode: int) -> None:
    anim.mode = mode


def render_keyframe(target: str, keyframe: Keyframe) -> None:
    target_o = items.get(target)

    if target_o.is_err():
        printf(f'Target object by the query "{target}" does not exist!')
        return

    target_obj = target_o.ok()

    if target_obj is None:
        print("Bad query")
        return

    if isinstance(target_obj, Bone):
        if keyframe.anchor_x is not None:
            target_obj.anchor.x = keyframe.anchor_x
        if keyframe.anchor_y is not None:
            target_obj.anchor.y = keyframe.anchor_y

    if keyframe.sprite is not None:
        target_obj.sprite = keyframe.sprite

    if keyframe.fill_color is not None:
        target_obj.fill_color = keyframe.fill_color

    if keyframe.position_x is not None:
        target_obj.transform.position.x = keyframe.position_x

    if keyframe.position_y is not None:
        target_obj.transform.position.y = keyframe.position_y

    if keyframe.rotation_x is not None:
        target_obj.transform.rotation.x = keyframe.rotation_x

    if keyframe.rotation_y is not None:
        target_obj.transform.rotation.y = keyframe.rotation_y

    if keyframe.rotation_z is not None:
        target_obj.transform.rotation.z = keyframe.rotation_z

    if keyframe.width is not None:
        target_obj.transform.scale.x = keyframe.width

    if keyframe.height is not None:
        target_obj.transform.scale.y = keyframe.height


def create(
    duration_seconds: int,
    mode: Literal["Normal", "Forwards"],
    timing_function: Callable[[Number, Number, Number], Number],
    animations: list[Animation],
) -> AnimationGroup:
    if mode not in ["Normal", "Forwards"]:
        unreachable(
            f"Incorrect animation mode!"
            + f'\n | Expected: "Normal" | "Forwards"'
            + f"\n | Recieved: {mode}"
        )

    # if timing_function not in Timing.timing_table:
    #     unreachable(
    #         "Incorrect timing function"
    #         + f"\n | Expected: animator.Timing"
    #         + f"\n | Recieved: {timing_function}"
    #     )

    for anim in animations:
        first_frame = anim.keyframes[list(anim.keyframes)[0]]

        anim.keyframes[0] = first_frame
        anim.keyframes = dict(sorted(anim.keyframes.items()))
        if mode == 0:
            # Set the key last key ("-1") to the first frame:
            # anim.keyframes = {
            #   0: first_frame
            #   ...
            #   -1: first_frame
            # }
            anim.keyframes[-1] = first_frame

    return AnimationGroup(
        id=uuid4().hex,
        lenght=duration_seconds,
        mode=mode,
        timing_function=timing_function,
        animations=animations,
    )
