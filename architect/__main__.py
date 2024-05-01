from deps import *
from typing import *


dependencies = ["pygame", "termcolor", "recordclass", "zenyx", "result"]


def main() -> None:
    title("Dependency check")

    dep_stack(dependencies)
    subprocess.check_call(
        [sys.executable, os.path.join(os.path.dirname(__file__), "mn.py")]
    )


if __name__ == "__main__":
    main()
