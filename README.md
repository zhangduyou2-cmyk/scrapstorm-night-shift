# SCRAPSTORM: NIGHT SHIFT

**Reclaim the wreckage. Rebuild your rig. Decide when to clock out.**

A free, single-player, top-down action survival game made with **Godot 4.7.2**, typed GDScript and the Compatibility renderer. Drive a modified cleaning crawler through industrial night shifts, assemble an evolving tool build, and push an endless expedition as far as you dare.

[完整中文说明](docs/README.zh-CN.md) · [Architecture](docs/ARCHITECTURE.md) · [v0.5.1 release notes](docs/RELEASE_NOTES_v0.5.1.md) · [Validation](docs/BUILD_REPORT.md)

**[Download Windows v0.5.1 — ~63 MB](https://github.com/zhangduyou2-cmyk/scrapstorm-night-shift/releases/download/v0.5.1/Scrapstorm-Night-Shift-v0.5.1-Windows.zip)** · **[Release notes and checksums](https://github.com/zhangduyou2-cmyk/scrapstorm-night-shift/releases/tag/v0.5.1)**

**Status:** Windows v0.5.1 is published as a free playtest release. Source and creator-held original assets use MIT. A desktop Web export can be built locally; there is no hosted Web demo.

**Windows playtest package:** extract the complete Windows ZIP and double-click `Play.cmd` (or `Scrapstorm.exe`). No development tools are needed. First-time players start with fresh progress; subsequent launches preserve their own saves. The private recording edition and the creator's saves are excluded. [Current distribution checks](docs/DISTRIBUTION_CHECK.md).

| The hangar | Counter, recharge, burst |
| --- | --- |
| ![Default hangar menu and current equipment](docs/media/v051-hangar.png) | ![Staged six-second boss counter window with full discharge energy](docs/media/v051-counter.png) |
| **Build a four-slot rig** | **Earn cosmetic rewards** |
| ![Staged endless shop with four tools and two active evolutions](docs/media/v051-build.png) | ![Staged achievement archive showing the Aurora reward](docs/media/v051-achievements.png) |

These are unedited screenshots rendered by the game. The hangar uses a fresh profile; boss, build and achievement screens use **staged presentation states**, not claimed playthroughs. [Image provenance and reproduction](docs/media/README.md).

## What you can play

| Mode | Structure |
| --- | --- |
| **OVERTIME** | Main endless mode: four tool slots, supplies after each room, a choice of bonus and next-room risk, a boss every third room, and rotating sectors. Extract after a boss or keep going. |
| **NIGHT SHIFT** | Choose one of three sectors. Five stages total 870 combat seconds, followed by its boss. Three tool slots. |
| **QUICK SWEEP** | Immediate three-minute survival using your equipped skill and cosmetics. |

Each sector has its own layout, enemy variants, boss counter and original layered score: **Rustyard**, **Conveyor Foundry** and **Neon Reactor**. Endless ordinary rooms last 65–80 combat seconds; completed objective rooms may end after 40 seconds. Shops allow unlimited thinking time, and **shop duration is never recorded**.

Eight automatic tools—Rotary Brush, Foam Sprayer, Arc Coil, Rotary Saw, Prism Cutter, Seeker Pods, Orbit Drones and Echo Mines—combine with six evolutions and eight temporary endless bonuses. Three independently charged active skills offer clearing, gravity control or faster tool operation. Boss counters refill discharge energy and create a **six-second burst window**; aiming at the boss focuses eligible tools within their real range and line of sight.

The archive retains **100 runs**. **16 achievements** award coins, illustrated medals, skins, skill colors and titles. No-hit awards use actual damage history; healing cannot erase a hit. Cosmetic rewards add no permanent combat stats. CONTRACTS is a future mode and has no playable entry yet.

## Controls

| Input | Action |
| --- | --- |
| WASD | Move |
| Mouse | Aim; place Singularity |
| Hold right mouse / release | Reclaim / discharge stored energy |
| Space | Dash |
| E | Use the equipped active skill |
| Esc | Pause or go back |

Tools attack automatically. English is the first-launch default; Simplified Chinese, key rebinding, hold/toggle reclaim, volume controls and reduced effects are available in Settings.

## Run from source

Open `project.godot` in **Godot 4.7.2 Standard** and run the main scene. The maintained helper scripts target Windows and require PowerShell; Python **3.11+** is used by verification and packaging tools.

From the repository root on Windows:

```powershell
.\tools\setup_godot.ps1
.\Play.ps1
```

Setup downloads a local engine. Export templates are a separate download needed for builds. No administrator access, global PATH changes or paid tools are required. For the editor, use `./Play.ps1 -Editor`. If PowerShell blocks scripts, use the process-scoped commands in the [tool guide](tools/README.md); optional browser/audio dependencies are documented there too.

```powershell
.\tools\setup_godot.ps1 -IncludeTemplates
.\tools\build.ps1 -Target All
.\Play.cmd
```

Windows output: `exports/windows-v0.5.1/Scrapstorm.exe`. Keep its adjacent PCK and license files together. Web output: `exports/web/`. Serve it over HTTP rather than opening `index.html` directly:

```powershell
python -m http.server 8765 --bind 127.0.0.1 --directory exports/web
```

Then open `http://127.0.0.1:8765/`. Engine downloads, caches, exports and raw test artifacts are not committed. A source checkout is not a prebuilt download; [release preparation and package contents](docs/RELEASE_NOTES_v0.5.1.md) explain the difference.

## Saves and progression

Progress stays on the current device. Windows and browser saves are separate; there are no accounts or cloud synchronization. Standard and endless runs resume from the **latest shop checkpoint**, not any arbitrary combat frame. Equipment, offers, RNG state, route choices and skill branches are preserved.

Profile v3 migrates older v1/v2 progress, including the previous one-time Overdrive refund. Validated primary/backup files, transactional writes and recent settlement IDs prevent accidental duplicate rewards. Browser storage clearing can remove its local progress. The archive currently has no export button. [Local data and privacy](PRIVACY.md).

## Engineering and evidence

The project demonstrates deterministic run state, explicit UI/world boundaries, shared damage and transaction paths, backward-compatible saves, bounded combat effects, bilingual interfaces and synchronized procedural music. See [the architecture](docs/ARCHITECTURE.md) for the code map and tradeoffs.

- **v0.5.1:** 25 local Godot suites / **1,390 checks passed**. Original and independently extracted Windows packages both started and exited successfully.
- **Boss evaluation:** 12 isolated early-build encounters defeated their bosses using normal battle input. Room and equipment setup was staged; this does not establish full-run economy or human win rates.
- **Web limitation:** both final-build attempts ended in normal combat deaths before the first shop. Each passed nine reached checks with zero page/console/network errors, but **the complete Web flow did not pass**; shop, route and checkpoint reload were not reached in these runs.
- **Publication entry check:** a separate current-build browser run passed **16 checks** with zero browser/network errors: English/Chinese reload persistence, two viewport sizes, all three mode entries, pause, voluntary retreat, and saved battle history. It deliberately does not claim a boss clear or shop checkpoint coverage. Reproduce with `npm ci`, `npm run browser:install`, then `npm run smoke:release` against the local Web server; Node is optional development tooling.
- There is no new v0.5.1 full-scene performance benchmark or promise of stable 60 FPS. Long endless balance, lower-end hardware and subjective music/combat feedback remain work in progress.

Run local regressions with `python tools/run_tests.py`. [The build report](docs/BUILD_REPORT.md) preserves exact versions, hashes, failures and coverage boundaries. It reports local verification, not a claim that hosted CI has run. [Roadmap](docs/ROADMAP.md) · [Changelog](CHANGELOG.md) · [Contributing](CONTRIBUTING.md).

## Authorship and assets

Created under the direction of **[zhangduyou2-cmyk](https://github.com/zhangduyou2-cmyk)**, who supplies the concept, scope decisions, playtest feedback and final approval. **OpenAI Codex** led implementation and assisted design, original procedural art/audio, integration, validation and documentation. This is an explicitly AI-assisted portfolio project; it is not presented as entirely hand-written code or human-composed music.

The hangar key art was AI-generated; combat/UI geometry, animation atlas and synthesized music/SFX have recorded source files. Noto Sans CJK and Rajdhani retain their font licenses; Godot retains its engine/component notices. [Credits](CREDITS.md) · [Asset register](docs/ASSET_REGISTER.csv) · [Third-party notices](THIRD_PARTY_NOTICES.md) · [Security reporting](SECURITY.md).

Project code, documentation and original assets are available under the [MIT License](LICENSE), to the extent the creator holds the relevant rights. Third-party components retain their own licenses. [License scope](docs/LICENSING.md). No paid assets or services were purchased for this project. [Publication checklist and scope](docs/PUBLISHING.md).
