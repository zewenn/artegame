from classes import *
from dataclasses import dataclass
import copy
import time

class Entities:
    selector_map: dict[str, Entity | Bone | None] = {}
    entities: list[Entity] = []

    @classmethod
    def create(this, _entity: Entity):
        this.entities.append(_entity)

    @classmethod    
    def add_to_selector_map(this, selector: str, entity: Entity | None):
        if entity is not None:
            this.selector_map[selector] = entity
    
    @classmethod
    def __inner_get__(this, id: str | None = None, tags: list[str] = None) -> Entity | None:
        """Query an entity by its id or tags

        Args:
            id (strorNone, optional): Defaults to None.
            tags (list[str], optional): Defaults to [].

        Returns:
            Entity or None: REFERENCE
        """

        if id is None and tags is None:
            return None
        
        if tags is None:
            tags = []

        tag_set: set = set(tags)

        for entity in this.entities:
            if entity.tags is None:
                entity.tags = []

            if entity.id == id or all(item in entity.tags for item in tag_set):
                return entity
    
    @classmethod
    def get(this, selector: str) -> Entity | Bone | None:
        """Selector based entity query\n
        `"player" - Entity` \n
        `"player|entity" - Entity` \n
        `"player->leg_left" - Bone` \n
        `"player|entity->leg_left" - Bone` \n

        Args:
            selector (str): the very cool selector query

        Raises:
            ValueError: includes more than one '->'

        Returns:
            Entity or Bone or None: REFERENCE
        """

        if this.selector_map.get(selector):
            return this.selector_map.get(selector)

        entity_and_bone: list[str] = selector.split("->")
        enity_selector_list: list[str] = entity_and_bone[0].split("|")

        entity_id: str | None = ""
        entity_tags: list[str] | None = []
        bone_id: str | None = None

        if len(entity_and_bone) > 2:
            raise ValueError(
                f"Wrong selector: {selector} | includes more than one '->'"
            )

        if len(entity_and_bone) == 2:
            bone_id = entity_and_bone[1]
        
        if len(enity_selector_list) == 1:
            entity_id = enity_selector_list[0]
        else:
            entity_tags = enity_selector_list
        
        entity: Entity | None = this.__inner_get__(id=entity_id, tags=entity_tags)

        if bone_id is None:
            this.add_to_selector_map(selector, entity)
            return entity

        if hasattr(entity, "bones"):
            this.add_to_selector_map(selector, entity.bones.get(bone_id))
            return entity.bones.get(bone_id)
        
        

class Transformer:
    def set_position(entity: Entity, pos: Vector2):
        entity.transform.position = pos 
    
    def set_rotation(entity: Entity, rot: Vector3):
        if (rot.z > 180):
            rot.z -= 180 + 180 * (rot.z % 180)
        entity.transform.rotation = rot

    def set_scale(entity: Entity, scale: Vector2):
        entity.transform.scale = scale

