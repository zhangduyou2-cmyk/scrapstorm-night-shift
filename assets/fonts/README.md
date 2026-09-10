# Included fonts / 随附字体

## Noto Sans CJK SC Regular

Used for English and Simplified Chinese UI text. The original font is included
unchanged under the SIL Open Font License 1.1; see [OFL.txt](OFL.txt).

- Original font copyright (embedded name table): © 2014-2021 Adobe (http://www.adobe.com/).
- Font version: 2.004.
- Download date: 2026-09-07.
- Official repository: https://github.com/notofonts/noto-cjk
- Pinned upstream revision: `f8d157532fbfaeda587e826d4cd5b21a49186f7c`.
- Font source: https://github.com/notofonts/noto-cjk/blob/f8d157532fbfaeda587e826d4cd5b21a49186f7c/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf
- License source: https://github.com/notofonts/noto-cjk/blob/f8d157532fbfaeda587e826d4cd5b21a49186f7c/Sans/LICENSE
- File size: 16,437,364 bytes (15.68 MiB).
- SHA-256: `2c76254f6fc379fddfce0a7e84fb5385bb135d3e399294f6eeb6680d0365b74b`.

Keep this copyright notice and the full OFL text with distributed game packages.
The font retains its own license regardless of the project's source-code license.

## Rajdhani Bold

Used for the v0.5 SCRAPSTORM wordmark and Latin main-menu headings/buttons. Chinese and body text continue to use Noto Sans CJK. The downloaded TTF is unchanged.

- File: `Rajdhani-Bold.ttf`.
- Copyright: Copyright (c) 2014, Indian Type Foundry (info@indiantypefoundry.com).
- Download date: 2026-09-07.
- Official repository: https://github.com/google/fonts/tree/main/ofl/rajdhani
- Download source: https://raw.githubusercontent.com/google/fonts/main/ofl/rajdhani/Rajdhani-Bold.ttf
- License: SIL Open Font License 1.1; full text in [Rajdhani-OFL.txt](Rajdhani-OFL.txt).
- License source: https://raw.githubusercontent.com/google/fonts/main/ofl/rajdhani/OFL.txt
- Font size: 400,680 bytes.
- Font SHA-256: `691470dd3286a14e9677940d0bf75796179841ba5215cbda1a2c8910a3226afd`.
- License size: 4,373 bytes.
- License SHA-256: `f62ef357d3a1c3d27edd35a6e1ba350e8a8d13499797964eeadefbf0b3b15d1f`.

The upstream URL uses the repository's main branch; the hashes above identify the exact included bytes. No font purchase or paid service was used. Keep the original copyright and complete OFL text with the font. The build script copies this license to `RAJDHANI-LICENSE.txt`, alongside Noto's separate `FONT-LICENSE.txt`, in Windows and Web distributions.

## Runtime rendering / 运行时渲染

`launch_hangar.gd` duplicates each FontFile resource and enables multi-channel signed distance field (MSDF) rendering with `msdf_size = 64`. This creates Godot glyph/cache data for crisp uniform scaling; it does not edit either original TTF/OTF, rename a font, or create a modified font file. The shared gameplay font import remains unchanged. Existing FontVariation UI emboldening is also applied only at runtime.

主菜单通过代码原生的独立MSDF字形缓存改善大窗口文字清晰度，未修改原始字体文件。第三方字体许可不随项目原创代码许可改变。
