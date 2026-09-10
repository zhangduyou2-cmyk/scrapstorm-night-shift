# v0.5.0 OVERTIME 构建与验证记录

日期：2026-09-07（北京时间）。**v0.5.0 已完成本地 Windows / Web 交付**：新机库主菜单、无尽模式、八工具/六进化、首领支援与投影、战斗档案和16成就已实际接入。23 套 Godot 回归 1,246 项通过；最终原EXE/解压EXE启动、最终Web普通输入流程另行验证。尚未公开GitHub或Release。[v0.4报告](BUILD_REPORT_v0.4.0.md)与[v0.3报告](BUILD_REPORT_v0.3.0.md)保留历史，不作为本轮通过数据。

## 本轮交付行为

- 主界面以原创AI辅助生成维修机库原画、Rajdhani标题字体和真实双语控件重做；背景裁切与UI等比缩放分别处理，工坊机器人也改为宽履带轮廓。原画真实分辨率1672×941，不能称原生4K。
- OVERTIME作为主入口：四工具槽、三图轮换、四种普通房间目标，每三房首领；每房商店和三选一路线，将八种局内增益与六种下一房风险配对。首领后可撤离结算，或保存后继续。
- 难度包含血量/速度/伤害/弹速、冲锋手和精英、炮击/横向危险带/死亡爆区、目标变化与构筑取舍；风险有预警。对象池和若干速度/伤害系数有上限，避免只靠无限堆怪。
- 新激光、导弹、无人机、地雷加入旧刷盘/泡沫/电弧/锯片，新增棱镜联动、猎群和连锁军械三进化。有空工具槽时每家新商店保证一张未装备工具；仍不保证抽到指定武器。
- 首领有真实掉落/充能的增援与上限；冲撞先跟踪预判再锁定长路径，提交后不拐弯。反应堆新增可打掉且只掉落一次的投影；原有破招窗口保留。
- 保存最近100局历史与终身统计；16成就包含标准全程/首领无伤、无尽深度/撤离、地图与构筑追求。奖励为金币、原创奖章、两套涂装、两种技能色和四称号，不增加无限永久战斗属性。
- v1/v2局外存档迁移到v3，旧检查点兼容；缺少受伤指标的旧局不能补领无伤。商店时间不采集、不计入成绩、奖励或技能充能。桌面和浏览器各自本地保存。

玩法细节见[范围](V05_OVERTIME_PLAN.md)、[玩法](GAME_BRIEF.md)、[档案](V05_BATTLE_ARCHIVE_AND_ACHIEVEMENTS.md)。以下区分行为夹具、普通输入、真实渲染与分发包。

## 最终统一行为回归

命令：`python tools/run_tests.py --label v05-release-final`。Godot4.7.2 headless、独立测试设置/档案；每套退出0且无失败断言、SCRIPT ERROR、ERROR或资源泄漏报告。汇总 `artifacts/v05-release-final-regressions.json`，逐套日志与检查数如下。

| 套件 | 通过数 |
| --- | ---: |
| `scripts/game/test_world.gd` | 25 |
| `tests/test_app.gd` | 22 |
| `tests/test_demo_app.gd` | 39 |
| `tests/test_demo_world.gd` | 43 |
| `tests/test_standard_app.gd` | 43 |
| `tests/test_standard_world.gd` | 68 |
| `tests/review_standard_release.gd` | 36 |
| `tests/test_abilities.gd` | 101 |
| `tests/test_loadout.gd` | 114 |
| `tests/test_profile.gd` | 79 |
| `tests/test_profile_v05.gd` | 77 |
| `tests/test_audio.gd` | 69 |
| `tests/test_hangar_ui.gd` | 28 |
| `tests/test_v04_mechanics.gd` | 53 |
| `tests/test_v04_integration.gd` | 49 |
| `tests/test_v05_hangar.gd` | 43 |
| `tests/test_v05_shop.gd` | 28 |
| `tests/test_v05_arsenal.gd` | 36 |
| `tests/test_v05_boss_support.gd` | 34 |
| `tests/test_archive_ui.gd` | 32 |
| `tests/test_overtime.gd` | 153 |
| `tests/test_overtime_app.gd` | 51 |
| `tests/test_overtime_review.gd` | 23 |
| **合计** | **1,246** |

这批在最终生产代码修复后完整运行。最后修复包括：精英创建入口统一初始化；同帧玩家死亡/首领死亡仍记录已击败首领和房间，但保持失败、不进店、不回血；回收回血不复活死亡玩家；技能施放当帧即给护盾，下一帧不重复授予。23项专项审查验证八增益的实际效果及保存后不叠乘。后续仅导出元数据、测试夹具、脚本和文档修改；没有改变游戏逻辑。

无尽153项及主应用51项包括九房/三图、路线和RNG稳定、商店不计时/不充能、实际磁盘保存重启、重复结算、替换存档、提取及同帧死亡。这里有加速房间时间、直接准备首领终态的状态夹具，**不代表普通输入九房通关**。早期失败记录保留在 artifacts 中。

音频运行时69项已包含在总数内；另运行 `tools/validate_audio.py`，独立文件/波形检查170项（112 WAV + 58 Ogg）通过，日志 `artifacts/v05-audio-validation.log` 与 `artifacts/audio-validation.json`。三首32小节分层曲与22音效保持；这些检查不能代替听感评价。

## 画面与界面验证

`tests/test_v05_hangar.gd`、`test_v05_shop.gd`、`test_archive_ui.gd`、`test_overtime_app.gd`原生截图，以及 `capture_v05_launch_integration.gd`实际main场景截图，覆盖英文/中文、1280×720、1920×1080、960×540及2554×1513请求窗口、整备/工坊/路线/结果/档案/奖励预览。共43张UI夹具图片保存在 `captures/v05/`，已检查显示；相同的行为断言不再重复累加到总数。

实际main使用canvas_items/keep；2554×1513请求窗口内的画布为2554×1436，留黑边而不压扁；独立机库布局夹具另外覆盖完整2554×1513。界面截图是布局/信号夹具，战斗与解锁状态可能预先准备，不是普通输入取得的奖励。

证据：`artifacts/v05-main-visual-validation.json`、`v05-visual-assets.json`、`v05-archive-validation.json`、`v05-overtime-app-validation.json`及原生日志。某些专项测试会在后续headless运行时刷新同名汇总中的截图列表；原生截图文件和单独视觉证据保留。素材台账40个唯一条目均核对来源/路径；原画与字体的来源、实测尺寸和哈希见[美术文档](ART_AND_ASSETS.md)、[原画记录](../assets/images/README.md)、[第三方声明](../THIRD_PARTY_NOTICES.md)。

## 普通输入战斗探针

`artifacts/v05-combat-evidence.json`索引最终与历史报告。固定60Hz普通移动、瞄准、吸附、技能及正常购买/付费刷新；不加钱、加血、直接伤害、删除目标或跳过战斗时间，没有记录商店耗时。测试策略可读取敌人与预警位置，不等于真人反应。

最终新工具发现规则下，标准foundry两个seed结果为：8102首领187.17秒后失败（未买到目标无人机）；8103以刷盘/无人机/泡沫完成首领92.35秒，剩余85.6生命、9次破招、18支援怪。`v05-arsenal-probe-final.json`只含这两局；更早六局明确留作旧规则基线。构筑差异不是单变量因果实验。

最终三局无尽探针：yard在第3房失败，首领104.83秒、5次破招、25增援；reactor第3房失败，首领69.48秒、2次破招、16增援、打掉4投影；foundry通过首个首领及第4/5房，在第6房reactor首领失败。**该策略没有完成六房撤离**。完整指标见 `v05-overtime-probe-final.json`。这些事实说明有实际压力、支援和反制行为，不说明玩家胜率、所有武器平衡或难度已获认可。

探针的源哈希早于最终“施放当帧护盾”修复；普通战斗样本不能写成最终包完整长局测试。该修复由最终统一回归、23项增益专项及最终包流程覆盖。早期无效typed-array策略和精英初始化报错报告单独留存并排除通过数据；失败样本未删除。

## 最终原生渲染压力

`artifacts/v05-render-release-final-v2.json`、同名日志记录三图×Overdrive，逐段至少600帧、1秒预热，真实 `frame_post_draw` 间隔；源哈希随报告保存。1280×720原生Compatibility，Intel Core Ultra9 275HX / RTX5080 Laptop，关闭VSync与FPS上限，屏外窗口。包含CPU、提交、驱动和调度，不能推算独立GPU耗时或显示器呈现率。

| 地图 | 平均FPS | 帧间隔P95 | 最大帧间隔 | 帧数 |
| --- | ---: | ---: | ---: | ---: |
| yard | 52.69 | 29.731 ms | 205.669 ms | 600 |
| foundry | 57.67 | 28.116 ms | 32.115 ms | 600 |
| reactor | 65.11 | 20.306 ms | 34.298 ms | 600 |

压力准备了100敌人、70弹体、150掉落、18危险区、240粒子、高血首领、八种三级工具与满增益，玩家无敌；这是**超过合法四槽的合成负载**，不接完整菜单/HUD/音频外壳，不作为正常游玩配置或低配承诺。三段所有池有界；新军械上限为12导弹/12地雷/20光束/16爆炸。具体峰值和原始逐帧数据在报告内。仍有长帧，不能宣称全程稳定60FPS。

第一次最终渲染夹具在两图后停止推进，已明确终止并保留 `v05-render-release-final-hung-partial.log`，该次没有完整通过结论；补充循环改为有限次数/进度检查、逐阶段持久化后重新跑完整矩阵。此夹具问题的根因与最终结果以报告中的定位记录为准，不冒称已证实为游戏生产逻辑缺陷。

## 最终分发包与浏览器

Windows目录 `exports/windows-v0.5.0/`，Web目录 `exports/web/`。`Play.cmd`指向新版；旧v0.4正在运行的窗口和文件保留，玩家先关闭旧窗口再启动新版。Godot与模板均4.7.2；最终Windows EXE的FileVersion/ProductVersion为0.5.0.0。构建日志 `artifacts/v05-final-export.log`、`v05-final-windows-export.log` 无引擎错误。最后一次Windows重导只修正EXE版本资源和描述，Web内容不变。

`tools/package_windows.py`生成 `artifacts/Scrapstorm-Night-Shift-v0.5.0-Windows.zip`，**62,542,692字节**，SHA-256：

`c26f61ce307925c09898f31d7e5607fb9ae52b3fc9564de9cf7842a0c73cc440`

`artifacts/windows-v0.5.0-package.json`记录七个文件哈希：EXE、PCK、项目声明、Noto与Rajdhani两份OFL、Godot许可及组件版权。CRC通过，独立解压的七个SHA全部匹配。`tools/verify_windows.ps1`在原导出和解压目录分别启动，没有源码`--path`，使用隔离设置；原包显示英文新主菜单，ZIP通过既有 `--smoke-start` 实际运行约4秒旧Demo兼容战斗（不能称为Quick/无尽实战）。两个PNG保存返回0且真实进程ExitCode都为0；两个测试进程退出。截图 `captures/v05/windows-export-final.png`、`windows-zip-final.png`实际查看，日志与包SHA见 `artifacts/v05-windows-native-validation.json`。

最终Windows/Web PCK相同，26,945,600字节，SHA-256：

`998321963d4e7bc7a2fe549f1ec28244ae7c3ac4846022ff68ed16ac3f82e8a8`

最终导出Web普通输入检查 **28/28通过**、13张截图，`artifacts/v05-web-smoke.json`保存实际HTTP获取与本地PCK一致性、浏览器环境、步骤和截图。使用全新独立Edge档案、真实键鼠与实际战斗时间，通过主菜单、默认英文/中文重载、档案/成就页、无尽第一房、商店买入、路线增益、保存→菜单→页面重载→继续、下一房、放弃结算→历史重载，以及标准/Quick入口。检查商店战斗时钟/充能冻结，保存后装备/钱包/商品/路线一致，历史金币不重复发放。页面/控制台/网络/HTTP错误为0。

浏览器只读取公开诊断位置来决定普通输入，未写入游戏/档案状态。早期输入策略有真实死亡，报告与截图逐次保留；修导航/吸附/技能策略不改变游戏难度。Web未跑完整首领通关和长局无尽，撤离由Godot专项状态夹具验证。SwiftShader/Headless浏览器帧率不能作为Windows原生性能证据。

## 交付边界

功能、保存迁移和分发包验证已完成；无尽耐玩性、长期经济、所有构筑及首领读招仍需要真人多轮反馈。未验证低配机器和所有浏览器。AI辅助美术/音频与代码贡献如实登记，没有购买付费素材或自动推送GitHub；公开作者与源码/原创资源许可可在发布前确定。
