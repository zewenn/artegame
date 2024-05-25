from zenyx import printf
from structures import *
import inspect
import copy

T = TypeVar("T")
K = TypeVar("K")


def attempt(func: Callable[..., T], args: Tuple = ()) -> Result[T, Mishap]:
    try:
        return Ok(func(*args))
    except Exception as e:
        return Err(Mishap(" ".join([str(x) for x in e.args]), True))


def unreachable(msg: str) -> Never:
    stack = inspect.stack()[1]
    printf(
        "\n\n@!unreachable$&"
        + f"\n@~In {stack.filename}, line {stack.lineno} in {stack.function}()$&"
    )
    printf(f"\n@!Error Message:$&\n{msg}")
    printf()
    exit()


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
