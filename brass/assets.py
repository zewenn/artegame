from base import *
from enums.gui import FONT_SIZE
from io import BytesIO
import base64
import pygame

from src.b64_asset_ref_table import REFERENCE_TABLE as b64_ref_table


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


def use(filename: string, T: Optional[UT] = None) -> UT:
    res = ASSETS.get(filename)

    if res == None:
        unreachable(f'Asset "{filename}" does not exist!')
    
    if T != None and type(res) != T:
        unreachable(f'Asset "{filename}" cannot fit constaints: {T}')

    return res


def create_runtime_objects(ratio: int = 1):
    for filename, b64_value in b64_ref_table.items():
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
