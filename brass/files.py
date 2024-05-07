import base64
from io import BytesIO
import pygame
from enums import FONT_SIZE

from src.b64_asset_ref_table import REFERENCE_TABLE as b64_ref_table

def load(name: str, base64_string: str, font_size = 12):
    # Convert the Base64 string to bytes
    binary_data = base64.b64decode(base64_string)

    # Create a BytesIO object from the binary data
    data_buffer = BytesIO(binary_data)

    res: pygame.Surface | pygame.mixer.Sound

    # Open the data using Pygame
    if name.endswith(".mp3"):
        res = pygame.mixer.Sound(data_buffer)
    elif name.endswith(".ttf"):
        res = pygame.font.Font(data_buffer, font_size)
    else:
        res = pygame.image.load(data_buffer)

    return res


ASSETS: dict[str, pygame.Surface | pygame.mixer.Sound | pygame.font.Font] = {}

def asset(filename: str) -> pygame.Surface | pygame.mixer.Sound | pygame.font.Font:
    return ASSETS[filename]

def init():
    for filename, b64_value in b64_ref_table.items():
        if (not filename.endswith(".ttf")):
            ASSETS[filename] = load(filename, b64_value)
            continue

        ASSETS[f"font-{FONT_SIZE.EXTRA_SMALL}-{filename}"] = load(filename, b64_value, FONT_SIZE.EXTRA_SMALL)
        ASSETS[f"font-{FONT_SIZE.SMALL}-{filename}"] = load(filename, b64_value, FONT_SIZE.SMALL)
        ASSETS[f"font-{FONT_SIZE.MEDIUM}-{filename}"] = load(filename, b64_value, FONT_SIZE.MEDIUM)
        ASSETS[f"font-{FONT_SIZE.BIG}-{filename}"] = load(filename, b64_value, FONT_SIZE.BIG)
        ASSETS[f"font-{FONT_SIZE.LARGE}-{filename}"] = load(filename, b64_value, FONT_SIZE.LARGE)
        ASSETS[f"font-{FONT_SIZE.EXTRA_LARGE}-{filename}"] = load(filename, b64_value, FONT_SIZE.EXTRA_LARGE)

