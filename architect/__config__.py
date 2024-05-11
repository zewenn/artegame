from dataclasses import dataclass

# For PyInstaller
PROJECT_NAME = "Artegame"
VERSION = "1.2.2"

# For the installer, to install...
DEPENDENCIES = ["pygame", "termcolor", "recordclass", "zenyx", "result", "PyInstaller"]

# For architect to run the correct __main__.py file
MAIN_FILE_DIR = "brass"

# Used to store the output of b64encoder.py and import_generator.py
SERIALISED_OUTPUT_DIR = ["brass", "src"]

# Used for the b64 images and sounds
ASSETS_FILE_NAME = "b64_asset_ref_table.py"

# Used to generate script imports
ROUTINE_PATH = ["brass", "src", "temp"]
SCENES_PATH = ["brass", "scenes"]
SCENES_FILE = ["brass", "scenenum.py"]
@dataclass
class ROUTINE_EVENTS:
    spawn = "@spawn"
    awake = "@awake"
    init = "@init"
    update = "@update"
TEMP_DIR_PATH = ["brass", "src", "temp"]
ROUTINE_IMPORT_FILE_NAME = "imports.py"
