from deps import *
from typing import *
import sys

dependencies = ["pygame", "termcolor", "recordclass", "zenyx", "result", "PyInstaller"]


def main() -> None:
    title("Dependency check")

    dep_stack(dependencies)
    # print([sys.executable, os.path.join(os.path.dirname(__file__), "architect_main.py"), *sys.argv[1:]])

    subprocess.check_call(
        [sys.executable, os.path.join(os.path.dirname(__file__), "architect_main.py"), *sys.argv[1:]]
    )


if __name__ == "__main__":
    main()
