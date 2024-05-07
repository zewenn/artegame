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
            bg_color=(245, 255, 255, 1),
            font_size=FONT_SIZE.LARGE,
            color=(255, 0, 0, 1)
        )
    )
)

print(DOM_El)