# For nuitka
PROJECT_NAME = "Artegame"
VERSION = "1.4.4"

# For the installer, to install...
DEPENDENCIES = ["pygame", "termcolor", "recordclass", "zenyx", "result", "nuitka", "screeninfo"]

# For architect to run the correct __main__.py file
MAIN_FILE_DIR = "brass"
BUILD_OUTPUT_DIR = ["dist"]
TEMPLATE_FILES_DIR = ["architect", "templates"]

# Used to store the output of b64encoder.py and import_generator.py
SERIALISED_OUTPUT_DIR = ["brass", "src"]

# Used for the b64 images and sounds
ASSETS_DIR_PATH = ["src", "assets"]
ASSETS_FILE_DIST_NAME = "b64_asset_ref_table.py"

# Used to generate script imports
ROUTINE_PATH = ["brass", "src", "temp"]
SCENES_PATH = ["src", "scenes"]
SCENES_ENUM_FILE = ["brass", "enums", "scenes.py"]
GLOBAL_ROUTINES_DIR_PATH = ["src", "global_routines"]
GLOBAL_ROUTINES_DIR_DIST_PATH = ["brass", "src", "global_routines"]


class ROUTINE_EVENTS:
    spawn = "def spawn("
    awake = "def awake("
    init = "def init("
    update = "def update("


TEMP_DIR_PATH = ["brass", "src", "temp"]
ROUTINE_IMPORT_FILE_NAME = "imports.py"
