# Adding your own assets

Everything in the game is a plain placeholder until you drop a file in here.
Put a file in the right folder with the right name, reopen the project in Godot so it imports, and it gets used. You don't need to change any code.
If a file is missing, the placeholder stays.

Any image type works (`png`, `jpg`, `webp`, `svg`). Models can be `glb`, `gltf`, `fbx` or `tscn`. Sounds can be `wav`, `ogg` or `mp3`.

## characters/
| file | what it is |
|---|---|
| `tempo.glb`, `hopper.glb`, `orbit.glb`, `syrup.glb` | 3D model for each fighter. It gets sized to the right height and faces the right way automatically. Animations called idle / run / walk / jump / attack / hurt are picked up by name. |
| `tempo_portrait.png` etc. | Square portrait for the top HUD (around 256x256). |

If a model faces backwards, change `PI / 2.0` to `-PI / 2.0` in `_load_model()` in `scripts/fighter.gd`.

## stage/
| file | what it is |
|---|---|
| `stage.glb` (or `stage.tscn`) | Your whole stage. It replaces the grey boxes. The floor top is at y = 0. The play area is x -12 to 12 and y 0 to 11.5, on the z = 0 plane, with the camera looking down -z. The walls you can't pass through are always at those numbers, so build the art around them. |
| `background.png` | A flat picture drawn far behind everything. |

## ball/
| file | what it is |
|---|---|
| `ball.glb` | Ball model. It gets scaled to the right size. The coloured ring and speed streak still show on top. |

## ui/
| file | what it is |
|---|---|
| `logo.png` | Title screen logo (transparent png, roughly square). |
| `title_bg.png` | Title screen background (1280x720 or bigger). |
| `menu_bg.png` | Main menu / options background. |
| `select_bg.png` | Character select background. |
| `boombox.png` | Art for the bottom speed display. It covers the drawn placeholder, and the numbers, timer and bars are still drawn on top. It's 348x72 in the game's 640x360 grid, so 1392x288 is a good size. |
| `profile.png` | Picture on the little player card in the main menu. |

## sfx/
Drop a `.wav`, `.ogg` or `.mp3` in here. The file name (without the extension) is the sound's name.
You don't have to change any code.

**Game sounds.** Using the same name replaces the built-in placeholder:
`hit`, `bounce`, `jump`, `swing`, `ko`, `special`, `timestop`, `slow`, `float`, `tick`

**Charging** (these play a placeholder until you add a file):
`charge_tick` (rising ticks while you hold swing), `charge_full` (the moment it's fully charged), `charged_hit` (a big charged hit connecting)

**Menu sounds.** Each one plays a placeholder until you add a file for it:

| file name | plays when |
|---|---|
| `menu_start` | you press a button on the title screen |
| `menu_move` | you move up or down the menu |
| `menu_hover` | the mouse moves onto a button |
| `menu_select` | you pick any button |
| `menu_back` | you go back |
| `menu_change` | you change a setting in Options |
| `select_change` | the cursor moves to another portrait |
| `select_ready` | a player picks their character (the bio pops up) |
| `select_unready` | a player backs out of their pick |
| `select_all_ready` | both sides have picked and the START GAME banner comes in |
| `select_go` | you hit START GAME |
| `final_ko` | the last life is lost. Everything freezes on GAME! while it plays, then the results screen comes up (already set to the Smash Ultimate final KO sound) |
| `results` | the results screen appears |
| `menu_select_rematch` / `_change_fighters` / `_main_menu` | the buttons on the results screen |
| `match_start` | Enter is pressed on the controls screen before a match |
| `pause_open` / `pause_close` | Esc opens / closes the pause menu in a match |

**A different sound for each button.** Add `_` and the button's name to the menu sound.
These are tried first, and if one isn't there the general sound plays instead:

| file name | plays when you pick |
|---|---|
| `menu_select_versus` | versus |
| `menu_select_single` | single |
| `menu_select_how_to_play` | how to play |
| `menu_select_options` | options |
| `menu_select_credits` | credits |
| `menu_select_quit` | quit |
| `menu_select_back` | back (in Options) |
| `menu_select_lives` / `_timer` / `_cpu` / `_sfx` / `_music` / `_fullscreen` | that option |
| `menu_back_options` / `menu_back_credits` / `menu_back_howto` / `menu_back_main` / `menu_back_select` | going back from that screen |
| `select_ready_nerdo` / `_mouse` / `_private` / `_macdonald` | readying up as that character (a voice line, say) |
| `select_change_nerdo` / `_mouse` / `_private` / `_macdonald` / `_random` | the cursor landing on that portrait |

Spaces in button names become `_`. Everything is lowercase.

## music/
| file | when it plays |
|---|---|
| `menu.ogg` | title, menus, character select |
| `match.ogg` | during a match |
| `music.ogg` | while the game is paused (Esc). If it's missing, `menu.ogg` plays instead. The match song carries on from where it was when you resume. |

There's no music unless you add some. It loops automatically, and its volume is in Options.

## fonts/
| file | what it is |
|---|---|
| `main.ttf` (or `.otf`) | Replaces the font everywhere. |
