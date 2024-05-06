from zenyx import printf
import b64encoder, import_generator
import os, sys
import deps
import subprocess, time
from termcolor import colored, cprint
import __config__ as conf


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
    printf.title(f"Building Brass Project : {conf.PROJECT_NAME}")

    # Need to serialise these, so that the game can use the files
    # Mostly auto import
    b64encoder.serialise()
    import_generator.serialise_imports()

    if len(args) < 3:
        args.append("--run")

    if args[2] in ["--build", "-b"]:
        printf.title("Building Executable")
        # os.system(f"python -m PyInstaller --onefile --noconsole {main_file}")
        start_t: float = time.perf_counter()
        build_success, build_error = deps.run_python_command(
            [
                "-m",
                "PyInstaller",
                "--onefile",
                "--noconsole",
                os.path.join(f"{conf.MAIN_FILE_DIR}", "__main__.py"),
                "-n",
                f"{conf.PROJECT_NAME}-{conf.VERSION}",
            ]
        )
        printf.title("Build Report")
        match build_success:
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
                print(f"{crossmark} Error: \n{build_error}")
                print("\n\n")
    elif args[2] in ["--run", "-r"]:
        printf.title("Running Python File")
        # os.system(f"python {main_file_dir}")
        deps.run_python_command([f"{conf.MAIN_FILE_DIR}", "__main__.py"])


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
