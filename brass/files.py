import base64
from io import BytesIO
import pygame

from src.b64_asset_ref_table import REFERENCE_TABLE as b64_ref_table

def load(name: str, base64_string: str):
    # Convert the Base64 string to bytes
    binary_data = base64.b64decode(base64_string)

    # Create a BytesIO object from the binary data
    data_buffer = BytesIO(binary_data)

    res: pygame.Surface | pygame.Sound

    # Open the data using Pygame
    if (not name.endswith(".mp3")):
        res = pygame.image.load(data_buffer)
    else:
        res = pygame.mixer.Sound(data_buffer)

    return res


ASSETS = {}


def init():
    for filename, b64_value in b64_ref_table.items():
        ASSETS[filename] = load(filename, b64_value)
