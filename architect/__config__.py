# For nuitka
PROJECT_NAME = "Artegame"
VERSION = "2.0.0"

# For the installer, to install...
DEPENDENCIES = [
    "pygame",
    "termcolor",
    "recordclass",
    "zenyx",
    "result",
    "nuitka",
    "screeninfo",
]

# For architect to run the correct __main__.py file
MAIN_FILE_DIR = "brass"
MAIN_FILE_NAME = PROJECT_NAME.lower() + ".py"
BUILD_OUTPUT_DIR = ["dist", "build"]
TEMPLATE_FILES_DIR = ["architect", "templates"]

BASE_PATH = ["dist", "wrapped", "brass"]
MAIN_FILE_PATH = ["dist", "wrapped", MAIN_FILE_NAME]

# Used to store the output of b64encoder.py and import_generator.py
SERIALISED_OUTPUT_DIR = [*BASE_PATH, "temp"]

# Used for the b64 images and sounds
ASSETS_DIR_PATH = ["src", "assets"]
ASSETS_FILE_DIST_PATH = [*SERIALISED_OUTPUT_DIR, "b64_asset_ref_table.py"]

# Used to generate script imports
ROUTINE_PATH = [*SERIALISED_OUTPUT_DIR, "rtns"]
SCENES_PATH = ["src", "scenes"]
SCENES_ENUM_FILE = ["brass", "enums", "scenes.py"]

GLOBAL_ROUTINES_DIR_PATH = ["src", "global_routines"]
GLOBAL_ROUTINES_DIR_DIST_PATH = [*BASE_PATH, "temp_global"]

PROJ_ENUMS_DIR_PATH = ["src", "enums"]
PROJ_ENUMS_DIR_DIST_PATH = [*BASE_PATH, "temp_enums"]

class ROUTINE_EVENTS:
    spawn = "def spawn("
    awake = "def awake("
    init = "def init("
    update = "def update("


TEMP_DIR_PATH = [*SERIALISED_OUTPUT_DIR, "rtns"]
ROUTINE_IMPORT_FILE_PATH = [*SERIALISED_OUTPUT_DIR, "rtns", "__init__.py"]
