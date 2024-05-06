from deps import *
from typing import *
import sys
import __config__ as conf


def main() -> None:
    title("Dependency check")

    dep_stack(conf.DEPENDENCIES)
    # print([sys.executable, os.path.join(os.path.dirname(__file__), "architect_main.py"), *sys.argv[1:]])

    success, err = run_python_command(
        [os.path.join(os.path.dirname(__file__), "architect_main.py"), *sys.argv[1:]]
    )

    if not success:
        print(f"Error happened while running architect:", err)


if __name__ == "__main__":
    main()
