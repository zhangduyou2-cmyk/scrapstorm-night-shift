# Changelog

Versions below describe local development milestones. They do not imply that matching GitHub Releases were published. Exact validation and limitations are recorded separately in the linked reports.

## 0.5.1 — 2026-09-07

- Reworked sector bosses around steady automatic damage, dedicated counter/battery energy and six-second burst windows.
- Added progressive valve supply, shared shooting/reclaim node settlement, aim-based boss focus, support stun and visible recharge feedback.
- Preserved independent skill charge, no-currency/no-healing supply rules and existing checkpoint formats.
- Local validation: 25 Godot suites / 1,390 checks passed; original/extracted Windows launch verified. Final Web attempts ended in ordinary combat deaths before reaching the shop; the complete flow did not pass.

[Release notes](docs/RELEASE_NOTES_v0.5.1.md) · [Build report](docs/BUILD_REPORT.md)

## 0.5.0 — 2026-09-07

- Introduced OVERTIME as the primary mode: room objectives, rotating sectors, bosses every third room, route bonuses/risks and extraction.
- Expanded to eight tools and six evolutions, including four-slot endless loadouts.
- Added 100-run battle history, 16 achievements, cosmetic rewards and transactional profile v3 migration.
- Replaced the main-menu presentation with original hangar key art and live equipment controls.

[Archived evidence](docs/BUILD_REPORT_v0.5.0.md)

## 0.4.0 — 2026-09-07

- Added deployment preparation, a workshop, independent active-skill charge and exclusive branches.
- Added limited tool removal, the original three behavior evolutions, active boss counters, elite interactions and richer combat feedback.
- Introduced free Overdrive migration/refund handling and optimized ordinary enemy rendering with an atlas.

[Archived evidence](docs/BUILD_REPORT_v0.4.0.md)

## Earlier prototypes

v0.3 established three-sector NIGHT SHIFT, original layered music, progression and shop checkpoints. v0.2 added the five-wave Demo and shop; v0.1 established the movement/reclaim/discharge survival loop. Historical reports remain under `docs/BUILD_REPORT_v*.md`; old claims are not current-version acceptance evidence.
