# v0.3.0 构建与验证记录

日期：2026-09-07（北京时间）。当前三图标准夜班、商店/战斗修正、金币工坊、主动技能、保存与音频已经接入。创作者对旧版的反馈是首领过易、声音单调；**新版本真人难度与听感尚待验收**。[v0.2历史](BUILD_REPORT_v0.2.0.md)与[v0.1历史](BUILD_REPORT_v0.1.0.md)不作为新导出的通过证据。

## 实现与产物

- NIGHT SHIFT提供yard/foundry/reactor，每图独立场地、敌人变体、首领和音乐；5普通阶段共870战斗秒，实际击杀首领才胜利。
- QUICK SWEEP保留180秒短局。OVERTIME、CONTRACTS为后续方向，不显示不可玩的入口。
- 四工具三槽、六改装三级、数值对照、独立图标、一次付费刷新；标准店价乘2.8后向上取整。
- 局外金币、两款额外皮肤/配色/蓝图、结算反馈、主备校验存档、最近256个run ID结算去重、商店检查点及RNG/已售/刷新恢复。
- 英文默认、中文保存、引导与改键、吸附切换、独立音量；三首32小节四段自制BGM、九层Ogg和14个短音效。
- Godot `4.7.2.stable.official.ed1daf0bf`，Windows x64与单线程Web匹配模板；Windows产物`exports/windows/Scrapstorm.exe`和相邻`.pck`，Web产物`exports/web/index.html`及配套文件。
- 商店没有时限，也不记录耗时；所有时间证据均为战斗时间或测试执行时间。

## 当前自动回归

| 检查 | 数量 | 脚本与主要范围 |
| --- | --- | --- |
| 核心规则 | 25 | `scripts/game/test_world.gd`：移动/掉落/终态/压力兼容 |
| App | 22 | `tests/test_app.gd`：菜单/偏好/暂停/重开 |
| 旧Demo世界兼容 | 43 | `tests/test_demo_world.gd`：55秒兼容波次和基础战斗 |
| 旧Demo App兼容 | 39 | `tests/test_demo_app.gd`：商店转场与结果 |
| Loadout与商店 | 90 | `tests/test_loadout.gd`：四工具三槽、候选、前后数值、报价、原子购买/刷新、RNG存档 |
| 三图标准世界 | 68 | `tests/test_standard_world.gd`：地图机制、首领、预警路径、遮挡、喷射与检查点 |
| 局外进度 | 28 | `tests/test_profile.gd`：金币、购买、首通、去重、主备保存与错误回滚 |
| 主动技能 | 53 | `tests/test_abilities.gd`：能耗/冷却、暂停门控、遮挡、效果、外观和恢复 |
| Godot音频 | 38 | `tests/test_audio.gd`：资源/循环、声部上限、手势启声、场景混音与清理 |
| 标准App | 39 | `tests/test_standard_app.gd`：三图、引导、设置、商店保存/恢复、工坊和结算 |
| 独立发布审查 | 39 | `tests/review_standard_release.gd`：三首领预警与缺口、技能/碰撞、高密度有界检查 |
| **Godot合计** | **484通过** | `artifacts/v03-regression-summary.json`，各`artifacts/v03-test_*.log`；均退出0且无错误文本 |
| 导出Web普通交互 | **40通过** | `tools/smoke_standard.cjs`、`artifacts/standard-web-smoke.json`；另计 |
| 最终Web提前收班补验 | **25通过** | 同脚本`--retreat-only`，`artifacts/standard-web-retreat-smoke.json`；两组Web合计65项 |
| 独立音频文件 | **58通过** | `tools/validate_audio.py`、`artifacts/audio-validation.json`；另计，不与38项runtime重复称为同一组 |

音频文件检查实际解码交付的Ogg，校验哈希、帧数、循环接点、峰值、DC、声道、段落变化与各图差异。RMS值不是LUFS，不证明扬声器听感。headless音频测试不启动dummy播放线程。

## 正常输入AI三图证据

`tests/probe_standard_world.gd`用固定60Hz逻辑更新、可见敌人/危险观测和普通输入启发式游玩，商店使用正常购买和付费刷新；没有加生命、加钱、直接伤害或跳过战斗时间，没有渲染。商店不记录耗时。

| 地图 / 策略 / seed | 结果 | 战斗秒 | 剩余生命 | 期末钱包 |
| --- | --- | --- | --- | --- |
| yard / combo / 8102 | 胜利 | 920.88 | 87.6 | 134 |
| foundry / combo / 8102 | 胜利 | 912.88 | 87.0 | 42 |
| reactor / combo / 8102 | 胜利 | 907.07 | 40.0 | 116 |

最终首领安全缺口修正后的三图获胜数据来自 **`artifacts/standard-probe-release.log`及当前`artifacts/standard-balance-probe.json`**。废钢锯策略三局失败完整保存在`artifacts/standard-balance-probe-saw-history-20260907.json`与`standard-probe-saw.log`，不能把另一策略的成功混进它们。此前`standard-probe-final.log`是修正前报告，不再作为最终反应堆时间数据。

最终三首领战分别50.87/42.87/37.05秒，对应1/1/5次正向净掉血事件。它们说明新招式会命中该AI，但不能证明创作者已经认可难度，也不能给出所有玩家的首领胜率。

AI调整过避开地图危险区的策略：即使短距离候选全在危险区，也按逃到安全边界的代价选择方向。探针策略版本与数值调整应分开记录。142.4/87.0/540.0的三图正向净掉血累计可能被同tick维修抵消，不等于精确原始受伤总量。当前结果说明存在可胜路径和约15分钟战斗样本，不代表真人局长分布、首领难度认可或高帧率。

## 长局与画面

`tests/stress_standard_world.gd`每图在首领场景无渲染运行10分钟、36,000tick，夹具给玩家无敌和扩大首领血量以维持运行。`artifacts/standard-stress.json`记录均有界，平均逻辑耗时yard约0.135ms、foundry约0.137ms、reactor约0.148ms/tick。

该场景峰值仅4—5个敌人、13—46弹体，**属于低密度持续运行检查**；不能写成高密度压力、GPU帧率、最低配置或无尽验收。另行补充高密度夹具如下，真实GPU帧时间仍待测。

独立`tests/review_standard_release.gd`补测每图30秒/1,800tick高密度：持续100敌人、峰值70弹体/150掉落/240粒子/18危险区。Intel Core Ultra 9 275HX上yard/foundry/reactor逻辑P95为1.154/1.144/1.307ms，最大tick 2.460ms；记录在`artifacts/standard-release-review.json`，39项通过。夹具人为无敌并维持高生命和上限对象，属于无渲染CPU压力，不等同于整局游玩或GPU FPS。

独立审查发现反应堆二阶段环弹缺口会偏离静态预警，已经改为与预警保持一致；相关回归、最终三图正常输入探针已重跑。主动放弃单独显示“提前收班”，不再显示报废或最后受击原因；标准App39项覆盖该区别。测试设置使用含PID的临时路径，避免不同验证进程互相污染偏好。

`tests/capture_standard_app.gd`最终已在原生图形界面重新生成并查看14张截图：菜单、地图选择、工坊、设置、战斗、首领、结果各EN/ZH一张，`artifacts/capture-standard-app.log`无errors。首局引导可见，HUD/结果末轮修改已包含；商店另由Loadout渲染夹具与Web截图验证。夹具准备状态，不是正常通关。

## 导出Web普通交互

Microsoft Edge/Chromium、1280×720、普通鼠标键盘＋只读诊断，`tools/smoke_standard.cjs`共40项通过，`artifacts/standard-web-smoke.json`记录24张截图和0页面JS/控制台/网络/HTTP错误。覆盖新档英文、中文持久化、三图入口、真实暂停与blur/focus、普通第一阶段、购买/刷新、商店退出/刷新/继续、第二阶段入口、主动放弃与金币去重、工坊状态。

普通输入yard在120.0167战斗秒进入商店，钱包132；买电弧62后70，刷新34后36。中英设置、保存返回、页面刷新和续玩保留装备/候选/已售/刷新状态。第二阶段主动放弃结算18金币，刷新页面后不重复发奖。初次脚本等待超时保留在`previous_attempts`，未隐藏失败。

这条Web证据不含三图完整15—20分钟通关、所有工坊商品购买或主观听测。音频只观察手势解锁与混音路由；SwiftShader软件渲染不用于硬件帧率结论。完整流程脚本在末轮文字与首领缺口修正前运行；最终导出随后追加25项普通输入提前收班补验，三图依次EN/ZH/EN，标题正确、存活主动退出不显示报废/受击原因、刷新后金币仍0且不重复结算，0页面/控制台/网络/HTTP错误。证据`artifacts/standard-web-retreat-smoke.json`，同脚本`--retreat-only`。两组Web共65项；首领缺口由随后Godot回归/正常输入探针验证，不称为完整最终Web首领验收。

## 最终平台交付状态

| 项目 | 当前证据 / 待完成项 |
| --- | --- |
| v0.3 Windows/Web首次导出 | `artifacts/build-v03-all.log`已成功 |
| 最后修改后的双端导出 | 已成功：`artifacts/build-v03-final-all.log`，含Windows文件版本与最终UI/首领修正 |
| Windows最终包启动 | 最终导出与ZIP独立解压版均实际运行；文件版本0.3.0.0，新档英文菜单，RTX 5080 Laptop GPU / OpenGL 3.3 Compatibility，无ERROR/WARNING |
| Windows ZIP | `artifacts/Scrapstorm-Night-Shift-v0.3.0-Windows.zip`，61,824,812字节，6项文件解压哈希全匹配；最新NOTICE已附带 |
| v0.3导出Web真实输入 | 40流程＋25最终提前收班补验，共65项，均0页面/控制台/网络/HTTP错误；范围如上 |
| 最终界面截图 | 14张英中原生实际渲染已重拍并查看，未见溢出，含首局引导 |

Windows包证据：`artifacts/windows-release-v03.json`、`artifacts/windows-zip-launch.log`、`captures/windows-zip-v03.png`。ZIP SHA-256：`5D3261603C70823A299E42DDF82741D91606C2DD6909C7284573E8CE32B980AF`。独立包验证证明新档启动、资源与画面正常，不将其称为Windows真人完整三图通关。

## 真人与公开发布边界

三张地图完整体验、首领强度、五阶段节奏、构筑选择、金币节奏和音乐喜好尚待创作者试玩。Firefox、多分辨率、真实GPU P95、连续重开与更多目标设备需要补测。自动断言、AI样本和截图各自证明有限范围。

本地工程尚未推送GitHub；公开作者名、源码/原创资源许可与发布时机未定。字体OFL和Godot MIT/组件声明独立附带。测试命令见[TEST_PLAN](TEST_PLAN.md)，当前玩法见[GAME_BRIEF](GAME_BRIEF.md)。
