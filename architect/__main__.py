import deps
from typing import * # type: ignore
import sys
import __config__ as conf
import os


def main() -> None:
    if not (sys.version_info.major == 3 and sys.version_info.minor >= 12):
        print("Architect needs at least python version 3.12 to run!")
        print("\tNote: only python3 is supported")
        return

    deps.title("Initalising")
    print(f"Running Architect on Python {sys.version}")
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
