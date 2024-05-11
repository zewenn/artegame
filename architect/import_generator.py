import os, time
from zenyx import printf
from result import Result, Ok, Err
from dataclasses import dataclass
from typing import *
import __config__ as conf
import random


@dataclass
class Routine:
    scene: str
    ui_routine: bool
    filename: str
    path: list[str]
    path_str: str


def delete_files_in_directory(directory_path):
    try:
        files = os.listdir(directory_path)
        for index, file in enumerate(files):
            file_path = os.path.join(directory_path, file)
            if os.path.isfile(file_path):
                os.remove(file_path)
            print(f"[{index + 1}/{len(files)}] Removing: {file[:16]}...", end="\r")
        print("")
    except OSError as e:
        print("Error occurred while deleting files: \n", e)


def generate_imports_from_directory(directory: str) -> Result[list[str], ValueError]:

    # Get the list of files in the directory
    file_list: list[str] = []
    for index, filename in enumerate(os.listdir(directory)):
        if filename.endswith(".py"):
            file_list.append(f"\nfrom {'.'.join(conf.ROUTINE_PATH[1:])} import " + filename.replace(".py", ""))
            out_txt = f"[{index + 1}/{len(file_list)}] Binding Routines: {filename[:16]}..."
            printf.full_line(out_txt, end="\r")
    print("")
    return Ok(file_list)


def get_python_files(from_dir: str) -> list[str]:
    res: list[str] = []
    for filename in os.listdir(from_dir):
        if filename.endswith(".py"):
            res.append(filename)
    return res


def get_routines_and_scenes(from_dir: list[str]) -> Tuple[list[Routine], list[str]]:
    res: list[Routine] = []

    parent_dir: str = os.path.realpath(os.path.join(*from_dir))
    parent_dir_parts: list[str] = parent_dir.split(os.sep)

    brass_index: int
    try:
        brass_index = parent_dir_parts.index("brass") + 1
    except Exception:
        brass_index = 0

    scenes: list[str] = []

    for filename in os.listdir(parent_dir):
        if os.path.isdir(os.path.join(parent_dir, filename)):
            scenes.append(filename)

    for scene in scenes:
        pth = os.path.join(parent_dir, scene)
        ui_dir = os.path.join(pth, "ui")
        routines_dir = os.path.join(pth, "routines")

        ui_py_files: list[str] = []
        routines_py_files: list[str] = []

        if os.path.isdir(ui_dir):
            ui_py_files = get_python_files(ui_dir)

        if os.path.isdir(routines_dir):
            routines_py_files = get_python_files(routines_dir)

        for ui_r in ui_py_files:
            res.append(
                Routine(
                    scene=scene,
                    ui_routine=True,
                    filename=ui_r,
                    path=(
                        (
                            parent_dir_parts[brass_index:-1]
                            + ["scenes", scene, "ui", ui_r]
                        )
                    ),
                    path_str=os.path.join(pth, "ui", ui_r),
                )
            )

        for r_r in routines_py_files:
            res.append(
                Routine(
                    scene=scene,
                    ui_routine=False,
                    filename=r_r,
                    path=(
                        parent_dir_parts[brass_index:-1]
                        + ["scenes", scene, "routines", r_r]
                    ),
                    path_str=os.path.join(pth, "routines", r_r),
                )
            )
    return (res, scenes)


def build_scenes_file(scenes: list[str]) -> None:
    with open(os.path.join(*conf.SCENES_FILE), "w", encoding="utf-8") as wf:
        wf.write("# Generating scenes enum\n\n")
        wf.write("from events import Scene\n\n")
        wf.write("class SCENES:\n\n")
        for scene in scenes:
            wf.write(f'\t{scene.upper()}: Scene = Scene("{scene}")\n')


def create_replace_temp(routines: list[Routine]) -> None:
    temp_path = os.path.join(*conf.TEMP_DIR_PATH)

    if not os.path.isdir(temp_path):
        os.mkdir(temp_path)

    delete_files_in_directory(temp_path)

    for routine in routines:
        contents = ""
        with open(routine.path_str, "r", encoding="utf-8") as rf:
            contents = rf.read()

        contents = "from scenenum import SCENES\n" + contents
        contents = contents.replace(
            conf.ROUTINE_EVENTS.spawn, f"@SCENES.{routine.scene.upper()}.spawn"
        )
        contents = contents.replace(
            conf.ROUTINE_EVENTS.awake, f"@SCENES.{routine.scene.upper()}.awake"
        )
        contents = contents.replace(
            conf.ROUTINE_EVENTS.init, f"@SCENES.{routine.scene.upper()}.initalise"
        )
        contents = contents.replace(
            conf.ROUTINE_EVENTS.update, f"@SCENES.{routine.scene.upper()}.update"
        )

        with open(
            os.path.join(
                temp_path,
                f"r{random.randint(0, 100000000)}_{routine.scene}_{routine.filename[:-3]}_{routine.ui_routine}.py",
            ),
            "w",
            encoding="utf-8",
        ) as wf:
            wf.write(contents)


def serialise_imports():
    """
    Binding a script adds it to the `script_import.py` file as an import,
    thus the script runs when the file is loaded.\n
    This is needed with the use event decorators, which - on load - bind functions to events.
    """

    routines, scenes = get_routines_and_scenes(conf.SCENES_PATH)

    build_scenes_file(scenes)
    create_replace_temp(routines)

    with open(
        os.path.join(*conf.SERIALISED_OUTPUT_DIR, conf.ROUTINE_IMPORT_FILE_NAME),
        "w",
        encoding="utf8",
    ) as wf:
        content: list[str] = []

        help_line: str = f"# Importing scripts, so they can run"

        import_list = generate_imports_from_directory(os.path.join(*conf.ROUTINE_PATH))
        if import_list.is_err():
            printf("Failed to import scripts: Wrong path")
            return

        import_line: str = " ".join(import_list.ok())

        if len(content) < 4:
            for i in range(4):
                content.append("")

        content[2] = help_line
        content[3] = import_line

        wf.write("\n".join(content))


if __name__ == "__main__":
    serialise_imports()
