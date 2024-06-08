from brass.base import *


# fmt: off
from src.global_routines import (
    projectiles,
    dash,
    crowd_control,
    spells,
    boons,
    interact,
    round_manager
)
from src.enums import keybinds

from brass import (
    vectormath, 
    collision,
    animator,
    timeout,
    assets,
    audio,
    scene,
    items, 
    pgapi,
    enums, 
    inpt, 
    gui
)
# fmt: on


player: Optional[Item] = None
player_hand_holder: Optional[Item] = None
player_plates_attack_anim: Optional[AnimationGroup] = None
player_gloves_attack_anim: Optional[AnimationGroup] = None
player_walk_left_anim: Optional[AnimationGroup] = None
player_walk_right_anim: Optional[AnimationGroup] = None
player_can_move_save = True


class DEFAULT_WEAPONS:
    GLOVES = Weapon(
        id="gloves",
        #
        light_sprite="light_attack_projectile.png",
        light_lifetime=1,
        light_speed=1,
        light_damage_multiplier=1,
        light_size=Vec2(32, 96),
        #
        heavy_sprite="heavy_attack_projectile.png",
        heavy_lifetime=1.5,
        heavy_speed=0.8,
        heavy_damage_multiplier=2,
        heavy_size=Vec2(32, 96),
        #
        dash_sprite="light_attack_projectile.png",
        dash_lifetime=2.25,
        dash_speed=2,
        dash_damage_multiplier=1.25,
        dash_size=Vec2(64, 256),
        #
        spell0_effectiveness=5,
        spell1_effectiveness=5,
    )
    PLATES = Weapon(
        id="plates",
        #
        light_sprite="light_attack_projectile.png",
        light_lifetime=1,
        light_damage_multiplier=1,
        light_speed=0.9,
        light_size=Vec2(64, 64),
        #
        heavy_sprite="heavy_attack_projectile.png",
        heavy_lifetime=1.5,
        heavy_damage_multiplier=2,
        heavy_speed=0.75,
        heavy_size=Vec2(64, 64),
        #
        dash_sprite="light_attack_projectile.png",
        dash_lifetime=2.25,
        dash_damage_multiplier=1.25,
        dash_speed=1.75,
        dash_size=Vec2(256, 64),
        #
        spell0_effectiveness=5,
        spell1_effectiveness=5,
    )


dash_display: Optional[GUIElement] = None
hp_amount_display: Optional[GUIElement] = None
hitpoint_display: Optional[GUIElement] = None
mana_display: Optional[GUIElement] = None
walk_sound: Optional[Audio] = None

default_attack_speed: Number = 0

can_attack: bool = True
can_dash: bool = False

inventory_display_banana: Optional[GUIElement]
inventory_display_strawberry: Optional[GUIElement]
inventory_display_blueberry: Optional[GUIElement]


weapon_display_0: Optional[Bone] = None
weapon_display_1: Optional[Bone] = None
weapons_swap_display: Optional[GUIElement] = None
spell0_icon_display: Optional[GUIElement] = None
spell1_icon_display: Optional[GUIElement] = None


def init() -> None:
    global player
    global player_hand_holder
    global dash_display
    global hitpoint_display
    global mana_display
    global walk_sound
    global player_plates_attack_anim
    global player_gloves_attack_anim
    global hp_amount_display
    global default_attack_speed
    global inventory_display_banana
    global inventory_display_strawberry
    global inventory_display_blueberry
    global weapon_display_0
    global weapon_display_1
    global player_walk_left_anim
    global player_walk_right_anim
    global weapons_swap_display
    global spell0_icon_display
    global spell1_icon_display

    player_query = items.get("player")
    player_hand_holder_query = items.get("player_hand_holder")
    dash_gui_query = gui.get_element("DashBar")
    hitpoint_bar_query = gui.get_element("PlayerHitpointBar")
    mana_bar_query = gui.get_element("ManaBar")
    hp_amount_query = gui.get_element("HpAmountDispaly")
    hp_amount_query = gui.get_element("HpAmountDispaly")
    inv_d_banana_query = gui.get_element("Inventory-Item-banana-Counter")
    inv_d_strawberry_query = gui.get_element("Inventory-Item-strawberry-Counter")
    inv_d_blueberry_query = gui.get_element("Inventory-Item-blueberry-Counter")
    w_d_0 = items.get("player_hand_holder->left_hand")
    w_d_1 = items.get("player_hand_holder->right_hand")
    weapon_swap_q = gui.get_element("WeaponSwapDisplay")
    sp0_i_d = gui.get_element("Spell0Display")
    sp1_i_d = gui.get_element("Spell1Display")

    player_plates_attack_anim_query = animator.store.get("plates_anim")
    player_gloves_attack_anim_query = animator.store.get("gloves_anim")
    player_walk_left_anim_q = animator.store.get("player_walk_anim_left")
    player_walk_right_anim_q = animator.store.get("player_walk_anim_right")

    # Player
    if player_query.is_err():
        unreachable("Player Item does not exist!")

    player = player_query.ok()

    # Player Hand Holder
    if player_hand_holder_query.is_err():
        unreachable("Player Item does not exist!")

    player_hand_holder = player_hand_holder_query.ok()

    # Dash Display GUIElement
    if dash_gui_query.is_err():
        unreachable("Dash display GUIElement does not exist!")

    dash_display = dash_gui_query.ok()

    # Hitpoint Display GUIElement
    if hitpoint_bar_query.is_err():
        unreachable("Hitpoint display GUIElement does not exist!")

    hitpoint_display = hitpoint_bar_query.ok()

    # Mana Bar GUIElement
    if mana_bar_query.is_err():
        unreachable("Mana display GUIElement does not exist!")

    mana_display = mana_bar_query.ok()

    # Weapon Swap GUIElement
    if weapon_swap_q.is_err():
        unreachable("Weapon Swap display GUIElement does not exist!")

    weapons_swap_display = weapon_swap_q.ok()

    # Spell 0 Display element
    if sp0_i_d.is_err():
        unreachable("spell0 icon display GUIElement does not exist!")

    spell0_icon_display = sp0_i_d.ok()

    # Spell 1 Display element
    if sp1_i_d.is_err():
        unreachable("spell0 icon display GUIElement does not exist!")

    spell1_icon_display = sp1_i_d.ok()

    # HP Amount Display GUIElement
    if hp_amount_query.is_err():
        unreachable("Hitpoint display GUIElement does not exist!")

    hp_amount_display = hp_amount_query.ok()

    # Walking audio
    # walk_sound = assets.use("walking.mp3", T=Audio)
    # audio.set_volume(walk_sound, 0.1)

    # Plates
    if player_plates_attack_anim_query.is_err():
        unreachable("plates animation does not exist")

    player_plates_attack_anim = player_plates_attack_anim_query.ok()

    # Gloves
    if player_gloves_attack_anim_query.is_err():
        unreachable("gloves animation does not exist")

    player_gloves_attack_anim = player_gloves_attack_anim_query.ok()

    # Walk left
    if player_walk_left_anim_q.is_err():
        unreachable("walk_left animation does not exist")

    player_walk_left_anim = player_walk_left_anim_q.ok()

    # Walk right
    if player_walk_right_anim_q.is_err():
        unreachable("walk_left animation does not exist")

    player_walk_right_anim = player_walk_right_anim_q.ok()

    # Inventory |> Banana
    if inv_d_banana_query.is_err():
        unreachable("Banana inventory display does not exist!")

    inventory_display_banana = inv_d_banana_query.ok()

    # Inventory |> Strawberry
    if inv_d_strawberry_query.is_err():
        unreachable("Strawberry inventory display does not exist!")

    inventory_display_strawberry = inv_d_strawberry_query.ok()

    # Inventory |> Blueberry
    if inv_d_blueberry_query.is_err():
        unreachable("Blueberry inventory display does not exist!")

    inventory_display_blueberry = inv_d_blueberry_query.ok()

    # Weapon Display 0
    if w_d_0.is_err():
        unreachable("Weapon 0 display does not exist!")

    weapon_display_0 = w_d_0.ok()

    # Weapon Display 1
    if w_d_1.is_err():
        unreachable("Weapon 1 display does not exist!")

    weapon_display_1 = w_d_1.ok()

    player.movement_speed = player.base_movement_speed
    player.attack_speed = player.base_attack_speed

    player.dashes_remaining = player.dash_count
    player.last_dash_charge_refill = pgapi.TIME.current

    if player.hitpoints is None:
        player.hitpoints = player.max_hitpoints
    if player.mana == None:
        player.mana = player.max_mana

    if player.slowed_by_percent == None:
        player.slowed_by_percent = 0

    default_attack_speed = player.base_attack_speed

    if not player.inventory:
        player.inventory = Inventory()

    if not player.weapons:
        player.weapons = [DEFAULT_WEAPONS.PLATES, DEFAULT_WEAPONS.GLOVES]

    if not player.weapon:
        player.weapon = player.weapons[0]

    empty_spell = Spell("Üres", "Üres képesség hely.", 0, 0, 0, "empty_icon.png", [])

    if player.spells == None:
        player.spells = [empty_spell, structured_clone(empty_spell)]
        # player.spells = [enums.spells.HEALING, enums.spells.Zzzz]
    elif len(player.spells) < 2:
        for _ in range(2 - len(player.spells)):
            player.spells.append(empty_spell)

    if not player.dash_time:
        player.dash_time = 150

    if not player.base_damage:
        player.base_damage = 10

    # print("Player:", player.uuid)
    # print("Player Spells:", player.spells)
    # hitpoint_display.style.bg_color = (20, 120, 220, 1)


def update() -> None:
    global player_plates_attack_anim
    global player_gloves_attack_anim
    global hitpoint_display
    global player_can_move_save
    global mana_display
    global hp_amount_display
    global default_attack_speed
    global can_attack
    global can_dash
    global weapons_swap_display
    global spell0_icon_display
    global spell1_icon_display

    weapon_display_0.sprite = f"{player.weapon.id}_0.png"
    weapon_display_1.sprite = f"{player.weapon.id}_1.png"

    if inpt.active_bind(keybinds.SPELLS.SPELL1) and player.spells[0] != None:
        spells.fire(player.spells[0], player)

    if inpt.active_bind(keybinds.SPELLS.SPELL2) and player.spells[1] != None:
        spells.fire(player.spells[1], player)

    if collision.collides(player.transform, round_manager.MIXER_TRANSFORM):
        if round_manager.ROUND_STATE == "BoonSelection":
            interact.show("Mixer", 10000)
            if inpt.active_bind(keybinds.INTERACT):
                boons.show_boon_menu()
    else:
        interact.hide(10000)

    if round_manager.ROUND_STATE == "Wait":
        interact.show("Következő kör", 10000)
        if inpt.active_bind(keybinds.INTERACT):
            round_manager.start_round()
            round_manager.ROUND_STATE = "Fight"
            interact.hide(10000)

    if inpt.active_bind(keybinds.PLAYER_WEAPON_SWITCH):
        if player.weapon.id == player.weapons[0].id:
            player.weapon = player.weapons[1]
            player.base_attack_speed = default_attack_speed
        else:
            player.weapon = player.weapons[0]
            player.base_attack_speed = default_attack_speed * 2

        weapons_swap_display.style.bg_image = f"weapon_switch_{player.weapon.id}.png"

        if player.weapon.id == "gloves":
            animator.play(player_gloves_attack_anim)
        else:
            animator.play(player_plates_attack_anim)

    if (player.rooted or player.stunned or player.sleeping) and player.can_move:
        player.can_move = False
    elif (
        not (player.rooted or player.stunned or player.sleeping)
    ) and not player.can_move:
        player.can_move = True

    move_player()
    pgapi.CAMERA.position = player.transform.position

    # print(items.rendering)

    if not (player.stunned or player.sleeping):
        attack_anim = (
            player_gloves_attack_anim
            if player.weapon.id == "gloves"
            else player_plates_attack_anim
        )

        light_attacking = inpt.active_bind(keybinds.PLAYER_LIGHT_ATTACK)
        heavy_attacking = inpt.active_bind(keybinds.PLAYER_HEAVY_ATTACK)

        if light_attacking and player.dashing and can_attack:
            animator.play(attack_anim)
            projectiles.shoot(
                projectiles.new(
                    sprite=player.weapon.dash_sprite,
                    position=structured_clone(player.transform.position),
                    scale=player.weapon.dash_size,
                    direction=player_hand_holder.transform.rotation.z,
                    lifetime_seconds=player.weapon.dash_lifetime,
                    speed=(
                        player.base_movement_speed
                        * player.weapon.dash_speed
                        * player.dash_movement_multiplier
                    ),
                    team="Player",
                    damage=player.base_damage * player.weapon.dash_damage_multiplier,
                ),
            )

            can_attack = False
            timeout.new((1 / player.attack_speed), allow_attack, ())

        elif light_attacking and can_attack:
            animator.play(attack_anim)
            projectiles.shoot(
                projectiles.new(
                    sprite=player.weapon.light_sprite,
                    position=structured_clone(player.transform.position),
                    scale=player.weapon.light_size,
                    direction=player_hand_holder.transform.rotation.z,
                    lifetime_seconds=player.weapon.light_lifetime,
                    speed=player.base_movement_speed * player.weapon.light_speed,
                    team="Player",
                    damage=player.base_damage * player.weapon.light_damage_multiplier,
                )
            )

            if not player.rooted and not can_dash:
                can_dash = True

            crowd_control.apply(player, "root", 0.1)

            can_attack = False
            timeout.new((1 / player.attack_speed), allow_attack, ())

        elif heavy_attacking and can_attack and not player.dashing:
            animator.play(attack_anim)
            projectiles.shoot(
                projectiles.new(
                    sprite=player.weapon.heavy_sprite,
                    position=structured_clone(player.transform.position),
                    scale=player.weapon.heavy_size,
                    direction=player_hand_holder.transform.rotation.z,
                    lifetime_seconds=2,
                    speed=player.base_movement_speed * player.weapon.heavy_speed,
                    team="Player",
                    damage=player.base_damage * player.weapon.heavy_damage_multiplier,
                    effects=[Effect("stun", 1)],
                )
            )

            crowd_control.apply(player, "root", 0.25)

            can_attack = False
            timeout.new((1 / player.attack_speed) * 2, allow_attack, ())

    if player.hitpoints <= 0:
        player.hitpoints = 0
        scene.pause()
        timeout.new(1, scene.load, (enums.scenes.DEFEAT,))

    if player.mana < 0:
        player.mana = 0

    if player.hitpoints > player.max_hitpoints:
        player.hitpoints = player.max_hitpoints

    if player.mana > player.max_mana:
        player.mana = player.max_mana

    hitpoint_display.style.width = f"{player.hitpoints / player.max_hitpoints * 100}%"
    mana_display.style.width = f"{player.mana / player.max_mana * 100}%"

    hp_amount_text = f"{int(player.hitpoints)}/{int(player.max_hitpoints)}"
    hp_amount_display.style.left = (
        f"{300 - len(hp_amount_text) * hp_amount_display.style.font_size / 2}x"
    )
    hp_amount_display.children[0] = hp_amount_text

    inventory_display_banana.children[0] = str(player.inventory.banana)
    inventory_display_strawberry.children[0] = str(player.inventory.strawberry)
    inventory_display_blueberry.children[0] = str(player.inventory.blueberry)

    spell0_icon_display.style.bg_image = player.spells[0].icon
    spell1_icon_display.style.bg_image = player.spells[1].icon

    spell0_cond = True
    spell1_cond = True


    if player.spells[0].cooldown_start != None:
        spell0_cond = False
        t = f"{round(player.spells[0].cooldown_start + player.spells[0].cooldown - pgapi.TIME.current)}s"
        spell0_icon_display.children[0].children[0] = t
        spell0_icon_display.children[0].style.left = f"{32 - len(t) * 12 / 2}x"

    if player.spells[1].cooldown_start != None:
        spell1_cond = False
        t = f"{round(player.spells[1].cooldown_start + player.spells[1].cooldown - pgapi.TIME.current)}s"
        spell1_icon_display.children[0].children[0] = t
        spell1_icon_display.children[0].style.left = f"{32 - len(t) * 12 / 2}x"

    if pgapi.SETTINGS.input_mode == "Controller":
        if weapons_swap_display.children[0].children[0] != "RB":
            weapons_swap_display.children[0].style.left = f"{32 - 12}x"
            weapons_swap_display.children[0].children[0] = "RB"

        if (
            spell0_icon_display.children[0].children[0] != "X"
            and spell0_cond
        ):
            spell0_icon_display.children[0].children[0] = "X"
            spell0_icon_display.children[0].style.left = f"{32 - 6}x"

        if (
            spell1_icon_display.children[0].children[0] != "Y"
            and spell1_cond
        ):
            spell1_icon_display.children[0].children[0] = "Y"
            spell1_icon_display.children[0].style.left = f"{32 - 6}x"
    else:
        if weapons_swap_display.children[0].children[0] != "Tab":
            weapons_swap_display.children[0].style.left = f"{32 - 1.5 * 12}x"
            weapons_swap_display.children[0].children[0] = "Tab"

        if (
            spell0_icon_display.children[0].children[0] != "Q"
            and spell0_cond
        ):
            spell0_icon_display.children[0].children[0] = "Q"
            spell0_icon_display.children[0].style.left = f"{32 - 6}x"

        if (
            spell1_icon_display.children[0].children[0] != "E"
            and spell1_cond
        ):
            spell1_icon_display.children[0].children[0] = "E"
            spell1_icon_display.children[0].style.left = f"{32 - 6}x"


def allow_attack() -> None:
    global can_attack
    can_attack = True


def move_player() -> None:
    global can_dash
    global player_walk_left_anim
    global player_walk_right_anim

    # global dash_display
    # global player_hand_holder

    # if not player.can_move:
    #     return

    # print(player.dashes_remaining)

    dash_display.style.width = (
        f"{round(player.dashes_remaining / player.dash_count, 2) * 100}%"
    )

    # .children[0] = (
    #     " ".join(["[×]" for _ in range(player.dashes_remaining)])
    #     + (" " if player.dashes_remaining != 0 else "")
    #     + " ".join(["[ ]" for _ in range(player.dash_count - player.dashes_remaining)])
    # )

    if player.dashes_remaining < player.dash_count and player.can_move:
        if (
            player.dash_charge_refill_time + player.last_dash_charge_refill
            <= pgapi.TIME.current
        ):
            player.dashes_remaining = player.dash_count
            player.last_dash_charge_refill = pgapi.TIME.current

    move_math_vec = vectormath.normalise(
        vectormath.new(Vec2(inpt.horizontal(), inpt.vertical()))
    )

    # if move_math_vec.end.x != 0 or move_math_vec.end.y != 0:
    #     audio.fade_in(walk_sound, 100, 1)
    # else:
    #     audio.fade_out(walk_sound, 100)

    if (
        inpt.active_bind(keybinds.PLAYER_DASH)
        and player.dashes_remaining > 0
        and (move_math_vec.end.x != 0 or move_math_vec.end.y != 0)
        and (player.can_move or can_dash)
    ):
        # if player.dashes_remaining == player.dash_count:
        player.last_dash_charge_refill = pgapi.TIME.current
        player.dashes_remaining -= 1
        dash.apply_dash_effect(
            player, move_math_vec, player.dash_movement_multiplier, player.dash_time
        )
        player.invulnerable = True
        if can_dash:
            can_dash = False

    if player.can_move:
        y = (
            player.movement_speed
            * (1 - (player.slowed_by_percent / 100))
            * pgapi.TIME.deltatime
            * move_math_vec.end.y
        )
        x = (
            player.movement_speed
            * (1 - (player.slowed_by_percent / 100))
            * pgapi.TIME.deltatime
            * move_math_vec.end.x
        )
        player.transform.position.y += y
        player.transform.position.x += x
        if x < 0:
            animator.stop(player_walk_right_anim)
            animator.play(player_walk_left_anim)
        elif x > 0 or y != 0:
            animator.stop(player_walk_left_anim)
            animator.play(player_walk_right_anim)

    player_hand_holder.transform.position = player.transform.position
    match pgapi.SETTINGS.input_mode:
        case enums.input_modes.CONTROLLER:
            if len(pgapi.CONTROLLERS) == 0:
                return

            move_vec = vectormath.normalise(
                vectormath.new(
                    end=Vec2(
                        inpt.get_button("right-x@ctrl#0"),
                        inpt.get_button("right-y@ctrl#0"),
                    )
                )
            )

            if move_vec.end.x != 0 or move_vec.end.y != 0:
                player_hand_holder.transform.rotation.z = -move_vec.direction + 90

        case enums.input_modes.MOUSE_AND_KEYBOARD:
            center = Vec2(pgapi.SCREEN.size.x / 2, pgapi.SCREEN.size.y / 2)
            mouse_relative_pos = Vec2(
                pgapi.MOUSE_POSITION.x - center.x, pgapi.MOUSE_POSITION.y - center.y
            )

            rotation = math.degrees(
                math.atan2(mouse_relative_pos.x, mouse_relative_pos.y)
            )
            player_hand_holder.transform.rotation.z = rotation
