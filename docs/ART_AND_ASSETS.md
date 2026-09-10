# SCRAPSTORM: NIGHT SHIFT · 美术、声音与素材

更新：2026-09-07，v0.5无尽加班与主机库升级。免费作品集、默认英语且可选简体中文；当前使用AI辅助生成的原创主菜单机库原图、程序战斗与预览视觉、SVG图标、22个短音效、三首原创分层BGM，以及官方免费Noto和Rajdhani字体，无付费采购。

## 制作与来源

Codex负责检索、制作、整理、接入及来源记录，创作者给出风格与试听反馈。优先许可清楚的免费资源与自行绘制/程序生成/AI辅助制作。候选未实际下载接入前不列作已使用；免费作品集不自动赋予外部素材任意分发许可。

程序视觉源为`scripts/ui/launch_hangar.gd`、`archive_panel.gd`、`overtime_panel.gd`、`scripts/ui/main.gd`、`mission_panel.gd`、`garage_panel.gd`、`shop_panel.gd`、`scripts/game/game_world.gd`、`standard_director.gd`、`standard_boss.gd`和`player_ability.gd`、`mechanical_encounters.gd`、`evolution_effects.gd`、`combat_feedback.gd`、`arena_detail.gd`；机库与技能预览由`scripts/ui/hangar_visual.gd`、`skill_preview.gd`提供；图标源为`assets/icon.svg`。这是Codex辅助完成的项目原创，不冒称下载图包或人类画师作品。公开复用许可待创作者发布前选定。

## 当前视觉

| 内容 | 实现 |
| --- | --- |
| 三图 | yard深蓝灰与暖金、foundry暖锈与橙、reactor冷蓝与霓虹；独立障碍/机械/危险区，传送带和电网实际参与玩法 |
| 玩家 | 机库分体履带、面罩/天线、清扫盘与能量外挂；工业黄/极地勤务/危险作业组，以及成就奖励cobalt/aurora共五外观；朝向/回收/蓄能/受击反馈，皮肤不改碰撞与属性 |
| 敌人与首领 | 三类普通敌人的各图变体，新增特色精英及护盾/熔渣/抢料表现；三首领破招目标、冲撞/热区/环弹预警对应实际玩法 |
| 武器与技能 | 八工具的独立代码图形（含棱光切割器、追猎导弹、轨道无人机、回响地雷）；分层脉冲、随身护盾/回声；准星黑洞真实聚怪/追加爆破；过载侧翼电弧/机动轨迹；碎钢风暴/导电网/压缩井有各自功能图形 |
| UI | 原创机库原图与真实双语控件；无尽主入口、标准、快速、工坊、档案、成就、设置、存档继续；选区→整备；工坊等比履带机体与技能演示；标准三槽/无尽四槽商店、工具比较和35耐久维修；原创成就勋章/奖励预览 |

敌方危险保持红橙语义，形状和动画辅助区分；玩家换色不重染敌方预警。减弱特效去装饰闪光、碎片和世界晃动，保留作用范围、落点与危险提示。短击停、圈、碎片、残影和后坐有时间/数量上限，HUD不随世界震动。配色为#101c24/#334751/#ede3ce/#ffc04d/#58d9e7/#f07842。逻辑画布1280×720。v0.5主菜单已检查1280×720、1920×1080、960×540和2554×1513窗口的中英原生截图；独立组件保持完整窗口尺寸，真实主场景在2554×1513窗口使用keep-aspect，渲染区为2554×1436，截图不包含外部留黑。图像和控件均等比缩放，文字使用独立MSDF字体实例；这属于布局验证，不等同导出包或性能验收。证据口径见[构建报告](BUILD_REPORT.md)。

## v0.5 主菜单原图与新增几何

`assets/images/hangar-keyart-v05.png`由OpenAI内置`image_gen`工具按本项目原创提示词生成，日期2026-09-07。实际PNG为**1672×941**、2,056,211字节，SHA-256为`b6c6333d376416dbab454b212c1d17c5d114e01ea340afc4423d198e74242050`。提示词曾请求3840×2160，工具实际返回较小尺寸，因此不称作原生4K；未伪上采样或改绘像素，保留原PNG与来源元数据。长期来源、完整提示词和展示方式位于[`assets/images/README.md`](../assets/images/README.md)，不依赖被忽略的本地artifacts目录。

原图描绘宽履带清扫机、维修臂、金属磨损、烟尘与暖灯，左侧留出安静背景。图片内没有烘焙菜单文字；`launch_hangar.gd`以等比cover绘图，独立等比控件层提供全部交互与翻译。主视觉是固定机体插画，当前装备由实时文字和技能图标单独显示，不把固定原图当作实际皮肤预览。少量尘点动画可随减弱特效设置关闭。

`hangar_visual.gd`和`skill_preview.gd`共享等比场景变换，预览机体改为低矮装甲和宽履带。成就皮肤cobalt（主色#295f94、亮边#74e7ff）与aurora（主色#205b59、薄荷#8af0bf、紫#bb91ff），以及ember #ff8c4b/prism #f6a9ef技能颜色，均为代码原生配色，不是额外下载贴图。`archive_panel.gd`的勋章与奖励图形为原创Godot几何，称号使用真实文字；`shop_panel.gd`的八工具和维修图标同样由代码绘制。公开复用许可仍待创作者选定，不将AI辅助资源冒称为纯人工作画。

## 普通敌人图集与性能

`assets/sprites/enemy_atlas.png`由原有原创几何在Godot中烘焙：三图×三种普通机体，共九种；每种四帧动画＋四帧受击，总72个80×80图块，组成640×720 RGBA图集。源为`tools/bake_enemy_sprites.gd`和world绘制函数；`enemy_atlas.gd`在运行时选帧/旋转，几何源和fallback保留，方便重建和调试。没有下载第三方图包或付费服务，图集原图已实际查看。

危险预警、血条、精英和首领继续实时绘制。`arena_detail.gd`新增原创钢板地面、边界管线和工作灯，避免地板装饰误认成危险区域。图集减少普通机体逐帧复杂几何绘制，性能数字来自本轮真实渲染夹具，具体环境、尖峰与限制见[BUILD_REPORT](BUILD_REPORT.md)；不承诺所有设备无卡顿。

## 三首地图音乐

| 地图 / 曲名 | 风格与配器 | BPM / 循环 |
| --- | --- | --- |
| yard / Afterhours Salvage | D小调工业breakbeat、切分鼓、FM铃音旋律、金属打击、拨弦低音 | 112 / 68.5714秒 |
| foundry / Pressure Circuit | 升F小调机械techno、四拍底鼓、反拍脉冲低音、应答主旋律、机械打击 | 128 / 60秒 |
| reactor / Neon Induction | C小调synthwave/electro、立体声和弦垫、上行音区旋律、琶音与切分鼓 | 104 / 73.8462秒 |

各曲32小节，四个8小节段落（主题、推进、稀疏段、末段抬升），有和声、旋律问答、音区和节奏变化。每图三个同步层`bed/rhythm/boss`，共9个32kHz立体声Ogg，合计约5MiB；延迟和尾音跨循环接点回绕。

菜单/结算使用较轻旋律层，商店低强度节奏，暂停淡出打击，首领叠加紧张层；换图1.5秒交叉淡化，最多6个音乐玩家。独立主音量/音乐/音效；切设置或购买不会每帧重启音乐。

源`tools/generate_music.py`使用免费Python/NumPy/SciPy/SoundFile合成与编码。实际交付文件的哈希、帧数、段落、峰值与RMS在`assets/audio/music/manifest.json`。无第三方录音、下载旋律、付费生成服务或预训练音频模型。制作与编曲记录为OpenAI Codex辅助，不声称人类作曲/演奏。RMS不是LUFS或主观响度结论。

## 音效与混音

`tools/generate_audio.py`使用Python标准库振荡器、包络和确定性噪声，生成22个22,050Hz/16位/单声道WAV。v0.3原14项为ui/start/collect/blast/hit/dash/enemy_down/win/lose/foam/arc/warning/boss_charge/unlock；v0.4新增skill_pulse、skill_singularity、skill_overdrive、singularity_burst、skill_ready、boss_break、evolve、install，分别为脉冲、引力吸入、电机爬升、塌缩、就绪、破甲、进化和装配。旧种子17000—17013和14个WAV字节不变；新增使用17014—17021，9层音乐也不改。实际WAV哈希/长度/峰值/RMS在`assets/audio/sfx_manifest.json`。

最多8个SFX声部，自动工具限频且只占空闲声部。满池时重要事件优先替换低优先级声，技能/进化/装配不抢正在播的warning/boss_charge。回收/击杀和自动工具用少量音高变化，关键技能和危险提示固定音色；表现随机不影响玩法RNG。Web需要实际按键或点击启声，headless资源/状态检查不称为听测。

`tools/validate_audio.py`170项实际文件检查（112 WAV＋58 Ogg）、`tests/test_audio.gd`69项runtime/声部分配检查通过。音效有非空、无削波、短起尾和格式/哈希检测；音乐检查循环/段落/地图差异；短音效有限窗口均值仅记录。试听副本在`artifacts/audio-preview`，不打包。完整说明见[`assets/audio/README.md`](../assets/audio/README.md)，实际听感仍由创作者确认。

## 台账、许可与外部参考

[ASSET_REGISTER.csv](ASSET_REGISTER.csv)登记40项：2字体、22音效、9音乐层、1图标、1敌人图集、1张主菜单原图与4组程序视觉。新增绘制模块归入对应视觉组并登记实际源文件；项目原创标明public reuse license pending，不替用户选择MIT。

Noto Sans CJK SC Regular 2.004来自官方仓库，Rajdhani Bold来自Google Fonts官方仓库，均免费采用SIL OFL 1.1，原始字体文件不改写。现有Godot FontVariation只在运行时适度加粗；v0.5主菜单复制FontFile资源并开启MSDF生成字形缓存，保持大窗口文字清晰，不修改OTF/TTF、不生成改名字体。完整许可、来源和实际校验值位于`assets/fonts/OFL.txt`、`assets/fonts/Rajdhani-OFL.txt`、`assets/fonts/README.md`。构建脚本分别复制为`FONT-LICENSE.txt`和`RAJDHANI-LICENSE.txt`。Godot 4.7.2 MIT和组件声明随导出，见[第三方声明](../THIRD_PARTY_NOTICES.md)。

用户提供的Claude Code Game Studios只借鉴设计验证、音频规划、分工和素材登记方法，没有复制其配置、模板或运行时代码。其MIT许可不并入本项目原创许可，完整评估在[标准计划](STANDARD_NIGHT_SHIFT_PLAN.md)。

此前查阅的Kenney Top-down Shooter、UI Pack、Interface Sounds仍为免费资源候选，没有下载或用于本轮。后续若引入，先核实具体资源包条款、保留证据再登记；本轮不把候选写成已用素材。
