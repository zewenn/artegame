# pylint: disable = deprecated-module
from distutils.dir_util import copy_tree

# pylint: enable = deprecated-module

from result import Result, Ok, Err
from dataclasses import dataclass
from zenyx import printf
from uuid import uuid4
from typing import *
from deps import *

import __config__ as conf
import os
import re
import shutil


@dataclass
class Routine:
    scene: str
    ui_routine: bool
    filename: str
    path: list[str]
    path_str: str


def copy_directory(src, dst):
    """
    Recursively copy all contents from src directory to dst directory.

    Parameters:
    src (str): Source directory path.

    dst (str): Destination directory path.
    """
    # Create the destination directory if it does not exist
    if not os.path.exists(dst):
        os.makedirs(dst)

    # Loop over all items in the source directory
    for item in os.listdir(src):
        src_path = os.path.join(src, item)
        dst_path = os.path.join(dst, item)

        # If the item is a directory, recursively copy its contents
        if os.path.isdir(src_path):
            copy_directory(src_path, dst_path)
        # If the item is a file, copy it to the destination directory
        else:
            shutil.copy2(src_path, dst_path)


@task("Generating Imports")
def generate_imports_from_directory(directory: str) -> Result[list[str], ValueError]:

    # Get the list of files in the directory
    top = len(
        [x for x in os.listdir(directory) if x.endswith(".py") and x != "__init__.py"]
    )
    file_list: list[str] = []

    for index, filename in enumerate(os.listdir(directory)):
        if not filename.endswith(".py") or filename == "__init__.py":
            continue

        # file_list.append(
        #     f"\nfrom {'.'.join(conf.ROUTINE_PATH[1:])} import "
        #     + filename.replace(".py", "")
        # )
        if filename == "__init__.py":
            print("asdasd")
            continue

        file_list.append(f"\nfrom . import " + filename.replace(".py", ""))

        progress_bar((index + 1), top, shorten(filename))

    file_list.append("\n")

    task_complete()
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
    with open(os.path.join(*conf.SCENES_ENUM_FILE), "w", encoding="utf-8") as wf:
        wf.write("# Generated Scene Enum\n\n")
        for scene in scenes:
            wf.write(f'{scene.upper()}: str = "{scene}"\n')


def multiline_to_singleline_imports(python_code: str) -> str:
    # Regex to find items within parentheses of from-import statements
    pattern = re.compile(r"(\s*import\s*)\(([^)]+)\)", re.DOTALL)

    def replacer(match):
        module_part = match.group(1)
        items_part = match.group(2)

        # Clean the items
        items = [item.strip() for item in items_part.replace("\n", "").split(",")]
        single_line_items = ", ".join(items)

        return f"{module_part}{single_line_items}"

    # Replace multi-line imports with single-line imports
    result = pattern.sub(replacer, python_code)
    return result


def replace_imports(contents: str, level: int = 3) -> str:
    dots = "." * level
    contents = contents.replace("from brass ", f"from {dots} ")
    contents = contents.replace("from brass.", f"from {dots}")
    contents = contents.replace("from src.global_routines ", "from ...temp_global ")
    contents = contents.replace("from src.global_routines.", "from ...temp_global.")
    contents = contents.replace("from ..enums ", f"from {dots}temp_enums ")
    contents = contents.replace("from ..enums.", f"from {dots}temp_enums.")
    contents = contents.replace(
        "from src import enums", f"from {dots} import temp_enums as enums"
    )
    contents = contents.replace("from src.enums ", f"from {dots}temp_enums ")
    contents = multiline_to_singleline_imports(contents)
    return contents


def create_replace_temp(routines: list[Routine], level: int = 3) -> None:
    dots = "." * level
    temp_path = os.path.join(*conf.TEMP_DIR_PATH)

    if not os.path.isdir(temp_path):
        os.mkdir(temp_path)

    delete_files_in_directory(temp_path)

    for routine in routines:
        contents = ""
        with open(routine.path_str, "r", encoding="utf-8") as rf:
            contents = rf.read()

        contents = f"from {dots} import events, scene\n" + contents
        # contents = "import enums\n" + contents
        contents = contents.replace(
            conf.ROUTINE_EVENTS.spawn,
            f"@scene.spawn(enums.scenes.{routine.scene.upper()})\n{conf.ROUTINE_EVENTS.spawn}",
        )
        contents = contents.replace(
            conf.ROUTINE_EVENTS.awake,
            f"@scene.awake(enums.scenes.{routine.scene.upper()})\n{conf.ROUTINE_EVENTS.awake}",
        )
        contents = contents.replace(
            conf.ROUTINE_EVENTS.init,
            f"@scene.init(enums.scenes.{routine.scene.upper()})\n{conf.ROUTINE_EVENTS.init}",
        )
        contents = contents.replace(
            conf.ROUTINE_EVENTS.update,
            f"@scene.update(enums.scenes.{routine.scene.upper()})\n{conf.ROUTINE_EVENTS.update}",
        )
        contents = replace_imports(contents, level)

        with open(
            os.path.join(
                temp_path,
                (
                    ("gui" if routine.ui_routine else "rtn")
                    + "_"
                    + routine.scene.replace("_", "")
                    + "_"
                    + routine.filename[:-3].replace("_", "")
                    + "_"
                    + uuid4().hex
                    + ".py"
                ),
            ),
            "w",
            encoding="utf-8",
        ) as wf:
            wf.write(contents)


@task("Binding GLOBAL Routines")
def build_global_routines() -> None:

    make_dir_walk(conf.GLOBAL_ROUTINES_DIR_DIST_PATH)

    copy_directory(
        os.path.join(*conf.GLOBAL_ROUTINES_DIR_PATH),
        os.path.join(*conf.GLOBAL_ROUTINES_DIR_DIST_PATH),
    )

    global_rtns = os.listdir(os.path.join(*conf.GLOBAL_ROUTINES_DIR_DIST_PATH))

    for item in global_rtns:
        if os.path.isdir(os.path.join(*conf.GLOBAL_ROUTINES_DIR_DIST_PATH, item)):
            global_rtns.remove(item)

    for index, global_rtn in enumerate(global_rtns):
        progress_bar(index + 1, len(global_rtns), shorten(global_rtn))
        # printf.full_line(
        #     f"[{index + 1}/{len(global_rtns)}] Binding GLOBAL Routines: {shorten(global_rtn)} ",
        #     end="\r",
        # )

        contents: str = ""
        with open(
            os.path.join(*conf.GLOBAL_ROUTINES_DIR_DIST_PATH, global_rtn),
            "r",
            encoding="utf-8",
        ) as rf:
            contents = rf.read()

        contents = contents.replace("from src.global_routines ", "from . ")
        contents = contents.replace("from src.global_routines.", "from .")
        # contents = contents.replace("from brass ", "from .. ")
        # contents = contents.replace("from brass.", "from ..")
        contents = replace_imports(contents, 2)

        with open(
            os.path.join(*conf.GLOBAL_ROUTINES_DIR_DIST_PATH, global_rtn),
            "w",
            encoding="utf-8",
        ) as wf:
            wf.write(contents)

    task_complete()


def serialise_imports():
    """
    Binding a script adds it to the `script_import.py` file as an import,
    thus the script runs when the file is loaded.\n
    This is needed with the use event decorators, which - on load - bind functions to events.
    """

    with open(
        os.path.join(*conf.SERIALISED_OUTPUT_DIR, "__init__.py"), "w", encoding="utf-8"
    ) as wf:
        wf.write(
            "\n".join(
                [
                    "from . import (",
                    f"\t{conf.ASSETS_FILE_DIST_PATH[-1].replace('.py', '')},",
                    f"\t{conf.ROUTINE_PATH[-1]}",
                    ")\n",
                ]
            )
        )

    with open(os.path.join(*conf.MAIN_FILE_PATH), "w", encoding="utf-8") as wf:
        wf.write(
            "\n".join(
                [
                    "from brass import init\n",
                    "if __name__ == '__main__':",
                    "\tinit()\n",
                ]
            )
        )

    make_dir_walk(conf.PROJ_ENUMS_DIR_DIST_PATH)
    copy_directory(conf.MAIN_FILE_DIR, os.path.join(*conf.BASE_PATH))
    copy_directory(
        os.path.join(*conf.PROJ_ENUMS_DIR_PATH),
        os.path.join(*conf.PROJ_ENUMS_DIR_DIST_PATH),
    )

    # copy_tree(
    #     os.path.join(conf.MAIN_FILE_DIR),
    #     os.path.join(*conf.BASE_PATH),
    # )

    delete_files_in_directory(os.path.join(*conf.GLOBAL_ROUTINES_DIR_DIST_PATH))
    build_global_routines()

    routines, scenes = get_routines_and_scenes(conf.SCENES_PATH)

    build_scenes_file(scenes)
    create_replace_temp(routines)

    with open(
        os.path.join(*conf.ROUTINE_IMPORT_FILE_PATH),
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
            for _ in range(4):
                content.append("")

        content[2] = help_line
        content[3] = import_line

        wf.write("\n".join(content))


if __name__ == "__main__":
    serialise_imports()
