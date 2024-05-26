from base import *

STORE: dict[string, AnimationGroup] = {}

def add(id: string, anim: AnimationGroup) -> None:
    global STORE

    STORE[id] = anim

def get(id: string) -> Result[AnimationGroup, Mishap]:
    global STORE

    query_res: Optional[AnimationGroup] = STORE.get(id)

    if query_res:
        return Ok(query_res)
    
    Err(Mishap("Animation does not exist!"))