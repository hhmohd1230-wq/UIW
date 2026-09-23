# UIW

Roblox dungeon automation script (Volt executor). The source lives in `src/`,
split by area; `dist/UIW.lua` is the joined, ready-to-run file.

With Auto Combat enabled, UIW also swings the equipped weapon at its attack
speed during a started dungeon, pausing while casting or in a peaceful area.

The Settings tab has an FPS limiter (15-120 FPS) and Black Screen mode. Black
Screen hides 3D rendering and caps the client at 15 FPS; press F8 or the on-screen
button to return. Both choices can be saved in a named config. Black Screen also
remembers its on/off state for the same account and queues UIW to run again
after a teleport when enabled.

Map scenery clearing runs only in Northern Lands. Other dungeons keep their
original map parts and collisions, including during boss fights.

The **Carry** tab coordinates a host and any listed alt usernames. Enable it on
each account, enter the same host and alt list, and leave **Fixed Dungeon** off
for automatic progression. The host waits until every listed alt has loaded in
the lobby, creates a private party at the highest difficulty the lowest alt can
enter, whitelists the alts and starts when they have all joined. Alts use the
game's friend join control if they land in another lobby. The lobby Play button
is pressed automatically. After the dungeon finishes and rewards arrive, the
host uses the in-dungeon Retry while the lowest alt remains below the next level
requirement. The group returns to the lobby only when the next dungeon or
difficulty unlocks, then creates that newly unlocked stage. **Fixed Dungeon**
keeps retrying the chosen dungeon and difficulty. Carry
choices are saved per account and queue
UIW after teleport while Carry is enabled. The game still controls party and
server capacity.

The **Healer** tab follows one selected player while keeping Auto Dodge active.
When its target is blank, it automatically follows the configured Carry host.
It stops offensive casts, faces the selected player and uses any equipped
healing spell when either the target or the healer loses health. When two
healing spells are equipped, a shared coverage timer spaces their casts so the
second spell is preserved instead of being fired at the same moment. **Equip Maximum Heal Gear**
selects the owned chest and helmet with the most spell power and equips the two
best owned healing spells, favoring Revitalize, Universal Heal and Chain Heal.
Map-wide healing can cast immediately; local heals wait until the healer has
chased within that spell's effective range.
The healer pathfinder treats vertical distance as real distance, jumps early on
short climbs and forces a fresh route when movement stalls. For difficult map
sections, press **Start recording** and manually walk the full dungeon route.
The route saves automatically when the dungeon is completed; **Stop & save** is
also available for a manual save. Enable **Use Recorded Route** to reuse those
account and dungeon specific waypoints on later runs, including reverse
movement toward a host behind the healer. Each dungeon owns a separate route.
The target, follow distance and healer choices are saved per Roblox account and
continue after dungeon teleports.

Base version: **v44.20** (from `UIW_v44.17.lua`). The split is lossless: building
reproduces that file byte for byte.

## Load it in Volt

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/hhmohd1230-wq/UIW/main/loader.lua"))()
```

The loader always takes the current build from GitHub, saves it next to the
executor (`UIW/UIW.lua` — so Auto Execute still works after a teleport) and falls back to that saved copy only
when GitHub cannot be reached. To pick another build, set one of these before
the line above:

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
| `accounts/<RobloxUserId>/configs/<name>.json` | One saved setup (switches + sliders) for that account |
| `accounts/<RobloxUserId>/uiw_meta.json` | That account's Auto Load, Auto Execute, script path and Black Screen state |

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
* Old shared configs stay in `UIW/configs`. Use **Import old shared configs to
  this account** on the Configs tab to copy them explicitly. Existing account
  configs are never overwritten. Each account sets its own Auto Load and Auto
  Execute choices.

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
| `src/carry/system.lua` | Host and alt party coordination, reward gated retry and stage selection |
| `src/healer/system.lua` | Target following, healing casts and maximum spell power loadout |
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
