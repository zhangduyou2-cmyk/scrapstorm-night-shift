# Third-party notices / 第三方声明

Project: **SCRAPSTORM: NIGHT SHIFT**. Updated 2026-09-10.

The game is a free portfolio project. Materials below retain their own license
independently of the project's MIT license. Only assets actually
included are listed here; researched candidates are listed in the art plan.

本作是免费作品集。以下仅列实际纳入的素材；第三方许可独立于项目 MIT 许可。

## Noto Sans CJK SC Regular

Game distributions include the full font license as FONT-LICENSE.txt next to the executable or web entry point.

- File / 文件: `assets/fonts/NotoSansCJKsc-Regular.otf`, version 2.004, unchanged.
- Copyright / 原字体版权: © 2014-2021 Adobe (http://www.adobe.com/).
- Upstream / 官方来源: [Noto CJK repository](https://github.com/notofonts/noto-cjk/blob/f8d157532fbfaeda587e826d4cd5b21a49186f7c/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf).
- License / 许可: SIL Open Font License 1.1.
- Complete license / 完整许可: [assets/fonts/OFL.txt](assets/fonts/OFL.txt).
- Provenance and checksum / 来源及校验值: [font README](assets/fonts/README.md).

Keep the font copyright notice and full OFL text with copies of the font,
including game distributions. The downloaded font has not been renamed or modified. Godot FontVariation applies UI emboldening at runtime; no new font file is generated.

## Rajdhani Bold

- File / 文件: `assets/fonts/Rajdhani-Bold.ttf`, unchanged; 400,680 bytes.
- Copyright / 版权: Copyright (c) 2014, Indian Type Foundry (info@indiantypefoundry.com).
- Upstream / 官方来源: [Google Fonts Rajdhani](https://github.com/google/fonts/tree/main/ofl/rajdhani).
- License / 许可: SIL Open Font License 1.1; [complete license](assets/fonts/Rajdhani-OFL.txt).
- SHA-256: `691470dd3286a14e9677940d0bf75796179841ba5215cbda1a2c8910a3226afd`.
- Provenance / 来源: [font README](assets/fonts/README.md).

The free, unmodified font supplies the v0.5 main-menu Latin display type. The build script copies its complete license as `RAJDHANI-LICENSE.txt` next to the executable or Web entry point, independently of Noto's `FONT-LICENSE.txt`. Keep its copyright and full OFL with copies.

Both main-menu fonts use private Godot FontFile resources with MSDF glyph caching at runtime. This improves enlarged text rendering without modifying or renaming the original OTF/TTF files; it does not create a modified font distribution.

## Original music and procedural audio / 原创音乐与程序音效

The twenty-two WAV effects and nine synchronized Ogg music layers in `assets/audio/`
were synthesized for this project with [tools/generate_audio.py](tools/generate_audio.py)
and [tools/generate_music.py](tools/generate_music.py). The three original scores
are **Afterhours Salvage**, **Pressure Circuit** and **Neon Induction**, each with
32 bars, four sections and melodic/rhythm/boss layers.

Composition, synthesis and implementation were AI-assisted by OpenAI Codex on
2026-09-07. There are no third-party audio samples, downloaded recordings or
melodies, pretrained audio-generation models, or paid generation services in
these assets; no human composer or performer is claimed. Free Python libraries
are development tooling, not an added game runtime.

[Production notes](assets/audio/README.md) and [the music manifest](assets/audio/music/manifest.json) and [the SFX manifest](assets/audio/sfx_manifest.json)
record source methods, actual delivered hashes, loop lengths and measurements.
Original material is covered by the project's MIT LICENSE to the extent the creator holds the relevant rights. Preserve the recorded AI-assisted provenance.

二十二个短音效、三首地图音乐的九个同步层，由振荡器、包络、确定性噪声与原创编曲合成，
记录为Codex辅助完成的项目原创资源。未下载录音采样，未购买付费服务，不冒称人类作曲或演奏。
原创素材在创作者有权授权的范围内采用项目 MIT LICENSE，保留真实制作来源记录。

## Godot Engine 4.7.2

The Windows and Web builds use Godot Engine 4.7.2.stable.official.ed1daf0bf.
Godot is Copyright (c) 2014-present Godot Engine contributors and Copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur, licensed under MIT.
The exact upstream notices for this version are preserved in [GODOT_LICENSE.txt](assets/licenses/GODOT_LICENSE.txt) and [GODOT_COPYRIGHT.txt](assets/licenses/GODOT_COPYRIGHT.txt), including third-party components. Both files are copied alongside each distribution by the build script.

## Project visuals / 项目视觉

The in-game robot, preview geometry, arena, enemies, pickups, effects, achievement medals and icon are original procedural/vector graphics authored for this project with Codex assistance. The separate v0.5 main-menu raster illustration has the AI-image provenance documented below. They do not use downloaded third-party image samples. Their implementation includes scripts/ui/launch_hangar.gd, archive_panel.gd, overtime_panel.gd, main.gd, mission_panel.gd, garage_panel.gd, hangar_visual.gd, skill_preview.gd, shop_panel.gd, scripts/game/game_world.gd, standard_director.gd, standard_boss.gd, mechanical_encounters.gd, player_ability.gd, evolution_effects.gd, combat_feedback.gd, arena_detail.gd, and assets/icon.svg. The maintenance hangar, articulated robot, three maps, enemy variants and elites, boss counter targets, skill/evolution previews, ability colors and mod icons use original procedural drawing; no third-party character or environment image pack is included. The v0.5 wide crawler, cobalt/aurora achievement palettes, ember/prism ability colors, medal shapes and eight-tool shop icons are code-native project geometry and colors.

The original normal-enemy body geometry is also baked into `assets/sprites/enemy_atlas.png`
with `tools/bake_enemy_sprites.gd`: nine map/type variants, four motion frames and
four hit frames each, 72 tiles in a 640 x 720 RGBA image. The editable geometry and
runtime fallback remain in the game. No external sprite pack was downloaded;
warning shapes, health bars, elite enemies and bosses continue to render dynamically.

## AI-assisted main-menu image / AI辅助主菜单原图

`assets/images/hangar-keyart-v05.png` was generated for this project with OpenAI's built-in `image_gen` tool on 2026-09-07, using an original industrial-crawler hangar prompt. It is **1672 x 941 pixels**, 2,056,211 bytes; SHA-256 `b6c6333d376416dbab454b212c1d17c5d114e01ea340afc4423d198e74242050`. The original PNG and provenance metadata are retained. A requested 3840 x 2160 output was not returned, so this asset is not described as native 4K. There was no paid asset purchase, copied character image, downloaded image pack, or subsequent fake upscaling.

This is an AI-assisted project image, not a claim of human painting. It contains no baked UI lettering; live translated Godot controls form a separate layer. Its fixed depicted robot is separate from the current-loadout summary and procedural cosmetic previews. [The image README](assets/images/README.md) permanently preserves the source, prompt, checksum and rendering notes. This image is covered by the project's MIT LICENSE to the extent the creator holds the relevant rights; no exclusive rights in AI-generated output are asserted.

主菜单使用按项目原创提示词生成的AI辅助机库原图，真实尺寸、校验值和生成记录已随源码保留。文字交互由Godot控件提供，未烘焙进图片；原图等比显示，不把请求分辨率或放大后的窗口尺寸写成原图尺寸。

## Development-method reference / 开发方法参考

Claude Code Game Studios, local revision `984023ddac0d5e27624f2baacde6105e45de375f`,
was consulted for role division, design validation, audio planning and provenance
workflows. No template prose, agent configuration, hook or runtime code from that
repository was copied into this game. Its MIT license does not determine the
license of this project's original code or assets. Any future incorporation of
its software must retain the applicable upstream copyright and license.

## Distribution inventory / 分发清单

See [the asset register](docs/ASSET_REGISTER.csv) for actual files and
[the art plan](docs/ART_AND_ASSETS.md) for researched candidates. Godot engine
notices and other dependencies must match the actual exported packages; engine
binaries are development tooling and must not be added to source control.
