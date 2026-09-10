# Project context: SCRAPSTORM: NIGHT SHIFT

This is a free portfolio game, also known as 午夜清扫队. Read docs/DEVELOPMENT_START.md, docs/V05_OVERTIME_PLAN.md and docs/DECISIONS.md when resuming development. The creator has answered the initial planning questions; proceed from the recorded decisions.

## Agreed direction

- Codex leads implementation, integration, asset research/creation, validation, and documentation. The creator provides direction and playtest feedback.
- Godot Standard, typed GDScript, Compatibility renderer; Windows x86_64 and desktop browsers; keyboard and mouse first.
- English (en) is the first-launch default regardless of OS language. Offer Simplified Chinese (zh_CN) in-game and persist the player's choice.
- Free downloadable resources with suitable terms, original procedural assets, and AI-assisted creation are preferred. Start with zero paid tooling/assets and a coherent cartoon industrial style.
- Track actual asset sources and terms in docs/ASSET_REGISTER.csv. Candidate resources are not installed or in use until actually added.
- Current v0.5 makes OVERTIME the primary mode: every third room is a boss, sectors rotate by cycle, four tool slots, route risks/boons, boss checkpoint extraction, history and achievements. Preserve three-sector NIGHT SHIFT (three slots) and three-minute QUICK SWEEP. CONTRACTS remains a later mode, with no nonfunctional entry. See docs/V05_OVERTIME_PLAN.md and docs/GAME_BRIEF.md.
- Shops have unlimited thinking time. Never record shop duration or use it in rewards, scores or balance telemetry.
- Persistent coins buy cosmetic skins/colors and the Singularity blueprint. Pulse and Overdrive are free; v1 saves that bought Overdrive receive a one-time 180-coin refund. Keep coins, run scrap, discharge energy and active-skill charge separate; no endless permanent attack/health scaling.
- The creator still found v0.3 bosses too easy. Require readable active counterplay and preserve failed probes; old automated results never override human difficulty feedback.
- v0.5.1 implements the creator-approved B boss loop: reliable automatic damage, dedicated counter/battery energy, a six-second burst opening, and aim-based boss focus. No new left-click primary gun. See docs/BOSS_COUNTER_B.md and current BUILD_REPORT.md; v0.5.0 build evidence is archived.

## Implementation priorities

- Validate a minimal Windows and Web export early, including input, audio, pause/focus behavior, and language selection.
- Separate scrap currency, discharge energy and ability charge. Active skills start ready, charge from field pickups, limited actual non-ability boss damage, and dedicated B boss supplies. Boss entry readies the active skill once; counters and battery deaths provide finite event rewards, never currency/healing. Skill damage itself and shop time never recharge skills. Do not add a second long cooldown. Each pickup and enemy death settles once.
- Keep Resource configuration separate from per-run mutable state. Use one damage entry point and local signals; reserve Autoloads for actual cross-scene services.
- Keep gameplay RNG separate from presentation RNG. Shop checkpoints must preserve current gameplay/shop RNG, offers, sold items, reroll/removal allowance and skill charge/branch choices, not only seed. Preserve validated primary/backup saves, transactional v1/v2-to-v3 migration/refunds and writes, and run-settlement deduplication. Do not conflate profile version 3 with the world checkpoint envelope version 1.
- Three original 32-bar scores use synchronized bed/rhythm/boss layers; retain independent music/SFX controls, bounded players, warning priority and Web gesture gating. Audio measurements are not listening approval.
- Use named input actions and translation keys. Add both English and Chinese text for new player-facing features.
- Current build evidence belongs in docs/BUILD_REPORT.md; v0.3/v0.4 evidence is archived in docs/BUILD_REPORT_v0.3.0.md and docs/BUILD_REPORT_v0.4.0.md. Do not claim old test/export counts for new changes.
- Measure before optimizing; run checks appropriate to the change. Report planned, implemented, and verified states separately.

## Documentation and release

- Development documents are Chinese; README is bilingual with English first.
- Preserve docs/reference/ORIGINAL_CONCEPT.md as the original reference. Current decisions and scope live in the active documents.
- Record real implementation and AI-assisted contributions accurately in portfolio materials.
- Public author name, GitHub ownership, and source-code license can be finalized before release and do not block local development.
- The selected English title is SCRAPSTORM: NIGHT SHIFT; the repository naming plan is scrapstorm-night-shift.
