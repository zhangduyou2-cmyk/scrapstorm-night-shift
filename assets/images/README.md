# Original main-menu image / 原创主菜单原图

This source-controlled record preserves the v0.5 visual provenance independently of local `artifacts/` files. The project is a free portfolio game; no asset purchase or external paid API was used.

## Included image

| Field | Value |
| --- | --- |
| File | `hangar-keyart-v05.png` |
| Purpose | SCRAPSTORM: NIGHT SHIFT v0.5 main-menu industrial hangar key art |
| Creation | OpenAI built-in `image_gen` tool, original project prompt, 2026-09-07 |
| Actual native dimensions | **1672 x 941 pixels** |
| Requested dimensions | 3840 x 2160; the tool returned 1672 x 941 instead |
| File size | 2,056,211 bytes |
| SHA-256 | `b6c6333d376416dbab454b212c1d17c5d114e01ea340afc4423d198e74242050` |
| Generation output identifier | `exec-58651e58-0398-4fe9-b49b-b5fe83a86253.png` |
| Image modifications | None; original PNG and embedded provenance metadata retained |
| Seed/model details | Not supplied by the image-generation tool; no reproducibility guarantee from a seed |
| Public reuse license | MIT, to the extent the creator holds the relevant rights; see ../../LICENSE |

The image is AI-assisted original project artwork, not a downloaded third-party game image or a claim of human painting. It does not depict a deliberately copied existing game/movie character. A prompt requesting 4K did not produce a 4K-native source; the file was not artificially upscaled or repainted afterward. The metadata and exact hash identify the delivered source. This note records provenance; the root MIT LICENSE supplies the reuse terms to the extent the creator holds the relevant rights.

## Original generation prompt

The following prompt was supplied to the built-in tool:

```text
Use case: stylized-concept. Asset type: original high-resolution PC action-survival game main-menu key art, a background painting only. Create a premium cinematic 3840 x 2160 landscape illustration of a midnight scrap-reclamation maintenance hangar. Composition is critical: LEFT 42% of the entire canvas is very dark quiet coal-blue atmospheric wall and empty shadow, suitable for real game buttons to be overlaid, with no focal objects or bright lamps there; RIGHT 58% holds the scene and hero. A compact, broad, tough but appealing cleaning robot occupies x=70% to 88%, y=43% to 80%, a squat armored machine on two WIDE REALISTIC rubber caterpillar tracks with sprockets, articulated side cleaning brushes and a chunky scrap suction nozzle. Its chassis is low and rectangular with bevelled corners, with a small black horizontal sensor visor and two subtle cyan eyes, NOT a humanoid and NOT an egg or tall sphere. Robot silhouette is wider than tall, recognizably an industrial street-cleaning crawler. Make it feel like a memorable original game character, no existing movie/game character design. Rich PBR-like painterly 3D materials: layered scuffed gunmetal steel, muted ochre armor accents, chipped edges, grease, bolts, vents, cable connections, brush bristles and worn tread blocks, crisp enough for 4K. Three-quarter front view, grounded on a raised repair platform; natural perspective and correct un-stretched proportions. Behind it on the far right: a powerful service crane/robotic repair arm, deep hangar bays, suspended warm amber workshop lamps, far cyan power coils, atmospheric dust shafts, a small welding blue electrical arc, chains and soft drifting steam. Floor grating and oily puddles catch localized warm and cyan reflections. Strong depth, separation of foreground/midground/background, dramatic but readable silhouette, polished indie-game key-art quality, restrained glow rather than flat vectors or toy-like ellipse shapes. Colors coal navy #101c24, graphite steel #334751, warm amber #ffc04d, ivory #ede3ce, tiny electric cyan #58d9e7. Very subtle vignetting, darkest on the left. No title, no text of any kind, no signs, no letters, no numerals, no logos, no UI, no borders, no watermark. This will be a real game background with fully separate live translated controls.
```

## Integration and proportion

`scripts/ui/launch_hangar.gd` draws this image with uniform cover scaling and a centered crop. A separate 1280 x 720 design canvas holds live Godot buttons, translated labels, the player's actual profile summary, and current loadout. Its layout uses uniform contain scaling. No titles, buttons, prices, or translation text are baked into the PNG.

The painting shows a fixed industrial-yellow crawler. Equipped cosmetics are represented in the live current-loadout summary and the separate code-native workshop/deployment previews; the static painting does not recolor itself or assert a different equipped skin. A few bounded, slow dust points add ambient movement and honor the reduced-effects setting.

Native component screenshots were checked at 1280 x 720, 1920 x 1080, 960 x 540 and 2554 x 1513 in English and Simplified Chinese. Under the real project's keep-aspect setting, a 2554 x 1513 window produces a 2554 x 1436 viewport image with letterbox space outside it. This preserves proportions; viewport capture dimensions and window dimensions must not be confused. Native layout checks do not establish exported Web compatibility or game performance.

The menu's Rajdhani Bold and Noto Sans CJK font resources use private MSDF glyph caches for scalable text; original font bytes remain unchanged. Full upstream sources, hashes and separate OFL texts are in [the font README](../fonts/README.md).

## Related code-native artwork

- `scripts/ui/hangar_visual.gd` and `skill_preview.gd`: original broad crawler geometry and uniform preview/effect transforms.
- `scripts/ui/archive_panel.gd`: original geometric achievement medals and reward previews; titles are real text.
- `scripts/ui/shop_panel.gd`: original eight-tool and repair icons, with three-slot/four-slot layouts.
- `scripts/game/game_world.gd` and `player_ability.gd`: in-game cosmetic/skill rendering, including achievement rewards.

Achievement palettes use cobalt body `#295f94` / highlight `#74e7ff`, aurora body `#205b59` / mint `#8af0bf` / violet `#bb91ff`, ember effects `#ff8c4b`, and prism effects `#f6a9ef`. These are code-native project colors rather than downloaded skins or image files. Player color choice does not recolor enemy danger telegraphs.

以上素材均以真实制作方式登记：AI辅助原图与代码原生几何分别说明，不把原图请求尺寸、游戏窗口尺寸或公开作品集用途当作分辨率及许可的替代证据。
