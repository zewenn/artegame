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


def new_routine(T_type: Literal["gui"] | Literal["routine"] | Literal["config"]) -> str:
    filepath_dict: dict[str, str] = {
        "gui": os.path.join(*conf.TEMPLATE_FILES_DIR, "gui.tpy"),
        "routine": os.path.join(*conf.TEMPLATE_FILES_DIR, "rtn.tpy"),
        "config": os.path.join(*conf.TEMPLATE_FILES_DIR, "cnf.tpy"),
    }

    res = ""
    with open(filepath_dict[T_type], "r", encoding="utf-8") as rf:
        res = rf.read()
    return res


def main(arguments):
    # printf.clear_screen()

    if arguments[0] != "architect":
        arguments[0] = "architect"

    if len(arguments) == 0:
        arguments = ["architect", "-r"]

    if len(arguments) < 2:
        arguments.append("-h")

    if arguments[1] in ["--new-scene", "-ns"]:
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
        make_file(os.path.join(new_scene_routines, "conf.py"), new_routine("config"))
        make_file(os.path.join(new_scene_ui, "index.py"), new_routine("gui"))

    if arguments[1] in ["--new-routine", "-nr"]:
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
            make_file(os.path.join(new_scene_ui, filename), new_routine("gui"))
            return

        make_file(os.path.join(new_scene_routines, filename), new_routine("routine"))

    printf.title(f"Architect")

    # Need to serialise these, so that the game can use the files
    # Mostly auto import
    print("[Task : Removing wrapped]")
    deps.delete_files_in_directory(conf.BASE_PATH)

    b64encoder.serialise()
    # return
    import_generator.serialise_imports()

    build_count_res = attempt(update_read_build_counter, ())

    if arguments[1] in ["--help", "-h"]:
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

    if arguments[1] in ["--run", "-r"]:
        printf.title(f"Run")
        # os.system(f"python {main_file_dir}")
        pth = os.path.join(*conf.MAIN_FILE_PATH)
        # print(pth)
        deps.run_python_command((pth,))
        return

    if arguments[1] in ["--build", "-b"]:

        # Build case
        printf.title("Building Executable")

        APP_NAME = f"{conf.PROJECT_NAME.lower()}-v{conf.VERSION.replace('.', '_')}" + (
            f".b{build_count_res.ok()}" if build_count_res.is_ok() else ""
        )

        build_start_time: float = time.perf_counter()
        
        deps.delete_files_in_directory(conf.BUILD_OUTPUT_DIR)

        build_success, build_error = deps.run_python_command(
            [
                "-m",
                "nuitka",
                os.path.join(*conf.MAIN_FILE_PATH),
                "--standalone",
                "--follow-imports",
                # "--plugin-enable=pygame",
                "--disable-console",
                # "--windows-disable-console",
                # "--windows-disable-console",
                "--remove-output",
                (
                    "--run"
                    if "-r" in arguments[2:]
                    else ""
                    f"--output-dir={os.path.realpath(os.path.join(*conf.BUILD_OUTPUT_DIR))}"
                ),
                # "-n",
                # APP_NAME,
            ]
        )

        os.rename(
            os.path.join(
                *conf.BUILD_OUTPUT_DIR, conf.MAIN_FILE_PATH[-1].replace(".py", ".dist")
            ),
            os.path.join(*conf.BUILD_OUTPUT_DIR, APP_NAME),
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
