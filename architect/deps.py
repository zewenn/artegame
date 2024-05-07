# Dependency manager
from typing import *
import subprocess
import sys, os, io, time

T = TypeVar("T")

def attempt(func: Callable[..., T], args: Tuple = ()) -> Tuple[Optional[T], Optional[str]]:
    try: 
        return (func(*args), None)
    except Exception as e:
        return (None, " ".join(e.args))

def title(content: str, line_char: chr = "─") -> None:
    width: int = os.get_terminal_size().columns
    mid_text: str = f" {content} "
    side_width: int = int((width - len(mid_text)) / 2)

    if len(line_char) != 1:
        raise ValueError("line char is not a char")

    sep_text = line_char * side_width
    print("\n" * 5)
    print(f"{sep_text}{mid_text}{sep_text}")
    print("\n")


class DummyFile(object):
    def write(self, x):
        pass

    def flush(self, x = None):
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


@silence
def imprt(name: str) -> None:
    __import__(name)


def is_installed(name: str) -> bool:
    try:
        imprt(name)
        return True
    except ModuleNotFoundError:
        return False
    except Exception as e:
        print(f"An unexpected error occured while checking for installed modules:\n{e}")
        return False


def install(name: str) -> bool:
    if is_installed(name):
        return True

    try:
        with open(os.devnull, "wb") as shutup:
            subprocess.check_call(
                [sys.executable, "-m", "pip", "install", "--upgrade", name],
                stdout=shutup,
                stderr=shutup,
                stdin=shutup,
            )
        return True
    except Exception:
        return False


def is_stack_installed(deps: list[str]) -> bool:
    for dep in deps:
        if not is_installed(dep):
            return False
    return True


def handle_dep_stack(deps: list[str]) -> list[Optional[Exception]]:
    failed: bool = False

    for index, dep in enumerate(deps):
        start = time.perf_counter()
        install_res = install(dep)

        symbol = "✔"

        if not install_res:
            symbol = "✘"
            failed = True

        print(
            f"[{index + 1}/{len(deps)}] {symbol} {dep}",
            f"\tin {round(time.perf_counter() - start, 5)}s",
            sep="    ",
        )
    
    if failed:
        return Exception("deps was unable to install some packag(es).")


def run_python_command(cmd: list[str]) -> Tuple[bool, Optional[Exception]]:
    try:
        x = subprocess.call([sys.executable, *cmd])
        if (x == 0):
            return True, None
        else: 
            return False, f"\tExit code: {x}"
    except Exception as e:
        return False, e
