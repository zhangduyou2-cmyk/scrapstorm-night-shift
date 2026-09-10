# Local data / 本地数据说明

Applies to the project's unmodified v0.5.1 Windows and Web builds.

The game has no account, analytics SDK, advertising, online leaderboard, telemetry upload, or cloud save. Gameplay code does not send run records to a server. Downloading a Web build still contacts its host; that host's ordinary request logs and privacy policy are separate from this game.

Godot's local `user://` storage holds:

- `settings.cfg`: language, sound, visual/accessibility preferences, key bindings, and tutorial preference.
- `profile.json` and its recovery files: coins, owned/selected cosmetics and skills, local records, recent battle history, achievements, progression, and an available shop checkpoint.

Windows saves belong to the current OS user. Web saves belong to the browser profile and site origin; clearing site data or using a different browser/address can remove or separate progress. There is no cross-device synchronization. Local files are not encrypted. Profile checksums detect corruption and are not an anti-cheat system; settings use an ordinary local configuration file. Back up saves before manual changes. Deleting all game save/settings files, or clearing the game's browser site data, resets local progress.

Native development fixtures use isolated save paths with `--test-settings`. Browser automation uses a separate browser context for its local storage. These are different isolation mechanisms.

The Windows `Play.cmd`/`Play.ps1` launcher can write local startup-error diagnostics to `%LOCALAPPDATA%/Scrapstorm-Launcher/launcher.log`. This is separate from game saves and is not uploaded or included in distribution packages. It identifies an existing game by its exact executable path and restores its window; it does not inspect or change a separate recording edition's profile.

Opening the Web build with `?smoke=1` enables a diagnostic snapshot at `window.__scrapstorm`; the presence of any `smoke` query parameter enables it, regardless of its value. The snapshot includes current combat state, positions, shop offers and selected equipment/progression summaries. Page scripts can read or replace that JavaScript object, but there is no write-back API into the game. It is not uploaded. The query parameter itself does **not** isolate or reset saves: a manually opened test URL uses that browser profile and site's ordinary storage. Normal launches without the parameter leave the diagnostic channel disabled.

本作不要求注册，也没有游戏内广告、统计上报或云存档。设置、金币、皮肤、技能、成就、战斗记录与商店检查点保存在本机或当前浏览器站点数据中。换设备不会同步；清理浏览器数据可能丢失进度。公开反馈时请移除日志中的本机路径，不必附上个人存档。`smoke` 查询参数仅开放页面内诊断观察，不会隔离或重置存档；手动打开此链接仍使用当前浏览器/站点的普通进度。
