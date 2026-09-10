# Contributing

This is an AI-assisted portfolio game directed by zhangduyou2-cmyk. Focused bug reports, playtest observations, translation fixes and small improvements are welcome once the repository is published. Source and original-asset licensing is still being finalized; do not assume a reuse license that has not been granted.

## Start here

Read the [README](README.md), [architecture](docs/ARCHITECTURE.md) and [current decisions](docs/DECISIONS.md). The maintained setup targets Windows, Godot 4.7.2 Standard and Python 3.11+:

```powershell
.\tools\setup_godot.ps1
.\Play.ps1 -Editor
python tools/run_tests.py
```

The test runner uses isolated `--test-settings` profiles and detects script errors even when Godot returns exit code zero. To run a focused suite:

```powershell
python tools/run_tests.py --label focused tests/test_loadout.gd
```

Other installed engine locations can be supplied with `--godot`. See the [tool guide](tools/README.md) for process-scoped PowerShell commands, clean-source verification and optional browser/audio dependencies. Non-Windows development has not received the same package verification as Windows.

## Make a reviewable change

Describe the player-facing problem and resulting behavior. Keep unrelated cleanup separate. For larger mode, economy or architecture changes, discuss the scope before implementing a large patch.

- Use named input actions and include both English and Simplified Chinese text for new UI.
- Keep mutable run state separate from shared definitions. Route damage through the world and persistent transactions through the profile service.
- Preserve old save migrations, settlement deduplication and deterministic shop/route state.
- Never record shop dwell time or turn it into score, rewards or charging.
- Record new asset origins and terms in `docs/ASSET_REGISTER.csv`; preserve required third-party notices. Disclose generated material and meaningful AI assistance accurately.

Run the affected suites. Explain what was tested, which engine/platform was used, and what remains untested. Native state fixtures, ordinary-input runs, browser tests and performance measurements are different kinds of evidence. Screenshots with injected state must say so.

Do not commit `.godot`, downloaded engines/templates, raw captures, exports, local profiles, credentials or machine-specific paths. Curated public gallery files belong in `docs/media` with provenance. Do not include an entire save or unredacted log when a minimal reproduction will do.

## Reports and pull requests

A useful bug report includes the version, mode/sector, steps, expected and actual behavior, and platform/browser. Include a seed or short redacted log if relevant. Difficulty feedback should describe the loadout and encounter, not just a win/loss count.

A pull request should explain the change and relevant validation. Existing automated failures or incomplete browser coverage must remain visible. Do not claim maintainer approval, successful CI or a public release that has not occurred. Use the [security reporting guidance](SECURITY.md) for sensitive issues.

## 中文补充

欢迎聚焦的问题复现、试玩反馈、翻译修正和小范围改进；较大玩法或架构变化先说明范围。使用固定 Godot 版本与隔离测试，不提交个人档案、缓存、导出或凭据。界面文本同时提供英中，素材记录来源和许可，AI 辅助贡献如实披露。商店停留时间永远不记录。提交说明应写清改了什么、实际验证什么，以及仍未覆盖的部分。
