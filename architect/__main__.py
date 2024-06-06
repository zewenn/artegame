import deps
from typing import *
import sys
import __config__ as conf
import os


def main() -> None:
    # print("\033[4A")
    # deps.full_line("")
    deps.title("Initalising")
    print("Performing a dependecy check...\n")

    res = deps.handle_dep_stack(conf.DEPENDENCIES)
    if isinstance(res, Exception):
        print("\nunreachable: Critical dependency not found!")
        return

    success, err = deps.run_python_command(
        [os.path.join(os.path.dirname(__file__), "cli.py"), *sys.argv[1:]]
    )

    if not success:
        print(f"Error happened while running architect:", err)


if __name__ == "__main__":
    main()
