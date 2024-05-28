from types import UnionType
from zenyx import printf
from structures import *
from uuid import uuid4
import inspect
import copy
import time
import math
import sys


import pygame._sdl2.controller as pycontroller
import pygame


T = TypeVar("T")
K = TypeVar("K")


class DummyFile(object):
    def write(self, x):
        pass

    def flush(self, x=None):
        pass


def silence(func: Callable):
    def wrap(*args, **kwargs):
        res, exc = None, None
        save_stdout = sys.stdout
        sys.stdout = DummyFile()
        try:
            res = func(*args, **kwargs)
        except Exception as e:
            exc = e
        sys.stdout = save_stdout
        if exc:
            raise exc
        return res

    return wrap


def attempt(func: Callable[..., T], args: Tuple = ()) -> Result[T, Mishap]:
    try:
        return Ok(func(*args))
    except Exception as e:
        return Err(Mishap(" ".join([str(x) for x in e.args]), True))


@silence
def quit() -> Never:
    raise Exception("Quit")


def unreachable(msg: str) -> Never:
    stack = inspect.stack()[1]
    printf(
        "\n\n@!unreachable$&"
        + f"\n@~In {stack.filename}, line {stack.lineno} in {stack.function}()$&"
    )
    printf(f"\n@!Error Message:$&\n{msg}")
    printf()
    quit()


def typeof(a: Any) -> str:
    return str(a.__class__.__name__)


def istype(a: Any, T: type) -> bool:
    if isinstance(a, T):
        return True

    if type(a) == T:
        return True

    try:
        if a.__name__ == T.__name__:
            return True
    except AttributeError:
        if a.__class__.__name__ == T.__name__:
            return True

    return False


def structured_clone(a: T) -> T:
    return copy.deepcopy(a)


def merge(a: T, b: T) -> Result[T, Mishap]:
    """
    #### Note: This will merge `b` into `a`, meaning `b` will override `a`'s content!
    """

    if typeof(a) != typeof(b):
        return Err(
            Mishap(
                f"Couldn't merge a (type of {typeof(a)}) and b (type of {typeof(b)})!"
            )
        )

    dict_a: dict[str, Any] = structured_clone(a.__dict__)
    dict_b: dict[str, Any] = structured_clone(b.__dict__)

    constructor: T = a.__class__

    for key, value in dict_b.items():
        if value == None:
            continue

        dict_a[key] = value

    return Ok(constructor(**dict_a))


class Piper(Generic[T, K]):
    def __init__(self, value: T) -> None:
        self.value = value
        self.next_args: list[Any] = []
        self.next_kwargs: dict[str, Any] = {}

    def __or__(self, func: Callable[..., K]) -> "Piper[K]":
        self.value = func(self.value, *self.next_args, **self.next_kwargs)

    def __rshift__(self, kwargs: dict[str, Any]) -> None:
        self.next_kwargs = kwargs
        return self

    def __add__(self, args: list[Any]) -> None:
        self.next_args = args
        return self

    def __call__(self, *args: Any, **kwds: Any) -> K:
        return self.value


def uuid() -> string:
    return uuid4().hex
