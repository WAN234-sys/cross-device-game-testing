# 🎮 Buddy Maze — Cross-Device Game Testing

A co-op multiplayer maze game built with **Godot 4.3**. 2–10 players work together to solve puzzles, complete quests, and escape themed mazes. Think *REPO × Peak × Big Walk* but tiny creatures in giant environments.

## Features

- **5 Themed Maps** — Kitchen Counter, Toy Chest, Grandma's Attic, Garden Shed, School Backpack
- **4 Phases per Map** — Progressive gates that unlock as you complete quests
- **6 Quests per Map** — Fetch, collect, co-op plates, reach markers, survive zones, talk to NPCs
- **30 Quest Coins** — Earn coins and spend them in the Buddy Shop on hats and colors
- **16 Obstacles per Map** — Push zones, slow zones, patrol enemies, timed hazards, dark rooms
- **15+ NPCs** — Breadwise the crouton, General Blockhead, Dr. Spots the ladybug therapist…
- **72 3D Assets** — Characters, environments, items, hats, all in GLB format
- **Co-op Required** — Solo explore is allowed, but gates and the exit need 2+ players
- **Cross-Platform** — Windows, Linux, Android, and Web builds via CI

## Controls

| Action | Keyboard/Mouse | Gamepad |
|--------|---------------|---------|
| Move | WASD | Left stick |
| Look | Mouse | Right stick |
| Jump | Space | A / Cross |
| Sprint | Shift | L3 |
| Interact / Talk | E | X / Square |
| Grab / Throw | Left click | RT |
| Crouch (buddy boost) | C | B / Circle |
| High-five | H | Y / Triangle |
| Emote wheel | Hold G | Hold D-pad Up |
| Ping | Q | D-pad Down |
| Pause | Escape | Start |

## Building

### Prerequisites
- [Godot 4.3](https://godotengine.org/download) (standard or .NET)

### Run locally
```bash
# Open in Godot editor
godot --path . --editor

# Or run directly
godot --path .
```

### Export builds
The CI workflow (`.github/workflows/build.yml`) automatically builds on push to `main`:
- **Windows** (.exe)
- **Linux** (x86_64)
- **Android** (.apk, debug signed)
- **Web** (HTML5)

Tag a release (`v0.1.0`) to attach builds to a GitHub Release.

### Run tests
```bash
godot --headless --path . -s tests/smoke_test.gd    # 20 checks
godot --headless --path . -s tests/maps_test.gd     # All 5 maps validation
```

## Multiplayer

- **Host**: Creates a room with a 4-letter code
- **Join**: Enter the host's IP address (same network)
- **Solo**: Play alone with drop-in — friends join mid-run
- Uses **ENet** for LAN/direct-IP connections
- Host-authoritative model: host decides token collection, gate state, quest completion

> ⚠️ Web builds use ENet which doesn't work in browsers. WebRTC upgrade needed for online play.

## Project Structure

```
scripts/
  autoload/       # GameManager, NetworkManager, AudioManager, QuestManager, etc.
  maps/           # MapBase, MazeBuilder, MazeGen, GenericMap, MapContent
  obstacles/      # ObstacleBase, PushZone, SlowZone, PatrolEnemy, TimedHazard, DarkRoom
  npcs/           # FriendNPC, QuestNPC
  quests/         # QuestItem, QuestMarker
  puzzles/        # PressurePlate, PuzzleGate, PhaseGate, MultiPlateController
  player/         # BuddyPlayer (first-person controller)
  ui/             # MainMenu, Lobby, GameHUD, CoinShop, Settings, Customize
  visual/         # ModelSwap (runtime GLB loader)
scenes/
  maps/           # 5 map .tscn files
  characters/     # Player scene
  puzzles/        # Plate, gate, token scenes
  ui/             # Menu, lobby, HUD scenes
assets/
  models/         # 72 GLB files (characters, environment, items, effects, NPCs)
  audio/sfx/      # 11 OGG sound effects
  shaders/        # Colorblind accessibility shader
  textures/       # Icon
tests/            # Smoke test, maps test, network test, screenshot test
tools/            # Maze checker, scene validator, linter
```

## License

Game code: MIT. Audio from Sound FX Starter Pack Vol. 1 (royalty-free, not redistributed in repo).
3D models generated via Blender MCP.
