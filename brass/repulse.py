from classes import *
import items


class Collision:
    @classmethod
    def is_smaller_than(this, distance: float, other: list[float]):
        if distance <= other[0] and distance <= other[1] and distance <= other[2]:
            return True
        else:
            return False

    @classmethod
    def get_smallest(this, dists: Distances) -> float:
        return min([dists.left, dists.right, dists.top, dists.bottom])

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

    @classmethod
    def repulse(this) -> None:
        collide_items: list[Item] = []
        repulse_items: list[Item] = []

        for item in items.rendering:
            if item.can_collide and item.render:
                collide_items.append(item)

        for item in items.rendering:
            if item in collide_items and item.can_repulse:
                repulse_items.append(item)

        # rei for repulse item
        for rei in repulse_items:
            for other in collide_items:
                if not this.collides(rei, other):
                    continue

                rei_dist = Distances()

                rei_dist.left = (
                    rei.transform.position.x
                    + rei.transform.scale.x
                    - other.transform.position.x
                    + 1
                )

                rei_dist.right = (
                    other.transform.position.x
                    + other.transform.scale.x
                    - rei.transform.position.x
                    + 1
                )

                rei_dist.bottom = (
                    rei.transform.position.y
                    + rei.transform.scale.y
                    - other.transform.position.y
                    + 1
                )

                rei_dist.top = (
                    other.transform.position.y
                    + other.transform.scale.y
                    - rei.transform.position.y
                    + 1
                )

                if other not in repulse_items:
                    this.move_back(rei_dist, rei, other, 1)
                    continue

                other_dist = Distances()

                # Other dist

                other_dist.left = (
                    other.transform.position.x
                    + other.transform.scale.x
                    - rei.transform.position.x
                    + 1
                )

                other_dist.right = (
                    rei.transform.position.x
                    + rei.transform.scale.x
                    - other.transform.position.x
                    + 1
                )

                other_dist.bottom = (
                    other.transform.position.y
                    + other.transform.scale.y
                    - rei.transform.position.y
                    + 1
                )

                other_dist.top = (
                    rei.transform.position.y
                    + rei.transform.scale.y
                    - other.transform.position.y
                    + 1
                )

                full_mass = rei.lightness + other.lightness
                rei_multiplier = rei.lightness / full_mass
                other_multiplier = other.lightness / full_mass

                this.move_back(rei_dist, rei, other, rei_multiplier)
                this.move_back(other_dist, other, rei, other_multiplier)
