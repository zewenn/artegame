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
ROUTINE_PATH = ["brass", "routines"] # Old version DONT USE
"""
## DEPRECATED
Use `SCENES_PATH` instead.
"""
SCENES_PATH = ["brass", "scenes"]
ROUTINE_IMPORT_FILE_NAME = "imports.py"
