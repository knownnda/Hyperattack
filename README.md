# Hyper Attack

2.5D ball brawler made in Godot 4.3+. 1 player vs CPU or 2 players on one keyboard, 5 lives each, 5 minute timer.

Hit the ball with your bat and it becomes your colour and goes faster. If someone else's ball touches you, you lose a life. Hold up or down while you swing to aim the hit. Last one standing wins.

## Characters
| | model | ability | meter |
|---|---|---|---|
| NERDO | Nerdo by Drawnah (CC BY 4.0) | Time Stop | 100 |
| MOUSE | Macdonald Mouse by Kasugay | Double Jump | 35 |
| PRIVATE | Private by gaddiellartey2010 (CC BY 4.0) | Zero-G | 75 |
| MACDONALD | MacDonald by Kasugay | Slow Ball | 60 |

Credits are in `CREDITS.txt` and on the in-game credits screen. Keep them when you upload to itch.io: the CC BY models require it.

## Modes
- **1 Player vs CPU** (easy / normal / hard)
- **2 Players** on one keyboard

## Controls
| | P1 | P2 |
|---|---|---|
| move | A / D | left / right |
| jump (hold to aim up) | W | up |
| fall fast / aim down | S | down |
| swing | F | K |
| bunt | G | L |
| special | H | ; |

**Bunt** pops the ball up softly and makes it neutral, but it keeps its speed, so the next proper swing carries on from there.
Gamepads work too: A jump, X swing, B bunt, Y special. Esc goes back to the menu.
On the select screen, press swing to ready up.

## Putting it on itch.io
1. Open the folder in Godot 4.3 or newer.
2. Editor > Manage Export Templates > Download.
3. Project > Export > **Web** (already set up). Export to `build/web/index.html`.
4. Zip everything **inside** `build/web` and upload it to itch as an HTML game. Tick "This file will be played in the browser" and set the viewport to 1280 x 720.

Thread support is turned off in the export preset, so you don't need the SharedArrayBuffer option on itch.

## Tweaking
- Ball speed and acceleration are in `scripts/ball.gd` (`BASE_SPEED`, `MAX_SPEED`, and the `struck()` function).
- Movement and swing timings are at the top of `scripts/fighter.gd`.
- Ability costs and text are in `scripts/game.gd`. Ability effects are in `try_special()` in `scripts/match.gd`.
- Lives are `stocks` in `game.gd`.

## Menus
Title screen, then the main menu (versus / single / how to play / options / credits), then character select, then the match. Esc or G goes back.

## Your own art and sound
Drop files into `assets/` to replace any placeholder. `assets/ADD_YOUR_ASSETS.md` lists every slot.
