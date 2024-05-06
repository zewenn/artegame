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


T = TypeVar("T")


def attempt(func: Callable[..., T], args: Tuple = ()) -> Result[T, Exception]:
    try:
        return Ok(func(args))
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


def main(args):
    printf.clear_screen()

    if args[0] != "architect":
        args[0] = "architect"

    if len(args) == 0:
        args = ["architect", "-r"]

    printf.title(f"Building Brass Project : {conf.PROJECT_NAME}")

    # Need to serialise these, so that the game can use the files
    # Mostly auto import
    b64encoder.serialise()
    import_generator.serialise_imports()

    build_count_res = attempt(update_read_build_counter, ())

    if len(args) < 2:
        args.append("-h")

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

        return

    if args[1] in ["--run", "-r"]:
        printf.title("Running Python File")
        # os.system(f"python {main_file_dir}")
        deps.run_python_command([f"{conf.MAIN_FILE_DIR}", "__main__.py"])
        return

    # Build case
    printf.title("Building Executable")

    build_start_time: float = time.perf_counter()
    build_success, build_error = deps.run_python_command(
        [
            "-m",
            "PyInstaller",
            "--onefile",
            "--noconsole",
            os.path.join(f"{conf.MAIN_FILE_DIR}", "__main__.py"),
            "-n",
            (
                f"{conf.PROJECT_NAME}-{conf.VERSION}"
                + (f".b{build_count_res.ok()}" if build_count_res.is_ok() else "")
            ),
        ]
    )

    printf.title("Build Report")

    match build_success:
        case True:
            tickmark = colored("✔", "green", attrs=["bold"])

            print(f"{tickmark} Executeable built successfully")
            print(
                f"{tickmark} Build time: {int((time.perf_counter() - build_start_time) * 1000) / 1000}s"
            )
            print("\n\n")
        case False:
            crossmark = colored("✕", "red", attrs=["bold"])
            print(f"{crossmark} Failed to build executeable!")
            print(f"{crossmark} Error: \n{build_error}")
            print("\n\n")


if __name__ == "__main__":
    args: list[str] = sys.argv
    main(args)
