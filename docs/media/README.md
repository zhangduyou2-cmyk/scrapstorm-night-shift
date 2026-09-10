# Screenshot provenance / 展示截图来源

The current README gallery uses four **native, unedited 1280×720 PNG screenshots of v0.5.1**. No compositing, retouching, replacement text or invented gameplay has been added. Files were copied byte-for-byte from the capture output; [gallery-manifest.json](gallery-manifest.json) records hashes and the capture script.

| File | State represented |
| --- | --- |
| [v051-hangar.png](v051-hangar.png) | Fresh isolated profile in the actual main menu. |
| [v051-counter.png](v051-counter.png) | Staged boss, entity positions and pre-counter resources; the real counter function produces the exposed state and HUD. |
| [v051-build.png](v051-build.png) | Staged four-slot tools, modifiers, wallet and room clock; the actual shop and evolution rules render the result. |
| [v051-achievements.png](v051-achievements.png) | A synthetic completed run is settled through the real profile service, then the actual reward page is shown. This is not claimed human-earned progress. |

All four images were visually reviewed. These are presentation/rendering evidence, not browser, performance, win-rate or complete-playthrough evidence. Interface animations and random shop offers may differ when rerun.

## Reproduce

From the repository root, after importing with the pinned engine:

```powershell
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --path . --script tests/capture_public_gallery.gd -- --test-settings
```

The script writes `captures/public-gallery-v051/` and an artifact report, using its own PID-scoped profile/settings and cleaning them afterwards. Copy the chosen PNG files into `docs/media` without changing pixels and refresh the manifest if replacing the gallery.

The older `menu.png`, `gameplay.png` and `*-v02.png` files are retained as historical images. They are not used to represent the current version.

中文：当前四张图全部是实际游戏原生渲染、逐字节复制的未修图 PNG。仅机库为全新默认状态；首领、构筑、成就使用已披露的展示夹具，不能当作自然游玩成绩。旧图只保留历史用途。
