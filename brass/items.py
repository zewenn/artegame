from .base import *

# class Items:
# selector_map: dict[str, Optional[Item | Bone]] = {}
rendering: list[Item] = []


def reset() -> None:
    global rendering
    del rendering[::]
    rendering = []


def remove(item: Item) -> Item:
    # global rendering
    if item in rendering:
        rendering.remove(item)
    return item


ADD_RET_TYPE = TypeVar("ADD_RET_TYPE", Item, List[Item])


def add(item: ADD_RET_TYPE) -> ADD_RET_TYPE:
    """
    ## Create new item(s)

    Args:
        item (Item | list[Item]): _description_

    Returns:
        Item: _description_
    """

    if isinstance(item, list):
        for it in item:
            it.uuid = "item:" + uuid()
            rendering.append(it)
        return item

    item.uuid = "item:" + uuid()
    rendering.append(item)
    return item


# def add_to_selector_map(selector: str, item: Optional[Item]) -> None:
#     global selector_map

#     if item is not None:
#         selector_map[selector] = item


def __inner_get__(
    name: Optional[string] = None, tags: Optional[list[string]] = None
) -> Optional[Item]:
    """Query an item by its id or tags

    Args:
        id (strorNone, optional): Defaults to None.
        tags (list[str], optional): Defaults to [].

    Returns:
        Item or None: REFERENCE
    """

    if name is None and tags is None:
        return None

    if tags is None:
        tags = []

    tag_set: set = set(tags)

    for item in rendering:
        if item.tags is None:
            item.tags = []

        if item.id == name or (
            all(item in item.tags for item in tag_set) and len(tags) != 0
        ):
            return item

    return None


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

    item: Optional[Item] = __inner_get__(name=item_id, tags=item_tags)

    if item is None:
        return Err(Mishap(f"Couldn't find item: {selector}"))

    if hasattr(item, "bones") and bone_id is not None:
        res = item.bones.get(bone_id)

        if res is None:
            return Err(Mishap(f"Couldn't find item: {selector}"))

        return Ok(res)

    return Ok(item)


def get_all(tag: string) -> list[Item]:
    return [x for x in rendering if tag in x.tags]
