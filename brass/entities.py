from classes import *
from dataclasses import dataclass
import copy
import time

class Items:
    selector_map: dict[str, Item | Bone | None] = {}
    in_scene: list[Item] = []

    @classmethod
    def create(this, item: Item):
        this.in_scene.append(item)

    @classmethod    
    def add_to_selector_map(this, selector: str, item: Item | None):
        if item is not None:
            this.selector_map[selector] = item
    
    @classmethod
    def __inner_get__(this, id: str | None = None, tags: list[str] = None) -> Item | None:
        """Query an item by its id or tags

        Args:
            id (strorNone, optional): Defaults to None.
            tags (list[str], optional): Defaults to [].

        Returns:
            Item or None: REFERENCE
        """

        if id is None and tags is None:
            return None
        
        if tags is None:
            tags = []

        tag_set: set = set(tags)

        for item in this.in_scene:
            if item.tags is None:
                item.tags = []

            if item.id == id or (all([item in item.tags for item in tag_set]) and len(tags) != 0):
                return item
    
    @classmethod
    def get(this, selector: str) -> Item | Bone | None:
        """Selector based item query\n
        `"player" - Item` \n
        `"player|item" - Item` \n
        `"player->leg_left" - Bone` \n
        `"player|item->leg_left" - Bone` \n

        Args:
            selector (str): the very cool selector query

        Raises:
            ValueError: includes more than one '->'

        Returns:
            Item or Bone or None: REFERENCE
        """

        if this.selector_map.get(selector):
            return this.selector_map.get(selector)

        item_and_bone: list[str] = selector.split("->")
        enity_selector_list: list[str] = item_and_bone[0].split("|")

        item_id: str | None = ""
        item_tags: list[str] | None = []
        bone_id: str | None = None

        if len(item_and_bone) > 2:
            raise ValueError(
                f"Wrong selector: {selector} | includes more than one '->'"
            )

        if len(item_and_bone) == 2:
            bone_id = item_and_bone[1]
        
        if len(enity_selector_list) == 1:
            item_id = enity_selector_list[0]
        else:
            item_tags = enity_selector_list
        
        item: Item | None = this.__inner_get__(id=item_id, tags=item_tags)

        if bone_id is None:
            this.add_to_selector_map(selector, item)
            return item

        if hasattr(item, "bones"):
            this.add_to_selector_map(selector, item.bones.get(bone_id))
            return item.bones.get(bone_id)
        
        

class Transformer:
    def set_position(item: Item, pos: Vector2):
        item.transform.position = pos 
    
    def set_rotation(item: Item, rot: Vector3):
        item.transform.rotation = rot

    def set_scale(item: Item, scale: Vector2):
        item.transform.scale = scale

