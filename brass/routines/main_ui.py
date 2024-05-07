from ui import *


DOM(
    Element(
        "asd",
        "asd",
        "asd",
        "asd",
        "asd",
        Element(
            style=StyleSheet(
                position=POSITION.RELATIVE,
                top="50x",
                left="-30x",
                width="50x",
                height="60x",
                bg_color=(255, 0, 0, 1)
            )
        ),
        style=StyleSheet(
            position=POSITION.ABSOLUTE,
            top="50h",
            left="50w",
            width="150x",
            height="50x",
            bg_color=(20, 120, 240, 1),
            font_size=FONT_SIZE.EXTRA_LARGE
        )
    )
)

print(DOM_El)