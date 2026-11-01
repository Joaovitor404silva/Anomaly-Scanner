# Anomaly-Scanner

A **S.T.A.L.K.E.R. 2: Heart of Chornobyl** plugin for [Game Crawler](https://github.com/Joaovitor404silva/Game-Crawler), the
live in-process debugger and MCP server for games. Game Crawler gives the generic tools (Unreal reflection, memory, hooks,
breakpoints, input bot, CLI and MCP); this plugin adds what only Stalker 2 has:

- `quest`: the live quest graph. List quests, read a quest or node state, start or end a node, and tap start/end/done events
- `npcs`: per-NPC census (uid, address, class, hp, distance, location, hidden, object index), sorted by distance
- `uid`: the UID of an actor, usable with console functions such as `XKillNpcByUID`
- `nbot`: a scripted player bot (movement, scenes, quest goals) driven through files in `bench\io\<port>`
- A guard that repairs the game's per-thread frame state when a UFunction call made by Game Crawler faults

> Built for game build **26123434** (Update 2.1). Other builds may need new signatures or offsets. Unofficial,
> single-player only, use at your own risk; read the [Disclaimer](#disclaimer).

## Install

1. Set up Game Crawler and its dev copy of Stalker 2 (see its README).
2. Clone this repo into Game Crawler's plugin folder:

   ```
   cd <Game-Crawler>\plugins
   git clone https://github.com/Joaovitor404silva/Anomaly-Scanner anomaly-scanner
   ```

3. Start the dev game. Game Crawler builds and loads `plugins\anomaly-scanner` by itself (or run
   `plugins\build_plugin.bat anomaly-scanner`). `plug list` shows it with its commands.

In any other game the plugin loads but stays idle, and its commands say so.

## Use

From the Game Crawler CLI or the MCP `raw` tool:

```
quest list filter=E01
quest state E01_MQ01
quest tap on
quest tap show since=0
quest end E01_MQ01_Talk
quest layout
npcs near=pawn r=3000 max=20
uid 0x7ff15e8a4000
```

The MCP server picks up `mcp.js` from this folder and adds the `quest`, `npcs` and `uid` tools.

## Files

| File | Role |
|---|---|
| `anomaly.cpp` | Plugin entry points, `quest` / `npcs` / `uid` commands, call guard |
| `quest.h`, `qring.h` | Quest graph reader and the event ring |
| `s2n_peframe.h` | Per-thread frame repair after a faulting call |
| `nbot*.cpp`, `nbot*.h`, `quest_goals.tsv` | Scripted player bot |
| `opts.h` | `key=value` argument parsing |
| `mcp.js` | MCP tools for the commands |
| `test\` | Unit tests (`test\build.bat`, run from inside Game Crawler's `plugins\anomaly-scanner`) |

## Configuration

| Variable | Default | Meaning |
|---|---|---|
| `ANOMALY_NBOT` | `1` | `0` keeps nbot inert |
| `S2_BRIDGE` | | Folder of the scene bridge used by nbot scenes |

## Disclaimer

- **Unofficial.** This project is not affiliated with, endorsed by or supported by GSC Game World, Microsoft, Valve or
  Epic Games. S.T.A.L.K.E.R. 2: Heart of Chornobyl is a trademark of GSC Game World. Unreal Engine is a trademark of Epic Games.
  All other trademarks belong to their owners.
- **No game content.** This repository contains no game code, assets, decompiled code or data from the game.
- **Single-player and offline use only.** Do not use it in online or multiplayer sessions, with anti-cheat, or to gain an
  advantage over other players. Doing so may break the game's terms of service and can get your account banned.
- **Use at your own risk.** It runs code inside the game process and writes to its memory. It can crash the game, corrupt
  saves or cause data loss. Back up your saves. The software is provided "as is", without warranty of any kind; see `LICENSE`.
- **Your responsibility.** You are responsible for complying with the game's EULA and the laws of your country.
- **AI-assisted.** Parts of this project were written with the help of AI coding tools.

## License

MIT, see `LICENSE`.
