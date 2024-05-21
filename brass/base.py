from zenyx import printf
from structures import *
import inspect

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
    exit()