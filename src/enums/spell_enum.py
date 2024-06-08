from brass.base import *

HEALING = Spell(
    "Vitamin-mix",
    "Másodpercenként visszatölti at életerőd egy részét.",
    20,
    5,
    75,
    "heal_icon.png",
    ["damage"],
)

HASTE = Spell(
    "Pre workout",
    "Gyorsabb mozgás és nagyobb támadási sebesség.",
    10,
    3,
    15,
    "haste_icon.png",
    [],
)

GOLIATH = Spell(
    "Kreatin",
    "Nagyobb méret és több életerő.",
    15,
    1.25,
    35,
    "goliath_icon.png",
    [],
)

Zzzz = Spell(
    "Ashwaganda",
    "Ellenfelek elaltatása.",
    15,
    1,
    45,
    "sleep_icon.png",
    [],
)