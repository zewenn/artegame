import pgapi
from files import ASSETS
from entities import *
from ui import *
import pygame
import math


def is_on_screen(item: Item) -> bool:
    if (
        item.transform.position.x >= 0
        and (
            item.transform.position.x + item.transform.scale.x
            <= pgapi.SETTINGS.screen_size[0]
        )
        and item.transform.position.y >= 0
        and (
            item.transform.position.y + item.transform.scale.y
            <= pgapi.SETTINGS.screen_size[1]
        )
    ):
        return True
    return False


def render_item(item: Item):
    if item.transform is None or (item.sprite is None and item.fill_color is None):
        return

    image: pygame.Surface

    if item.sprite is not None:
        image = ASSETS[item.sprite]
    elif item.fill_color is not None:
        image = pygame.Surface((item.transform.scale.x, item.transform.scale.y))
        image.fill(tuple(item.fill_color))
    else:
        return

    # Scale the image
    scaled_image = pygame.transform.scale(
        image,
        (
            int(item.transform.scale.x * pgapi.CAMERA.pixel_unit_ratio),
            int(item.transform.scale.y * pgapi.CAMERA.pixel_unit_ratio),
        ),
    )

    # scaled_image = pygame.transform.smoothscale(
    #     scaled_image, (item.transform.scale.x, item.transform.scale.y)
    # )

    # Rotate the image
    rotated_image = pygame.transform.rotate(scaled_image, item.transform.rotation.z)

    # Get the rect of the rotated image
    rotated_rect = rotated_image.get_rect()

    # Set the position of the rotated image
    rotated_rect.center = (
        pgapi.SETTINGS.screen_size[0] / 2
        + (pgapi.CAMERA.position.x * -1 + item.transform.position.x)
        * pgapi.CAMERA.pixel_unit_ratio,
        pgapi.SETTINGS.screen_size[1] / 2
        + (pgapi.CAMERA.position.y * -1 + item.transform.position.y)
        * pgapi.CAMERA.pixel_unit_ratio,
    )

    # Blit the rotated image onto the screen
    if item.crop is None:
        pgapi.SCREEN.blit(rotated_image, rotated_rect.topleft)
        return

    pgapi.SCREEN.blit(
        rotated_image,
        rotated_rect.topleft,
        (
            item.crop.start.x * pgapi.CAMERA.pixel_unit_ratio,
            item.crop.start.y * pgapi.CAMERA.pixel_unit_ratio,
            item.crop.end.x * pgapi.CAMERA.pixel_unit_ratio,
            item.crop.end.y * pgapi.CAMERA.pixel_unit_ratio,
        ),
    )


def render_bone(bone: Bone, parent: Item):
    if bone.transform is None or (bone.sprite is None and bone.fill_color is None):
        return

    image: pygame.Surface

    if bone.sprite is not None:
        image = ASSETS[bone.sprite]

    elif bone.fill_color is not None:
        image = pygame.Surface((bone.transform.scale.x, bone.transform.scale.y))
        image.fill(tuple(bone.fill_color))

    else:
        return

    # vec: CompleteMathVector = MathVectorToolkit.normalise(
    #     MathVectorToolkit.new(
    #         start=Vector2(0, 0), magnitude=1, direction=parent.transform.rotation.z
    #     )
    # )

    # Scale the image
    scaled_image = pygame.transform.scale(
        image,
        (
            int(bone.transform.scale.x * pgapi.CAMERA.pixel_unit_ratio),
            int(bone.transform.scale.y * pgapi.CAMERA.pixel_unit_ratio),
        ),
    )

    # Rotate the image
    rotated_image = pygame.transform.rotate(
        scaled_image,
        2 * bone.transform.rotation.z
        + (parent.transform.rotation.z - bone.transform.rotation.z),
    )

    # Get the rect of the rotated image
    # math.cos(theta) * cx - math.sin(theta) * cy + px

    rotated_rect = rotated_image.get_rect(
        center=(
            pgapi.SETTINGS.screen_size[0] / 2
            + (
                pgapi.CAMERA.position.x * -1
                + parent.transform.position.x
                + (
                    (bone.transform.position.x)
                    * math.cos(math.radians(-parent.transform.rotation.z))
                    - math.sin(math.radians(-parent.transform.rotation.z))
                    * (bone.transform.position.y)
                )
                + bone.anchor.x
            )
            * pgapi.CAMERA.pixel_unit_ratio,
            pgapi.SETTINGS.screen_size[1] / 2
            + (
                pgapi.CAMERA.position.y * -1
                + parent.transform.position.y
                + (
                    (bone.transform.position.x)
                    * math.sin(math.radians(-parent.transform.rotation.z))
                    + math.cos(math.radians(-parent.transform.rotation.z))
                    * (bone.transform.position.y)
                )
                + bone.anchor.y
            )
            * pgapi.CAMERA.pixel_unit_ratio,
        )
    )

    # Set the position of the rotated image
    # rotated_rect.topleft = (
    #     parent.transform.position.x + bone.transform.position.x,
    #     parent.transform.position.y + bone.transform.position.y
    # )

    # Blit the rotated image onto the screen
    pgapi.SCREEN.blit(rotated_image, rotated_rect.topleft)


def render_ui(element: Element, parent_style: StyleSheet = StyleSheet()) -> None:
    elstl = element.style

    x = 0
    y = 0
    w = unit(elstl.width) if elstl.width != None else 20
    h = unit(elstl.height) if elstl.height != None else 0

    match elstl.position:
        case POSITION.ABSOLUTE:
            x = (
                unit(elstl.left)
                if unit(elstl.left) != None
                else unit(elstl.right) if unit(elstl.right) != None else 0
            )
            y = (
                unit(elstl.top)
                if unit(elstl.top) != None
                else unit(elstl.bottom) if unit(elstl.bottom) != None else 0
            )

        case POSITION.RELATIVE:
            x = (
                unit(elstl.left) + unit(parent_style.left)
                if unit(elstl.left) != None and unit(parent_style.left) != None
                else (
                    unit(elstl.right) + unit(parent_style.right)
                    if unit(elstl.right) != None and unit(parent_style.right) != None
                    else 0
                )
            )
            y = (
                unit(elstl.top) + unit(parent_style.top)
                if unit(elstl.top) != None and unit(parent_style.top) != None
                else (
                    unit(elstl.bottom) + unit(parent_style.bottom)
                    if unit(elstl.bottom) != None and unit(parent_style.bottom) != None
                    else 0
                )
            )

    bg_color = (
        pygame.Color(*elstl.bg_color) if elstl.bg_color else pygame.Color(0, 0, 0, 0)
    )

    image = pygame.Surface((w, h))
    image.fill(bg_color)

    positioned_rect = image.get_rect(topleft=(x, y))

    pgapi.SCREEN.blit(image, positioned_rect.topleft)

    child_strings_count = 0

    for child in element.children:
        if isinstance(child, str):
            font = ASSETS[f"font-{element.style.font_size}-{element.style.font}"]
            # font.size = unit(element.style.font_size)
            text_surf = font.render(
                child, True, element.style.color, element.style.bg_color
            )

            pgapi.SCREEN.blit(
                text_surf, (x, y + element.style.font_size * child_strings_count)
            )

            child_strings_count += 1
            continue

        render_ui(child, element.style)


def render():
    for item in Items.rendering:
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

        render_item(item=item)

        if item.bones is None:
            continue

        for bone in item.bones.values():
            render_bone(bone=bone, parent=item)

    render_ui(DOM_El)
