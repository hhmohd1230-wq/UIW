# UIW

Roblox dungeon automation script (Volt executor). The source lives in `src/`,
split by area; `dist/UIW.lua` is the joined, ready-to-run file.

Base version: **v44.20** (from `UIW_v44.17.lua`). The split is lossless: building
reproduces that file byte for byte.

## Load it in Volt

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hhmohd1230-wq/UIW/main/loader.lua"))()
```

The loader downloads the built script, saves it to `UIW/UIW.lua` (so Auto
Execute still works after a teleport) and falls back to that saved copy when
GitHub cannot be reached. To pick another build, set one of these before the
line above:

```lua
getgenv().UIW_BUILD = "flat"    -- the flat-arena experiment
getgenv().UIW_BUILD = "stable"  -- the v44.22 build
getgenv().UIW_LOCAL = true      -- run the saved copy, no download
```

Note: the raw file is served from a cache, so a push can take a few minutes
to reach the loader.

## Share it with someone else

The one line above is all anyone needs — no key, no account, nothing to
install. It works for other people only while this repository is **public**
(Settings → General → Danger Zone → Change visibility). Making it private
again breaks the link for everyone, including you; `getgenv().UIW_LOCAL = true`
keeps working from the saved copy.

Every push rebuilds `dist/UIW.lua` from `src/` automatically (GitHub Actions,
`.github/workflows/build.yml`), so whoever runs the loader always gets the
current source.

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

## Configs and Auto Execute

Everything is in the **Configs** tab of the window.

| File (Volt `workspace/UIW/`) | What it holds |
| --- | --- |
| `configs/<name>.json` | One saved setup (switches + sliders) |
| `uiw_meta.json` | Which config loads on start (`AutoLoad`), `AutoExecute`, `ScriptPath` |

* **Save** writes the current setup under the typed name. **Load** applies it.
* **Delete** asks once more ("Sure?"). Deleting the config that is in use or
  set to Auto Load puts everything back to the defaults, including Auto Load
  and Auto Execute.
* **Auto Load** loads the selected config every time the script starts.
* **Auto Execute** queues the script for the next teleport and re-queues
  itself in every new server. After the teleport it runs the file named in
  `ScriptPath` (default `UIW/UIW.lua`, which `build.cmd -Volt` writes). To use
  another file, set `getgenv().UIW_SCRIPT_PATH = "UIW/other.lua"` before
  loading the script once.
* An old `UIW/settings.json` is moved to `configs/default.json` on first start.

## Layout

| Path | What it is |
| --- | --- |
| `manifest.txt` | Build order. Every part is listed here once. |
| `src/00_bootstrap.lua` | Waits for the game/player, removes an old instance, services |
| `src/01_config.lua` | `CONFIG`, default settings |
| `src/02_files_settings.lua` | Safe file access, `ConfigStore` (named configs + meta file) |
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
| `src/ui/hud.lua` | The hub window (tabs, cards, toasts, config page) |
| `src/ui/*` | Hitbox ESP, path ESP, target health bar, tactical display |
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
