# UIW

Roblox dungeon automation script (Volt executor). The source lives in `src/`,
split by area; `dist/UIW.lua` is the joined, ready-to-run file.

Base version: **v44.20** (from `UIW_v44.17.lua`). The split is lossless: building
reproduces that file byte for byte.

## Build

Double-click `build.cmd`, or from a terminal in this folder:

```
build.cmd            # join src/ into dist/UIW.lua
build.cmd -Volt      # ...and copy it to Volt\workspace\UIW\UIW.lua
build.cmd -AutoExec  # ...and also over the auto-execute file UIW_Aura_Mage_v13.lua
```

`python build.py` does the same join (no copying).

Load it in Volt:

```lua
loadstring(readfile("UIW/UIW.lua"))()
```

## Layout

| Path | What it is |
| --- | --- |
| `manifest.txt` | Build order. Every part is listed here once. |
| `src/00_bootstrap.lua` | Waits for the game/player, removes an old instance, services |
| `src/01_config.lua` | `CONFIG`, default settings |
| `src/02_files_settings.lua` | Safe file access, settings file |
| `src/03_names_and_helpers.lua` | Enemy/boss/hazard name tables, filters, math helpers, `Maid` |
| `src/core/character.lua` | `CharacterService` (movement, facing) |
| `src/core/self_abilities.lua` | `SelfAbilityTracker` (our own spells) |
| `src/core/hazards.lua` | `HazardTracker` (precast / hitBox tracking, damage learning) |
| `src/core/geometry.lua` | `GeometrySensor` (walls, floor, raycasts) |
| `src/core/dungeon.lua` | `DungeonModel` (rooms, enemies) |
| `src/core/route_planner.lua` | `RoutePlanner` (pathfinding) |
| `src/core/dodge_solver.lua` | `DodgeSolver` |
| `src/core/combat.lua` | `CombatController` (Q/E casting) |
| `src/core/controller.lua` | `UIWController` (targets, main loop) |
| `src/ui/*` | Hitbox ESP, path ESP, target health bar, tactical display, HUD |
| `src/patches/*` | Version layers that extend the classes above (v42 ... v44.20) |
| `src/dungeons/<name>/*` | Dungeon-specific logic (Aquatic Temple, Enchanted Forest, Crystal Golem) |
| `src/99_start.lua` | Creates and starts the controller |
| `src/99_telemetry.lua` | Hit/dodge telemetry (`getgenv().UIW_Telemetry`) |

## Rules

* All parts share one Lua scope (they use each other's `local`s), so a part
  only runs inside the joined file. Order in `manifest.txt` matters: a part can
  only use what earlier parts defined.
* Lua allows at most 200 `local`s in the top-level scope. New code should go
  inside `do ... end` blocks (like the patch files) or into existing tables.
* New dungeon logic goes in `src/dungeons/<dungeon>/` and is added to
  `manifest.txt`.
