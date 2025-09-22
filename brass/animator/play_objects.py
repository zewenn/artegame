from ..base import *


def new(group: AnimationGroup) -> PlayObject:
    this = PlayObject(group=group, anims=[], finished=False)
    start_time: float = time.perf_counter()

    for anim in this.group.animations:
        end_ts_multiplier: list[float] = [x / 100 for x in anim.keyframes]

        this.anims.append(
            ExpandedAnim(
                start_time, end_ts_multiplier, anim, list(anim.keyframes.values())
            )
        )

    return this


def set_anim_duration(play_object: PlayObject, anim: ExpandedAnim):
    anim.duration = play_object.group.length * (
        anim.end_time_multipliers[anim.current_keyframe + 1] + 0.001
    )


def next_keframe(play_object: PlayObject, anim: ExpandedAnim):
    if anim.current_keyframe + 1 == len(anim.keyframe_list) - 1:
        anim.finished = True
        return False

    anim.current_keyframe += 1
    anim.start_time = time.perf_counter()
    set_anim_duration(play_object, anim)
    anim.end_time = anim.start_time + anim.duration
    return True
