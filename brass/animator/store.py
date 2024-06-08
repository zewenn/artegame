from ..base import *

STORE: dict[string, AnimationGroup] = {}

def add(name: string, anim: AnimationGroup) -> None:
    STORE[name] = anim

def get(name: string) -> Result[AnimationGroup, Mishap]:
    query_res: Optional[AnimationGroup] = STORE.get(name)

    if query_res:
        return Ok(query_res)
    
    return Err(Mishap("Animation does not exist!"))
