from zenyx import printf
import b64encoder, add_scripts
import os, sys
import subprocess, time
from termcolor import colored, cprint


def run_command(command_list: list[str]):
    try:
        # Run the command and capture the return code
        result = subprocess.run(command_list, check=True)

        # Check the return code
        if result.returncode == 0:
            return True, None
        else:
            error_output = (
                result.stderr.decode("utf-8") if result.stderr is not None else None
            )
            return False, error_output
    except subprocess.CalledProcessError as e:
        # An error occurred (non-zero exit code)
        error_output = e.stderr.decode("utf-8") if e.stderr is not None else None
        return False, e


def test():
    printf.title("Running Test")
    os.system("python __test__.py")
    print("\n\n")


def brass(args):
    printf.title("Building brass")

    main_file_dir: str = "brass"

    # Base tasks
    b64encoder.init()
    add_scripts.init()

    if len(args) < 3:
        print(args)
        args.append("--run")

    if args[2] in ["--build", "--b"]:
        printf.title("Building Executable")
        # os.system(f"python -m PyInstaller --onefile --noconsole {main_file}")
        start_t: float = time.perf_counter()
        run_test, error = run_command(
            [
                "python",
                "-m",
                "PyInstaller",
                "--onefile",
                "--noconsole",
                os.path.join(f"{main_file_dir}", "__main__.py"),
            ]
        )
        printf.title("Build Report")
        match run_test:
            case True:
                tickmark = colored("✔", "green", attrs=["bold"])

                print(f"{tickmark} Executeable built successfully")
                print(
                    f"{tickmark} Build time: {int((time.perf_counter() - start_t) * 1000) / 1000}s"
                )
                print("\n\n")
            case False:
                crossmark = colored("✕", "red", attrs=["bold"])
                print(f"{crossmark} Failed to build executeable!")
                print(f"{crossmark} Error: \n{error}")
                print("\n\n")
    elif args[2] in ["--run", "--r"]:
        printf.title("Running Python File")
        os.system(f"python {main_file_dir}")


def main(args):
    printf.clear_screen()

    if args[0] != "architect":
        args[0] = "architect"

    if len(args) == 0:
        args = ["architect", "-a", "-r"]

    if len(args) < 2:
        args = ["architect", "a", "--run"]
    if args[1] not in ["a", "app", "t", "test"]:
        args = ["architect", "a", args[1]]

    if args[1] in ["a", "app"]:
        brass(args=args)
    elif args[1] in ["t", "test"]:
        test()


if __name__ == "__main__":
    args: list[str] = sys.argv
    main(args)
