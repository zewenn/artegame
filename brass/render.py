import pgapi
from img import surface_ref_table
from entities import *
import pygame
import math


def render_item(item: Item):
    if item.transform is None or (
        item.sprite is None and item.fill_color is None
    ):
        return

    image: pygame.Surface

    if item.sprite is not None:
        image = surface_ref_table[item.sprite]
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
        image = surface_ref_table[bone.sprite]

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


def render():
    for item in Items.rendering:
        # render_thread = threading.Thread(
        #     target=render_one,
        #     args=(item,)
        # )
        # render_thread.setDaemon(True)

        # render_thread.start()

        render_item(item=item)

        if item.bones is not None:
            for bone in item.bones.values():
                render_bone(bone=bone, parent=item)
