# Dependency manager
from typing import Optional, Callable
import subprocess
import sys, os, io, time


def title(content: str, line_char: chr = "─") -> None:
    width: int = os.get_terminal_size().columns
    mid_text: str = f" {content} "
    side_width: int = int((width - len(mid_text)) / 2)

    if len(line_char) != 1:
        raise ValueError("line char is not a char")

    sep_text = line_char * side_width
    print("\n"*5)
    print(f"{sep_text}{mid_text}{sep_text}")
    print("\n")


class DummyFile(object):
    def write(self, x):
        pass
    def flush(self, x): 
        pass


def silence(func: Callable):
    def wrap(*args, **kwargs):
        save_stdout = sys.stdout
        sys.stdout = DummyFile()
        func(*args, **kwargs)
        sys.stdout = save_stdout

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


def install(name: str) -> bool | Exception:
    if is_installed(name):
        return False

    try:
        with open(os.devnull, "wb") as shutup:
            subprocess.check_call(
                [sys.executable, "-m", "pip", "install", "--upgrade", name],
                stdout=shutup,
                stderr=shutup,
                stdin=shutup,
            )
        return True
    except Exception as e:
        return e


def is_stack_installed(deps: list[str]) -> bool:
    for dep in deps:
        if not is_installed(dep):
            return False
    return True


def dep_stack(deps: list[str]) -> list[Optional[Exception]]:

    for dep in deps:
        start = time.perf_counter()
        res = install(dep)

        symbol = "✘"
        addon_text = ""

        if not isinstance(res, Exception):
            symbol = "+"

        if not res:
            symbol = "✔"

        print(f"{symbol} {dep}  \t[{round(time.perf_counter() - start, 5)}s]")
