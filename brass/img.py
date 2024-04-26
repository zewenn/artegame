import base64
from io import BytesIO
import pygame

from src.image_b64 import REFERENCE_TABLE as b64_ref_table

def load(base64_string: str):
    # Convert the Base64 string to bytes
    binary_data = base64.b64decode(base64_string)

    # Create a BytesIO object from the binary data
    image_buffer = BytesIO(binary_data)

    # Open the image using Pygame
    image = pygame.image.load(image_buffer)

    return image


surface_ref_table = {}


def init():
    for key, value in b64_ref_table.items():
        surface_ref_table[key] = load(value)
