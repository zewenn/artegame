# Dependency manager
from typing import *
import subprocess
import sys
import os
import time

T = TypeVar("T")


def shorten(filename: str) -> str:
    return filename[:16] + ("..." if len(filename) > 16 else "")


def task(task_name: str):
    def wrap(fn):
        def res(*args, **kwargs):
            full_line(f"\n[Task : {task_name}]")
            r = fn(*args, **kwargs)
            return r

        return res

    return wrap


# @task("Delete Files")
def delete_files_in_directory(directory_path: list[str], display: bool = True):
    make_dir_walk(directory_path)
    directory_path = os.path.join(*directory_path)
    try:
        files = os.listdir(directory_path)
        for index, filename in enumerate(files):
            file_path: str = os.path.join(directory_path, filename)

            if os.path.isfile(file_path):
                os.remove(file_path)
            if os.path.isdir(file_path):
                delete_files_in_directory(file_path.split(os.sep), display=False)
                os.rmdir(file_path)

            if display:
                progress_bar(index + 1, len(files), shorten(filename))
        if display:
            task_complete()
    except OSError as e:
        print("Error occurred while deleting files: \n", e)


def progress_bar(at: int, top: int, msg: str) -> str:
    percent = round(at / top * 15, 5)
    progress = round(percent)
    line = "█" * progress + " " * (15 - progress)
    full_line(f" {round(at / top * 100)}%|{line}| {at}/{top},", msg, end="\r")
    # time.sleep(0.05)


def task_complete():
    # printf.full_line(" Task completed @!successfully$&!")
    print("")


def full_line(*args, **kwargs) -> None:
    terminal_width: int = os.get_terminal_size().columns
    joiner = " "
    if kwargs.get("sep"):
        joiner = kwargs.get("sep")

    content = joiner.join(args)

    print(
        f'{content}{" "*(terminal_width - len(content))}',
        **kwargs,
    )


def attempt(
    func: Callable[..., T], args: Tuple = ()
) -> Tuple[Optional[T], Optional[str]]:
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


def install(name: str, lazy: bool = True) -> bool:
    if is_installed(name) and lazy:
        return True

    try:
        # print(f"[GET]\u001b[38;5;215m {name}\u001b[0m", end="\r")
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


@task("lazy check dependencies")
def handle_dep_stack(deps: list[str]) -> list[Optional[Exception]]:
    failed: bool = False

    longest_dep_name = deps[0]
    for dep in deps:
        if len(dep) > len(longest_dep_name):
            longest_dep_name = dep

    for index, dep in enumerate(deps):
        install_res = install(dep)

        if not install_res:
            failed = True

        depname = str(dep)[: len(longest_dep_name)]

        progress_bar(index + 1, len(deps), depname)

        # print(
        #     f"[{index + 1}/{len(deps)}]\u001b[38;5;215m {depname.ljust(14)}\u001b[0m",
        #     f"\u001b[38;5;236m {round(time.perf_counter() - start, 5)}s\u001b[0m",
        #     # sep="    ",
        # )
    task_complete()

    if failed:
        return Exception("deps was unable to install some packag(es).")

    return None


def run_python_command(cmd: list[str]) -> Tuple[bool, Optional[Exception]]:
    try:
        # print([sys.executable, *cmd])
        x = subprocess.call([sys.executable, *cmd])
        if x == 0:
            return True, None
        else:
            return False, f"\tExit code: {x}"
    except Exception as e:
        return False, e


def make_dir_walk(pth: list[str]) -> None:
    if os.path.isdir(os.path.join(*pth)):
        return

    if "." in pth[-1]:
        pth = pth[0:-1]

    for index in range(len(pth)):
        current = pth[0 : index + 1]

        if os.path.isdir(os.path.join(*current)):
            continue

        os.mkdir(os.path.join(*current))
