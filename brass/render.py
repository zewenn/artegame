import pgapi
from img import surface_ref_table
from entities import *
import pygame


def render_entity(entity: Entity):
    if entity.transform is None or (
        entity.sprite is None and entity.fill_color is None
    ):
        return

    image: pygame.Surface

    if entity.sprite is not None:
        image = surface_ref_table[entity.sprite]
    elif entity.fill_color is not None:
        image = pygame.Surface((entity.transform.scale.x, entity.transform.scale.y))
        image.fill(tuple(entity.fill_color))
    else:
        return

    # Scale the image
    scaled_image = pygame.transform.smoothscale(
        image,
        (
            int(entity.transform.scale.x * pgapi.CAMERA.pixel_unit_ratio),
            int(entity.transform.scale.y * pgapi.CAMERA.pixel_unit_ratio),
        ),
    )

    # scaled_image = pygame.transform.smoothscale(
    #     scaled_image, (entity.transform.scale.x, entity.transform.scale.y)
    # )

    # Rotate the image
    rotated_image = pygame.transform.rotate(scaled_image, entity.transform.rotation.z)

    # Get the rect of the rotated image
    rotated_rect = rotated_image.get_rect()

    # Set the position of the rotated image
    rotated_rect.topleft = (
        pgapi.SETTINGS.screen_size[0] / 2
        + (pgapi.CAMERA.position.x * -1 + entity.transform.position.x)
        * pgapi.CAMERA.pixel_unit_ratio,
        pgapi.SETTINGS.screen_size[1] / 2
        + (pgapi.CAMERA.position.y * -1 + entity.transform.position.y)
        * pgapi.CAMERA.pixel_unit_ratio,
    )

    # Blit the rotated image onto the screen
    if entity.crop is None:
        pgapi.SCREEN.blit(rotated_image, rotated_rect.topleft)
        return

    pgapi.SCREEN.blit(
        rotated_image,
        rotated_rect.topleft,
        (
            entity.crop.start.x * pgapi.CAMERA.pixel_unit_ratio,
            entity.crop.start.y * pgapi.CAMERA.pixel_unit_ratio,
            entity.crop.end.x * pgapi.CAMERA.pixel_unit_ratio,
            entity.crop.end.y * pgapi.CAMERA.pixel_unit_ratio,
        ),
    )


def render_bone(bone: Bone, parent: Entity):
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

    # Scale the image
    scaled_image = pygame.transform.scale(
        image,
        (
            int(bone.transform.scale.x * pgapi.CAMERA.pixel_unit_ratio),
            int(bone.transform.scale.y * pgapi.CAMERA.pixel_unit_ratio),
        ),
    )

    # Rotate the image
    rotated_image = pygame.transform.rotate(scaled_image, bone.transform.rotation.z)

    # Get the rect of the rotated image
    rotated_rect = rotated_image.get_rect(
        center=(
            pgapi.SETTINGS.screen_size[0] / 2
            + (
                pgapi.CAMERA.position.x * -1
                + parent.transform.position.x
                + bone.transform.position.x
                + bone.anchor.x
            )
            * pgapi.CAMERA.pixel_unit_ratio,
            pgapi.SETTINGS.screen_size[1] / 2
            + (
                pgapi.CAMERA.position.y * -1
                + parent.transform.position.y
                + bone.transform.position.y
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
    for entity in Entities.entities:
        # render_thread = threading.Thread(
        #     target=render_one,
        #     args=(entity,)
        # )
        # render_thread.setDaemon(True)

        # render_thread.start()

        render_entity(entity=entity)

        if entity.bones is not None:
            for bone in entity.bones.values():
                render_bone(bone=bone, parent=entity)
