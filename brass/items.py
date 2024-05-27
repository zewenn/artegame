from base import *

# class Items:
# selector_map: dict[str, Optional[Item | Bone]] = {}
rendering: list[Item] = []


def reset() -> None:
    global rendering
    del rendering[::]
    rendering = []

def remove(x: Item) -> None:
    global rendering
    if x in rendering:
        rendering.remove(x)
        del x

def add_to_scene(item: Item) -> Item:
    rendering.append(item)
    return item


# def add_to_selector_map(selector: str, item: Optional[Item]) -> None:
#     global selector_map

#     if item is not None:
#         selector_map[selector] = item


def __inner_get__(
    id: Optional[str] = None, tags: Optional[list[str]] = None
) -> Optional[Item]:
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

    for item in rendering:
        if item.tags is None:
            item.tags = []

        if item.id == id or (
            all([item in item.tags for item in tag_set]) and len(tags) != 0
        ):
            return item


def get(selector: str) -> Result[Item | Bone, Mishap]:
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

    # if selector_map.get(selector):
    #     return Ok(selector_map.get(selector))

    item_and_bone: list[str] = selector.split("->")
    enity_selector_list: list[str] = item_and_bone[0].split("|")

    item_id: Optional[str] = ""
    item_tags: list[str] = []
    bone_id: Optional[str] = None

    if len(item_and_bone) > 2:
        return Err(Mishap(f"Wrong selector: {selector} | includes more than one '->'"))

    if len(item_and_bone) == 2:
        bone_id = item_and_bone[1]

    if len(enity_selector_list) == 1:
        item_id = enity_selector_list[0]
    else:
        item_tags = enity_selector_list

    item: Optional[Item] = __inner_get__(id=item_id, tags=item_tags)

    if bone_id is None:
        # add_to_selector_map(selector, item)
        if item: 
            return Ok(item)
        return Err(Mishap(f"Couldn't find item: {selector}"))

    if hasattr(item, "bones"):
        # add_to_selector_map(selector, item.bones.get(bone_id))
        res = item.bones.get(bone_id)

        if res == None:
            return Err(Mishap(f"Couldn't find item: {selector}"))
        
        return Ok(res)


    

