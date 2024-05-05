from classes import *
from entities import Items


class Collision:
    @classmethod
    def is_smaller_than(this, distance: float, other: list[float]):
        if distance <= other[0] and distance <= other[1] and distance <= other[2]:
            return True
        else:
            return False

    @classmethod
    def collides(this, a: Collider, b: Collider) -> bool:
        # print(a.transform, b.transform)
        if (
            a.transform.position.x + a.transform.scale.x >= b.transform.position.x
            and a.transform.position.x <= b.transform.position.x + b.transform.scale.x
            and a.transform.position.y + a.transform.scale.y >= b.transform.position.y
            and a.transform.position.y <= b.transform.position.y + b.transform.scale.y
        ):
            return True
        return False

    @classmethod
    def move_back(
        this, dists: Distances, rei: Item, other: Item, multiplier: int = 1
    ) -> None:
        if this.is_smaller_than(
            distance=dists.left, other=[dists.right, dists.top, dists.bottom]
        ):
            rei.transform.position.x -= (
                rei.transform.position.x
                + rei.transform.scale.x
                - other.transform.position.x
                + 1 * multiplier
            )

        if this.is_smaller_than(
            distance=dists.right, other=[dists.left, dists.top, dists.bottom]
        ):
            rei.transform.position.x += (
                other.transform.position.x
                + other.transform.scale.x
                - rei.transform.position.x
                + 1 * multiplier
            )

        if this.is_smaller_than(
            distance=dists.bottom, other=[dists.left, dists.top, dists.right]
        ):
            rei.transform.position.y -= (
                rei.transform.position.y
                + rei.transform.scale.y
                - other.transform.position.y
                + 1 * multiplier
            )

        if this.is_smaller_than(
            distance=dists.top, other=[dists.left, dists.bottom, dists.right]
        ):
            rei.transform.position.y += (
                other.transform.position.y
                + other.transform.scale.y
                - rei.transform.position.y
                + 1 * multiplier
            )

        # if collision.is_smaller_than(
        #     distances["left"],
        #     [distances["right"], distances["bottom"], distances["top"]],
        # ):
        #     slt["position"]["x"] -= (
        #         (slt["position"]["x"] + slt["scale"]["width"])
        #         - elt["position"]["x"]
        #         + 1
        #     )

        # elif collision.is_smaller_than(
        #     distances["right"],
        #     [distances["left"], distances["bottom"], distances["top"]],
        # ):
        #     slt["position"]["x"] += (
        #         (elt["position"]["x"] + elt["scale"]["width"])
        #         - slt["position"]["x"]
        #         + 1
        #     )

        # elif collision.is_smaller_than(
        #     distances["bottom"],
        #     [distances["left"], distances["right"], distances["top"]],
        # ):
        #     slt["position"]["y"] -= (
        #         (slt["position"]["y"] + slt["scale"]["height"])
        #         - elt["position"]["y"]
        #         + 1
        #     )

        # elif collision.is_smaller_than(
        #     distances["top"],
        #     [distances["left"], distances["right"], distances["bottom"]],
        # ):
        #     slt["position"]["y"] += (
        #         (elt["position"]["y"] + elt["scale"]["height"])
        #         - slt["position"]["y"]
        #         + 1
        #     )

    @classmethod
    def repulse(this) -> None:
        collide_items: list[Item] = []
        repulse_items: list[Item] = []

        for item in Items.rendering:
            if item.can_collide and item.render:
                collide_items.append(item)

        for item in Items.rendering:
            if item in collide_items and item.can_repulse:
                repulse_items.append(item)

        # rei for repulse item
        for rei in repulse_items:
            for other in collide_items:
                if not this.collides(rei, other):
                    continue

                if other not in repulse_items:
                    dist = Distances()

                    dist.left = (
                        rei.transform.position.x
                        + rei.transform.scale.x
                        - other.transform.position.x
                        + 1
                    )

                    dist.right = (
                        other.transform.position.x
                        + other.transform.scale.x
                        - rei.transform.position.x
                        + 1
                    )

                    dist.bottom = (
                        rei.transform.position.y
                        + rei.transform.scale.y
                        - other.transform.position.y
                        + 1
                    )

                    dist.top = (
                        other.transform.position.y
                        + other.transform.scale.y
                        - rei.transform.position.y
                        + 1
                    )

                    this.move_back(dist, rei, other, 1)
