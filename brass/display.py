from .base import *

import threading
from . import (
    pgapi,
    items,
    events
)
from .assets import ASSETS
from .gui import *
import pygame
import math

DIRTY_RECTS: list[pygame.Rect] = []


SURFACE_CHACHE: dict[string, Surface] = {}


def is_same_transform(a: Transform, b: Transform) -> bool:
    if a is None or b is None:
        return False

    if (
        a.rotation.x == b.rotation.x
        and a.rotation.y == b.rotation.y
        and a.rotation.z == b.rotation.z
        and a.scale.x == b.scale.x
        and a.scale.y == b.scale.y
    ):
        return True
    return False


def is_on_screen(item: Item) -> bool:
    if (
        item.transform.position.x >= 0
        and (
            item.transform.position.x + item.transform.scale.x
            <= pgapi.SETTINGS.screen_size.x
        )
        and item.transform.position.y >= 0
        and (
            item.transform.position.y + item.transform.scale.y
            <= pgapi.SETTINGS.screen_size.y
        )
    ):
        return True
    return False


def calculate_transform_cache(item: Item) -> None:
    # Get the image either from sprite or by creating a colored surface
    if item.sprite is not None:
        image = ASSETS[item.sprite]
    else:
        image = pygame.Surface((item.transform.scale.x, item.transform.scale.y))
        image.fill(tuple(item.fill_color))

    # Scale the image
    pixel_ratio = pgapi.CAMERA.pixel_unit_ratio
    scale_x = int(item.transform.scale.x * pixel_ratio)
    scale_y = int(item.transform.scale.y * pixel_ratio)
    scaled_image = pygame.transform.scale(image, (scale_x, scale_y))

    # Rotate the image
    return pygame.transform.rotate(scaled_image, item.transform.rotation.z)


def render_item(item: Item):
    if item.transform is None or (item.sprite is None and item.fill_color is None):
        return

    same_transform: bool = is_same_transform(item.transform, item.transform_cache)

    if (
        SURFACE_CHACHE.get(item.uuid) is None
        or not same_transform
        or item.sprite != item.sprite_cache
    ):
        SURFACE_CHACHE[item.uuid] = calculate_transform_cache(item)
        item.transform_cache = structured_clone(item.transform)
        item.sprite_cache = item.sprite

    screen_center_x = pgapi.SETTINGS.screen_size.x / 2
    screen_center_y = pgapi.SETTINGS.screen_size.y / 2

    camera_pos_x = pgapi.CAMERA.position.x * -1
    camera_pos_y = pgapi.CAMERA.position.y * -1

    item_pos_x = item.transform.position.x
    item_pos_y = item.transform.position.y

    pixel_ratio = pgapi.CAMERA.pixel_unit_ratio

    rotated_rect = SURFACE_CHACHE.get(item.uuid).get_rect()
    rotated_rect.center = (
        screen_center_x + (camera_pos_x + item_pos_x) * pixel_ratio,
        screen_center_y + (camera_pos_y + item_pos_y) * pixel_ratio,
    )

    # Blit the rotated image onto the screen
    if item.crop is None:
        DIRTY_RECTS.append(
            pgapi.SCREEN.this.blit(SURFACE_CHACHE.get(item.uuid), rotated_rect.topleft)
        )
        return

    crop_start_x = item.crop.start.x * pixel_ratio
    crop_start_y = item.crop.start.y * pixel_ratio
    crop_end_x = item.crop.end.x * pixel_ratio
    crop_end_y = item.crop.end.y * pixel_ratio

    DIRTY_RECTS.append(
        pgapi.SCREEN.this.blit(
            SURFACE_CHACHE.get(item.uuid),
            rotated_rect.topleft,
            (crop_start_x, crop_start_y, crop_end_x, crop_end_y),
        )
    )


def render_bone(bone: Bone, parent: Item):
    if bone.transform is None or (bone.sprite is None and bone.fill_color is None):
        return

    # Determine the image to use
    if bone.sprite is not None:
        image = ASSETS[bone.sprite]
    else:
        image = pygame.Surface((bone.transform.scale.x, bone.transform.scale.y))
        image.fill(tuple(bone.fill_color))

    # Compute the pixel unit ratio and scale the image
    pixel_ratio = pgapi.CAMERA.pixel_unit_ratio
    scale_x = int(bone.transform.scale.x * pixel_ratio)
    scale_y = int(bone.transform.scale.y * pixel_ratio)
    scaled_image = pygame.transform.scale(image, (scale_x, scale_y))

    # Calculate rotation angle
    bone_rotation = bone.transform.rotation.z
    parent_rotation = parent.transform.rotation.z
    rotation_angle = 2 * bone_rotation + (parent_rotation - bone_rotation)

    # Rotate the image
    rotated_image = pygame.transform.rotate(scaled_image, rotation_angle)

    # Precompute trigonometric functions for position calculation
    cos_theta = math.cos(math.radians(-parent_rotation))
    sin_theta = math.sin(math.radians(-parent_rotation))

    # Calculate the rotated rect position
    screen_center_x = pgapi.SETTINGS.screen_size.x / 2
    screen_center_y = pgapi.SETTINGS.screen_size.y / 2
    camera_pos_x = pgapi.CAMERA.position.x * -1
    camera_pos_y = pgapi.CAMERA.position.y * -1
    parent_pos_x = parent.transform.position.x
    parent_pos_y = parent.transform.position.y
    bone_pos_x = bone.transform.position.x
    bone_pos_y = bone.transform.position.y
    bone_anchor_x = bone.anchor.x
    bone_anchor_y = bone.anchor.y

    final_x = (
        screen_center_x
        + (
            camera_pos_x
            + parent_pos_x
            + (bone_pos_x * cos_theta - bone_pos_y * sin_theta)
            + bone_anchor_x
        )
        * pixel_ratio
    )
    final_y = (
        screen_center_y
        + (
            camera_pos_y
            + parent_pos_y
            + (bone_pos_x * sin_theta + bone_pos_y * cos_theta)
            + bone_anchor_y
        )
        * pixel_ratio
    )

    rotated_rect = rotated_image.get_rect(center=(final_x, final_y))

    # Blit the rotated image onto the screen
    DIRTY_RECTS.append(pgapi.SCREEN.this.blit(rotated_image, rotated_rect.topleft))


def render_gui(element: GUIElement, parent_style: StyleSheet = None) -> None:
    if parent_style is None:
        parent_style = DOM_El.current_style

    elstl = element.current_style

    if elstl.display == "none":
        return

    # Set default values and units
    x, y = element.transform.position.x, element.transform.position.y
    w = element.transform.scale.x
    h = element.transform.scale.y

    if w < 0 or h < 0:
        return

    # Background color and alpha
    bg_color = list(elstl.bg_color if elstl.bg_color else (0, 0, 0, 0))
    bg_color[3] = min(max(bg_color[3], 0), 1) * 255

    # Text color and alpha
    color = list(elstl.color if elstl.color else (255, 255, 255, 1))
    color[3] = min(max(color[3], 0), 1) * 255

    # Font settings
    font_size = elstl.font_size if elstl.font_size else 16
    font_family = elstl.font_family if elstl.font_family else "inter.ttf"
    bold = "bold" in elstl.font_variant if elstl.font_variant else False
    italic = "italic" in elstl.font_variant if elstl.font_variant else False
    gap = unit(elstl.gap if elstl.gap else "0x")

    # Create image surface
    if not elstl.bg_image:
        # pylint: disable=no-member
        image = attempt(pygame.Surface, ((w, h), pygame.SRCALPHA))
        # pylint: enable=no-member

        if image.is_err():
            print(image.err().msg)
            return

        image = image.ok()

        image.fill(bg_color)
    else:
        image = pygame.transform.scale(ASSETS[elstl.bg_image], (w, h))

    positioned_rect = image.get_rect(topleft=(x, y))

    DIRTY_RECTS.append(pgapi.SCREEN.this.blit(image, positioned_rect.topleft))

    p_style = StyleSheet(
        position=elstl.position,
        left=f"{x}x",
        top=f"{y}x",
        width=f"{w}x",
        height=f"{h}x",
        bg_color=bg_color,
        color=color,
        gap=gap,
    )

    child_strings_count = 0

    for child in element.children:
        if not isinstance(child, str):
            render_gui(child, p_style)
        else:
            font = ASSETS[f"font-{font_size}-{font_family}"]
            font.italic = italic
            font.bold = bold
            text_surf = font.render(child, True, color)
            text_surf.set_alpha(color[3])
            DIRTY_RECTS.append(
                pgapi.SCREEN.this.blit(
                    text_surf, (x, y + (font_size + gap) * child_strings_count)
                )
            )
            child_strings_count += 1


def load_tiles(image: Surface, tile_width: int, tile_height: int) -> list[Surface]:
    tiles: list[Surface] = []
    for y in range(0, image.get_height(), tile_height):
        for x in range(0, image.get_width(), tile_width):
            if (
                x + tile_width <= image.get_width()
                and y + tile_height <= image.get_height()
            ):
                rect = pygame.Rect(x, y, tile_width, tile_height)
                tile = image.subsurface(rect)
                tiles.append(tile)
    return tiles


def render_items() -> None:
    for item in items.rendering:
        # render_thread = threading.Thread(
        #     target=render_one,
        #     args=(item,)
        # )
        # render_thread.setDaemon(True)

        # render_thread.start()

        if (
            not item.render
            # and is_on_screen(item)
        ):
            continue

        # render_thread = threading.Thread(target=render_item, args=(item,))
        # bone_thread = None
        render_item(item)

        if item.bones is None:
            continue

        for bone in item.bones.values():
            # bone_thread = threading.Thread(target=render_bone, args=(bone, item))
            render_bone(bone, item)

        # render_thread.start()
        # if bone_thread:
        #     bone_thread.start()
        # render_thread.join()
        # if bone_thread:
        #     bone_thread.join()


def render():
    global DIRTY_RECTS
    # render_background(BACKGROUND, NUM_TILES_X)
    if pgapi.SETTINGS.background_image is not None:
        DIRTY_RECTS.append(
            pgapi.SCREEN.this.blit(
                pgapi.SETTINGS.background_image,
                (
                    pgapi.SCREEN.size.x / 2
                    + (-pgapi.CAMERA.position.x - pgapi.SETTINGS.background_size.x / 2)
                    * pgapi.CAMERA.pixel_unit_ratio,
                    pgapi.SCREEN.size.y / 2
                    + (-pgapi.CAMERA.position.y - pgapi.SETTINGS.background_size.y / 2)
                    * pgapi.CAMERA.pixel_unit_ratio,
                ),
            )
        )
    render_items()
    attempt(render_gui, (DOM_El,))

    pygame.display.update(DIRTY_RECTS)
    DIRTY_RECTS = []
