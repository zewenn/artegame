from classes import *
from dataclasses import fields
import math, copy


class MathVectorToolkit:
    def __raise_creation_error(missing: list[str] = None):
        if missing is None:
            missing = []

        out = "Not enough creation data: \n"
        if len(missing) == 0:
            out += "No arguments given"
        else:
            out += "Some of the following might be None: \n"
            out += ", ".join(missing)
        raise ValueError(out)

    def __raise_incorrect_error(paramname):
        raise ValueError(f"{paramname} does not match the calculated value!")

    class cloning:
        def MathVector(mv: CompleteMathVector) -> CompleteMathVector:
            return MathVectorToolkit.new(
                start=Vector2(mv.start.x, mv.start.y), end=Vector2(mv.end.x, mv.end.y)
            )

        def Vector2(v: Vector2) -> Vector2:
            return Vector2(x=v.x, y=v.y)

    def new(
        end: Vector2 | None = None,
        start: Vector2 | None = None,
        delta: Vector2 | None = None,
        direction: float | None = None,
        magnitude: float | None = None,
    ) -> CompleteMathVector:
        """
        You do not need to give every argument.
        If you missed a key one, the ValueError message will show which one it was

        Args:
            start (Vector2, optional): Defaults to None.
            end (Vector2, optional): Defaults to None.
            delta (Vector2, optional): Defaults to None.
            direction (float, optional): Defaults to None.
            magnitude (float, optional): Defaults to None.

        Returns:
            CompleteMathVector: The Completed MathVector
        """

        if start is not None:
            start = Vector2(start.x, start.y)

        if end is not None:
            end = Vector2(end.x, end.y)

        if delta is not None:
            delta = Vector2(delta.x, delta.y)

        if [start, direction, magnitude] == [None, None, None]:
            start = Vector2()

        return MathVectorToolkit.complete(
            IncompleteMathVector(
                start=start,
                end=end,
                delta=delta,
                direction=direction,
                magnitude=magnitude,
            )
        )

    def complete(
        mv: IncompleteMathVector,
    ) -> CompleteMathVector:
        if [mv.start, mv.end, mv.delta, mv.direction, mv.magnitude] == [
            None,
            None,
            None,
            None,
            None,
        ]:
            MathVectorToolkit.__raise_creation_error()

        if mv.end is None:
            if None in [
                mv.direction,
                mv.magnitude,
                mv.start,
            ]:
                MathVectorToolkit.__raise_creation_error(["Start", "Direction", "Magnitude"])

            mv.end = Vector2(
                x=mv.start.x + mv.magnitude * math.cos(math.radians(mv.direction)),
                y=mv.start.y + mv.magnitude * math.sin(math.radians(mv.direction)),
            )

        if mv.start is None:
            if None in [mv.direction, mv.magnitude, mv.end]:
                MathVectorToolkit.__raise_creation_error(["End", "Direction", "Magnitude"])

            mv.start = Vector2(
                x=mv.end.x - mv.magnitude * math.cos(math.radians(mv.direction)),
                y=mv.end.y - mv.magnitude * math.sin(math.radians(mv.direction)),
            )

        calc_delta: Vector2 = Vector2(x=mv.end.x - mv.start.x, y=mv.end.y - mv.start.y)
        if mv.delta is None:
            mv.delta = calc_delta
        elif mv.delta.x != calc_delta.x or mv.delta.y != calc_delta.y:
            MathVectorToolkit.__raise_incorrect_error("Delta")

        calc_magnitude: float = (mv.delta.x**2 + mv.delta.y**2) ** 0.5
        if mv.magnitude is None:
            mv.magnitude = calc_magnitude
        elif mv.magnitude != calc_magnitude:
            MathVectorToolkit.__raise_incorrect_error("Magnitude")

        calc_direction: float = math.degrees(math.atan2(mv.delta.y, mv.delta.x))
        if mv.direction is None:
            mv.direction = calc_direction
        elif round(mv.direction, 5) != round(calc_direction, 5):
            print(round(mv.direction, 5), round(calc_direction, 5))
            MathVectorToolkit.__raise_incorrect_error("Direction")

        return CompleteMathVector(
            start=mv.start,
            end=mv.end,
            delta=mv.delta,
            direction=mv.direction,
            magnitude=mv.magnitude,
        )

    def add(
        origin: CompleteMathVector, addend: CompleteMathVector
    ) -> CompleteMathVector:
        """Adds two vectors together.
        The start point of the vector will be equal to the origin's start point

        Args:
            origin (CompleteMathVector): The vector you wish to add to
            addend (CompleteMathVector): The addend

        Returns:
            CompleteMathVector: The calculated Complete Math Vector
        """
        return MathVectorToolkit.new(
            start=MathVectorToolkit.cloning.Vector2(origin.start),
            end=Vector2(
                x=(origin.delta.x + addend.delta.x),
                y=(origin.delta.y + addend.delta.y),
            ),
        )

    def subtract(
        origin: CompleteMathVector, subtrahend: CompleteMathVector
    ) -> CompleteMathVector:
        return MathVectorToolkit.new(
            # start=copy.deepcopy(origin.start),
            start=MathVectorToolkit.cloning.Vector2(origin.start),
            end=Vector2(
                x=(origin.delta.x - subtrahend.delta.x),
                y=(origin.delta.y - subtrahend.delta.y),
            ),
        )

    def multiply(mv: CompleteMathVector, multiplier: float) -> CompleteMathVector:
        """Multipy a vector by a scalar amount

        Args:
            mv (CompleteMathVector): the vector
            multiplier (float): scalar amount

        Returns:
            CompleteMathVector: The updated vector
        """
        return MathVectorToolkit.new(Vector2(mv.end.x * multiplier, mv.end.y * multiplier))

    def divide(mv: CompleteMathVector, divisor: float) -> CompleteMathVector:
        """divide a vector by a scalar amount

        Args:
            mv (CompleteMathVector): the vector
            divisor (float): scalar amount

        Returns:
            CompleteMathVector: The updated vector
        """
        return MathVectorToolkit.new(
            start=MathVectorToolkit.cloning.Vector2(mv.start),
            end=Vector2(mv.end.x / divisor, mv.end.y / divisor)
        )

    def dot_product(mv1: CompleteMathVector, mv2: CompleteMathVector) -> float:
        """Calculates the dot product of two vectors

        Args:
            mv1 (CompleteMathVector): first vector
            mv2 (CompleteMathVector): second vector

        Returns:
            float: the dot product
        """
        displacement = Vector2(
            x=(mv1.start.x - mv2.start.x), y=(mv1.start.y - mv2.start.y)
        )

        mv1_a = Vector2(mv1.end.x - displacement.x, mv1.end.y - displacement.y)

        mv2_a = Vector2(mv2.end.x - displacement.x, mv2.end.y - displacement.y)

        return (mv1_a.x * mv2_a.x) + (mv1_a.y * mv2_a.y)

    def normalise(mv: CompleteMathVector) -> CompleteMathVector:
        """Normalises the vector so its magnitude is `Literal[1]`.

        Args:
            mv (CompleteMathVector): the vector

        Raises:
            ValueError: if the magnitude is a not positive number

        Returns:
            CompleteMathVector: the updated vector
        """
        if mv.magnitude <= 0:
            raise ValueError("Cannot normalise vector with a negative length")

        return MathVectorToolkit.divide(mv, mv.magnitude)

    def limit(mv: CompleteMathVector, limit: float) -> CompleteMathVector:
        """Limits the magnitude of the vector

        Args:
            mv (CompleteMathVector): the vector
            limit (float): the magnitude limit

        Returns:
            CompleteMathVector: the updated vector
        """
        if mv.magnitude <= limit:
            return MathVectorToolkit.cloning.MathVector(mv)

        return MathVectorToolkit.new(
            start=MathVectorToolkit.cloning.Vector2(mv.start),
            magnitude=limit,
            direction=mv.direction,
        )

    def angle_between(
        mv1: CompleteMathVector, mv2: CompleteMathVector, _in="degrees"
    ) -> float:
        """Gets the angle between two vectors endpoints

        Args:
            mv1 (CompleteMathVector): 1st vector
            mv2 (CompleteMathVector): 2nd vector
            _in (str, optional): 'degrees' or 'radians'. Defaults to "degrees".

        Raises:
            ValueError: if `_in` is incorrect

        Returns:
            float: the angle betwween the two end points
        """
        if _in not in ['degrees', 'radians']:
            raise ValueError(f"Cannot convert angle to \"{_in}\"")

        if _in == "degrees":
            return abs(mv1.direction - mv2.direction)
        else:
            return math.radians(abs(mv1.direction - mv2.direction))
