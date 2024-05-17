from deps import *
from typing import *
import sys
import __config__ as conf


def main() -> None:
    title("Architect")
    print("Performing a dependecy check...\n")

    res = handle_dep_stack(conf.DEPENDENCIES)
    if isinstance(res, Exception):
        print("\n\nERROR: Critical dependency not found!")
        return

    success, err = run_python_command(
        [os.path.join(os.path.dirname(__file__), "cli.py"), *sys.argv[1:]]
    )

    if not success:
        print(f"Error happened while running architect:", err)


if __name__ == "__main__":
    main()
