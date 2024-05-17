from zenyx import printf
import b64encoder, import_generator
import os, sys
import deps
import subprocess, time
from termcolor import colored, cprint
import __config__ as conf
from result import *
from typing import *


def parse_int(string: str) -> Result[int, str]:
    try:
        x = int(string)
        return Ok(x)
    except ValueError as ve:
        return Err(" ".join(ve.args))


def make_file(path: str, content: str = "") -> None:
    with open(path, "w") as wf:
        wf.write(content)


T = TypeVar("T")


def attempt(func: Callable[..., T], args: Tuple = ()) -> Result[T, Exception]:
    try:
        return Ok(func(*args))
    except Exception as e:
        return Err(e)


def update_read_build_counter() -> str:
    res = 0
    with open(
        file=os.path.join("architect", "@build_counter.txt"),
        mode="r+",
        encoding="utf-8",
    ) as wrf:
        num = parse_int(wrf.read())
        wrf.seek(0)

        if num.is_err():
            wrf.write("0")
            return res

        res = num.ok()

        wrf.write(str(res + 1))

        return str(res)


def new_routine(T: Literal["gui"] | Literal["routine"] | Literal["config"], scn_name: str = "") -> str:
    match T:
        case "gui":
            return "\n".join(
                [
                    "from events import *",
                    "from enums import *",
                    "from gui import *",
                    "\n\n\n@awake",
                    "def _awake():",
                    "    DOM()",
                ]
            )
        case "config":
            return "\n".join(
                [
                    "from events import *",
                    "from enums import *",
                    "from result import *",
                    "import saves",
                    "\n\n\n@spawn",
                    "def spawn_scene():",
                    "    items.create(Item(id=\"test_item\"))",
                ]
            )
        case "routine":
            return "\n".join(
                [
                    "from audio_helper import Audio",
                    "from input_handler import Input",
                    "from classes import *",
                    "from events import *",
                    "import items",
                    "import pgapi",
                    "\n\n\n@init",
                    "def _init():",
                    "    pass",
                    "\n\n@update",
                    "def _update():",
                    "    pass",
                ]
            )


def main(args):
    # printf.clear_screen()

    if args[0] != "architect":
        args[0] = "architect"

    if len(args) == 0:
        args = ["architect", "-r"]

    if len(args) < 2:
        args.append("-h")

    if args[1] in ["--new-scene", "-ns"]:
        printf.title("Creating New Scene")

        usr_input = input("Scene name: ").lower()
        if usr_input == "":
            printf("@!Aborted$& Scene creation!")
            return

        new_scene_path = os.path.join(*conf.SCENES_PATH, usr_input)
        new_scene_routines = os.path.join(new_scene_path, "routines")
        new_scene_ui = os.path.join(new_scene_path, "ui")

        if os.path.isdir(new_scene_path):
            printf("@!Aborted$& Scene creation, since the scene already exists!")
            return

        os.mkdir(new_scene_path)
        os.mkdir(new_scene_routines)
        os.mkdir(new_scene_ui)

        make_file(os.path.join(new_scene_routines, "main.py"), new_routine("routine"))
        make_file(os.path.join(new_scene_routines, "__config__.py"), new_routine("config", scn_name=usr_input))
        make_file(os.path.join(new_scene_ui, "index.py"), new_routine("gui"))

    if args[1] in ["--new-routine", "-nr"]:
        printf.title("Creating New Routine")

        usr_input = input("Scene name: ").lower()
        if usr_input == "":
            printf("@!Aborted$& Routine creation!")
            return

        new_scene_path = os.path.join(*conf.SCENES_PATH, usr_input)
        new_scene_routines = os.path.join(new_scene_path, "routines")
        new_scene_ui = os.path.join(new_scene_path, "ui")

        if not os.path.isdir(new_scene_path):
            printf("@!Aborted$& Routine creation, since the scene does not exist!")
            return

        usr_input = input("UI routine? (No by default) [Yes/No]: ").lower()
        ui: bool = False

        if usr_input in ["y", "yes"]:
            ui = True

        filename: str = input("Routine Name: ").lower()
        if filename == "":
            printf("@!Aborted$& Routine creation!")
            return

        if not filename.endswith(".py"):
            filename += ".py"

        if ui:
            make_file(os.path.join(new_scene_ui, filename), new_routine(True))
            return

        make_file(os.path.join(new_scene_routines, filename), new_routine(False))

    printf.title(f"Build")

    # Need to serialise these, so that the game can use the files
    # Mostly auto import
    b64encoder.serialise()
    import_generator.serialise_imports()

    build_count_res = attempt(update_read_build_counter, ())

    if args[1] in ["--help", "-h"]:
        printf.title("Architect Help Menu")
        printf.full_line("Architect is the build system for @!Brass$&.")
        printf.full_line("\n@!Command usage:$&")

        printf("    - @!Run the project:$&")
        printf("       ./architect -r")
        printf("       ./architect --run")

        printf("\n    - @!Build the project:$&")
        printf("       ./architect -b")
        printf("       ./architect --build")

        printf("\n    - @!Show this help menu:$&")
        printf("       ./architect -h")
        printf("       ./architect --help")

        printf("\n    - @!Create a new scene:$&")
        printf("       ./architect -ns")
        printf("       ./architect --new-scene")

        printf("\n    - @!Create a new routine:$&")
        printf("       ./architect -nr")
        printf("       ./architect --new-routine")

        return

    if args[1] in ["--run", "-r"]:
        printf.title(f"Run")
        # os.system(f"python {main_file_dir}")
        deps.run_python_command([f"{conf.MAIN_FILE_DIR}", "__main__.py"])
        return

    if args[1] in ["--build", "-b"]:

        # Build case
        printf.title("Building Executable")

        APP_NAME = f"{conf.PROJECT_NAME}-{conf.VERSION}" + (
            f".b{build_count_res.ok()}" if build_count_res.is_ok() else ""
        )

        build_start_time: float = time.perf_counter()
        build_success, build_error = deps.run_python_command(
            [
                "-m",
                "nuitka",
                os.path.join(f"{conf.MAIN_FILE_DIR}", "__main__.py"),
                "--standalone",
                "--windows-disable-console",
                f"--output-dir={os.path.realpath(os.path.join(*conf.BUILD_OUTPUT_DIR))}",
                "--remove-output",
                # "-n",
                # APP_NAME,
            ]
        )

        printf.title("Build Report")

        match build_success:
            case True:
                printf(
                    f"[{round(time.perf_counter() - build_start_time, 5)}s] ✔ Executeable built @!successfully$&!"
                )
                printf(f"Output: {os.path.realpath(os.path.join('dist'))}")
                print("\n\n")
            case False:
                printf(f"✘ @!Failed$& to build executeable!")
                printf(f"Error: \n{build_error}")
                print("\n\n")

        # os.remove(
        #     os.path.join(
        #         f"{conf.PROJECT_NAME}-{conf.VERSION}"
        #         + (f".b{build_count_res.ok()}" if build_count_res.is_ok() else "")
        #         + ".spec"
        #     )
        # )


if __name__ == "__main__":
    args: list[str] = sys.argv
    main(args)
