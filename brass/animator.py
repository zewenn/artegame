from entities import *
from classes import *
import copy
from result import Result, Ok, Err

class play_object:
    def __init__(self, id: str):
        self.id = id
        self.group = animator.animation_groups.get(id)
        self.anims: list[ExpandedAnim] = []
        self.finished: bool = False
        start_t: float = time.perf_counter()

        if self.group is None:
            raise ValueError("Worng identificator")

        for anim in self.group.animations:
            end_ts_multiplier: list[float] = [x / 100 for x in anim.keyframes]

            self.anims.append(
                ExpandedAnim(
                    start_t, end_ts_multiplier, anim, list(anim.keyframes.values())
                )
            )

    def set_anim_duration(self, anim: ExpandedAnim):
        anim.duration = self.group.lenght * (
            anim.end_time_multipliers[anim.current_keyframe + 1] + 0.001
        )

    def next(self, anim: ExpandedAnim):
        if anim.current_keyframe + 1 >= len(anim.keyframe_list) - 1:
            anim.finished = True
            return False

        anim.current_keyframe += 1
        anim.start_time = time.perf_counter()
        self.set_anim_duration(anim)
        anim.end_time = anim.start_time + anim.duration
        return True

    def tick(self):
        finished_count: int = 0
        if self.finished:
            del animator.playing_groups[self.id]
            del self
            return

        for anim in self.anims:
            if anim.finished:
                finished_count += 1
                animator.render_keyframe(anim.anim.target, anim.keyframe_list[-1])
                continue

            if time.perf_counter() > anim.end_time:
                x = self.next(anim)
                if x is False:
                    continue

            t = (time.perf_counter() - anim.start_time) / (
                self.group.lenght
                * (anim.end_time_multipliers[anim.current_keyframe + 1] + 0.001)
            )
            t = max(0, min(1, t))

            interpolated_keyframe = interpolation.interpolate_keyframes(
                self.group.timing_function,
                anim.keyframe_list[anim.current_keyframe],
                anim.keyframe_list[anim.current_keyframe + 1],
                t,
            )

            animator.render_keyframe(anim.anim.target, interpolated_keyframe)

        if len(self.anims) == finished_count:
            self.finished = True


class interpolation:
    @classmethod
    def lerp(this, start: float | int, end: float | int, t: float | int) -> int | float:
        """Linear interpolation function."""
        return start + t * (end - start)

    @classmethod
    def ease_in(this, start: int | float, end: int | float, t: int | float) -> int | float:
        """Ease-in timing function."""
        return this.lerp(start, end, t * t)

    @classmethod
    def ease_out(this, start: int | float, end: int | float, t: int | float) -> int | float:
        """Ease-out timing function."""
        return this.lerp(start, end, (1 - (1 - t) * (1 - t)))

    @classmethod
    def ease_in_out(this, start: int | float, end: int | float, t: int | float) -> int | float:
        """Ease-in-out timing function."""
        return this.lerp(
            start,
            end,
            (
                t * t * (3 - 2 * t)
                if t < 0.5
                else 1 - (1 - t) * (1 - t) * (3 - 2 * (1 - t))
            ),
        )

    @classmethod
    def interpolate_keyframes(this, timing: int, keyframe1, keyframe2, t) -> Keyframe:
        """Interpolate between two KeyframeT objects."""
        interpolated_keyframe = Keyframe()
        timing_f = animator.Timing.timing_table[timing]

        for field in keyframe1.__annotations__:
            value1 = getattr(keyframe1, field)
            value2 = getattr(keyframe2, field)

            if isinstance(value1, (int, float)) and isinstance(value2, (int, float)):
                # Linear interpolation for numerical values
                interpolated_value = timing_f(value1, value2, t)
                setattr(interpolated_keyframe, field, interpolated_value)
            else:
                # Handle non-numeric values (e.g., colors, sprites)
                setattr(interpolated_keyframe, field, value2)

        return interpolated_keyframe


class animator:
    @classmethod
    def __handle_normal_stop(this, anims: list[Animation]) -> None:
        for anim in anims:
            this.render_keyframe(anim.target, list(anim.keyframes.values())[-1])

    @classmethod
    def __update_play_object(this, name: str) -> None:
        this.play_objects[name] = play_object(name)

    # --------------------------- Public ---------------------------

    class Modes:
        mode_list: list[int] = [0, 1]
        NORMAL: int = 0
        FORWARD: int = 1

    class Timing:
        timing_table: dict[int, callable] = {
            0: interpolation.lerp,
            1: interpolation.ease_in,
            2: interpolation.ease_out,
            3: interpolation.ease_in_out,
        }
        LINEAR = 0
        EASE_IN = 1
        EASE_OUT = 2
        EASE = 3

    animation_groups: dict[str, AnimationGroup] = {}
    play_objects: dict[str, ExpandedAnim] = {}
    playing_groups: dict[str, play_object] = {}

    @classmethod
    def tick_anims(this) -> None:
        for playing_animation in list(this.playing_groups.values()):
            if playing_animation is None:
                continue

            playing_animation.tick()

    @classmethod
    def play(this, name: str) -> None:
        if name in this.playing_groups:
            return

        if name not in this.play_objects:
            this.__update_play_object(name)

        this.playing_groups[name] = copy.deepcopy(this.play_objects[name])

    @classmethod
    def stop(this, name: str) -> None:
        if name not in this.playing_groups:
            return
        if this.playing_groups[name].group.mode == this.Modes.NORMAL:
            this.__handle_normal_stop(
                this.playing_groups[name].group.animations
            )
        del this.playing_groups[name]

    @classmethod
    def set_mode(this, name: str, mode: int) -> None:
        if mode not in this.Modes.mode_list:
            raise ValueError(f"Cannot set mode to {mode}")
        if name in this.animation_groups:
            raise ValueError(
                f"Cannot set the mode of {name}, because it does not exist"
            )
        this.animation_groups[name].mode = mode
        this.__update_play_object(name)

    @staticmethod
    def render_keyframe(target: str, keyframe: Keyframe) -> None:
        target_obj: Item | Bone = Items.get(target)

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

    @classmethod
    def create(
        this,
        name: str,
        duration: int,
        mode: int,
        timing_function: int,
        anim_list: list[Animation],
    ) -> Optional[ValueError]:
        if mode not in this.Modes.mode_list:
            return ValueError("Incorrect animation mode")

        if timing_function not in this.Timing.timing_table:
            return ValueError("Incorrect timing function")

        for anim in anim_list:
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

        this.animation_groups[name] = AnimationGroup(
            lenght=duration,
            mode=mode,
            timing_function=timing_function,
            animations=anim_list,
        )
