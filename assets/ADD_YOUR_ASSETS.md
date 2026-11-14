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
Replaces the generated placeholder sounds:
`hit`, `bounce`, `jump`, `swing`, `ko`, `special`, `timestop`, `slow`, `float`, `tick`

These are silent until you add a file for them:
`menu_move`, `menu_select`, `menu_back`, `ready`, `go`, `win`

## music/
| file | when it plays |
|---|---|
| `menu.ogg` | title, menus, character select |
| `match.ogg` | during a match |

There's no music unless you add some. It loops automatically, and its volume is in Options.

## fonts/
| file | what it is |
|---|---|
| `main.ttf` (or `.otf`) | Replaces the font everywhere. |
