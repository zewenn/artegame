from .enums.gui import FONT_SIZE
from io import BytesIO
import base64
import pygame

from .base import *

# pylint: disable=import-error, no-name-in-module
# pyright: reportMissingImports=false
from .temp.b64_asset_ref_table import REFERENCE_TABLE as original_b64_ref_table

# pylint: enable=import-error


b64_ref_table: dict[string, string] = original_b64_ref_table


def load(name: string, base64_string: string, font_size=12):
    # Convert the Base64 string to bytes
    binary_data = base64.b64decode(base64_string)

    # Create a BytesIO object from the binary data
    data_buffer = BytesIO(binary_data)

    res: pygame.Surface | pygame.mixer.Sound

    # Open the data using Pygame
    if name.endswith(".mp3"):
        res = Audio(pygame.mixer.Sound(data_buffer), 1, False, 0)
    elif name.endswith(".ttf"):
        res = pygame.font.Font(data_buffer, font_size)
    else:
        res = pygame.image.load_extended(data_buffer)

    return res


ASSETS: dict[string, Surface | Audio | Font] = {}


UT = TypeVar("UT", type[Surface], type[Audio], type[Font])


def use(filename: string, T_type: Optional[UT] = None) -> UT:
    res = ASSETS.get(filename)

    if res is None:
        unreachable(f'Asset "{filename}" does not exist!')

    if T_type is not None and isinstance(res, T_type):
        unreachable(f'Asset "{filename}" cannot fit constaints: {T_type}')

    return res


def create_runtime_objects(ratio: int = 1):
    for filename, b64_value in b64_ref_table.items():

        # if (
        #     not filename.endswith(".mp3")
        #     or not filename.endswith(".wav")
        #     or not filename.endswith(".png")
        #     or not filename.endswith(".ttf")
        # ):
            
        #     unreachable(
        #         f"Invalid file type: " + "'." + filename.split(".")[1] + "'"
        #         if "." in filename
        #         else filename
        #     )

        if not filename.endswith(".ttf"):
            ASSETS[filename] = load(filename, b64_value)
            continue

        # Handling font size, since the pygame can't

        ASSETS[f"font-{FONT_SIZE.EXTRA_SMALL}-{filename}"] = load(
            filename, b64_value, round(FONT_SIZE.EXTRA_SMALL * ratio)
        )
        ASSETS[f"font-{FONT_SIZE.SMALL}-{filename}"] = load(
            filename, b64_value, round(FONT_SIZE.SMALL * ratio)
        )
        ASSETS[f"font-{FONT_SIZE.MEDIUM}-{filename}"] = load(
            filename, b64_value, round(FONT_SIZE.MEDIUM * ratio)
        )
        ASSETS[f"font-{FONT_SIZE.BIG}-{filename}"] = load(
            filename, b64_value, round(FONT_SIZE.BIG * ratio)
        )
        ASSETS[f"font-{FONT_SIZE.LARGE}-{filename}"] = load(
            filename, b64_value, round(FONT_SIZE.LARGE * ratio)
        )
        ASSETS[f"font-{FONT_SIZE.EXTRA_LARGE}-{filename}"] = load(
            filename, b64_value, round(FONT_SIZE.EXTRA_LARGE * ratio)
        )
