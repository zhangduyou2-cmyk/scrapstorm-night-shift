# v0.4.0 构建与验证记录

日期：2026-09-07（北京时间）。**v0.4.0本地可玩版已导出Windows与Web**：霓虹工业机库、独立技能充能、分支/进化、首领反制、精英事件和进度迁移已经接入。14套Godot回归763项及170项独立音频文件检查通过；最终原EXE/ZIP已实际启动，导出Web59项流程与最终包17项补测均通过；版本边界见下文。尚未公开GitHub或Release。旧[v0.3报告](BUILD_REPORT_v0.3.0.md)保留历史，不作为本轮证据。

## 最终Godot回归

| 检查 | 通过数 | 范围 |
| --- | --- | --- |
| `scripts/game/test_world.gd` | 25 | 原型核心循环、实体与终态 |
| `tests/test_app.gd` | 22 | 应用菜单/偏好/暂停/重开 |
| `tests/test_demo_app.gd` | 39 | 旧Demo商店与结果兼容 |
| `tests/test_demo_world.gd` | 43 | 旧Demo世界与波次兼容 |
| `tests/test_standard_app.gd` | 43 | 标准入口、检查点/设置/结果、Quick装备外观字段传递 |
| `tests/test_standard_world.gd` | 68 | 三图场地、遮挡、阶段、首领和保存 |
| `tests/review_standard_release.gd` | 35 | 首领预警/缺口/路径等审查；此轮不运行其旧密度夹具 |
| `tests/test_abilities.gd` | 101 | 独立充能/来源限速、真实落点/牵引/工具加速、分支/暂停/旧状态恢复 |
| `tests/test_loadout.gd` | 112 | 数值、购买/刷新/拆卸原子性、门槛、token/RNG/checkpoint与UI数值对照 |
| `tests/test_profile.gd` | 79 | v1→v2迁移与返款一次、保留进度、目标/徽章/精通、坏档拒奖、去重和真实磁盘失败回滚 |
| `tests/test_audio.gd` | 69 | 22 WAV/9 Ogg、混音/手势/关闭、音色与饱和声部警告优先级 |
| `tests/test_hangar_ui.gd` | 28 | 无渲染机库/整备/工坊/商店行为断言 |
| `tests/test_v04_mechanics.gd` | 50 | 三图破招目标、特色精英/交互、阶段保存、精英已提交路径保护 |
| `tests/test_v04_integration.gd` | 49 | 三进化真实伤害/牵引/环绕转射出、清场/出售、55ms与反馈有界、HUD隔离、击停终态 |
| **合计** | **763** | 14套全部退出0，无失败断言/引擎错误 |

汇总为`artifacts/v04-final-regressions.json`。最后修复Quick仅更新技能内部外观、没有同步实际world机体/技能颜色字段的问题；此后三个受影响套件standard_app43/demo_app39/integration49重跑通过，其余模块未改。源码版本和最终包对应关系按下文产物记录。

机库原生另跑相同28条行为断言及12张截图保存，共40个检查；这里**不把重复28条再次累加**。`artifacts/hangar-ui-v04-validation.json`保留截图路径、UI源/fixture哈希、实际查看范围与限制。`artifacts/v04-integration.json`及`v04-test_integration.log`记录49项，装备/敌人是准备状态夹具，不代表正常输入养成或渲染性能。

独立`tools/validate_audio.py` **170项通过**（112 WAV＋58 Ogg），结果`artifacts/audio-validation.json`；`artifacts/v04-audio-preservation.json`确认旧14 WAV与9 Ogg共23文件SHA不变。新增8种音效和实际22 WAV全量manifest已登记；69项runtime计入Godot，170项文件检查另算。波形和资源检查不称为听感认可。

Profile审查修复了JSON浮点版本号被严格整数成员判断拒绝，以及迁移保存失败后内存提前兑现退款的问题。版本、免费技能和返款同一事务提交，失败恢复旧状态；真实JSON重启/备份和缺失目录/备份写入失败均有覆盖。

## 三图普通输入首领探针

`artifacts/v04-mechanics-probe-final.json`保留六局完整结果与来源。固定60Hz普通输入、seed8102、正常购买和付费刷新；没有加血、加钱、直接伤害、删除目标或跳过战斗时间。combo沿用旧移动/瞄准策略，counter另外根据可见压块、排气阀、供能节点和场地控件选择移动/吸附/喷射/技能。两者购买优先级相同，但回收和局面不同会改变最终装配，不能作为只有机制这一变量的严格消融实验。

| 地图 | 策略 | 胜败 | 战斗秒 | 首领秒 | 破招次数 | 剩余生命 |
| --- | --- | --- | --- | --- | --- | --- |
| yard | combo | 失败 | 1016.68 | 146.67 | 0 | 0.0 |
| yard | counter | 胜利 | 960.65 | 90.63 | 5 | 115.0 |
| foundry | combo | 胜利 | 1168.02 | 298.00 | 1 | 5.2 |
| foundry | counter | 胜利 | 996.67 | 126.65 | 11 | 72.2 |
| reactor | combo | 失败 | 996.98 | 126.97 | 0 | 0.0 |
| reactor | counter | 胜利 | 951.72 | 81.70 | 3 | 83.6 |

当前数据汇总yard/reactor的校准六局记录与foundry最终两局记录；铸造厂最后调整为交替阀、5600生命和中距离冲撞后独立重跑，并非六局来自同一次执行。来源字段保留原报告，失败样本不丢弃。首领配置生命为yard4200、foundry5600、reactor2600。

旧策略在yard/reactor失败，foundry298秒首领战后以5.2生命获胜且偶然破招一次；主动反制策略三图获胜。它们说明该启发式下存在可读的获胜路径与反制收益，**不代表真人胜率、难度已经认可或所有技能/构筑都平衡**。净掉血事件可能与同tick维修相抵，不等于精确原始受伤总量；探针没有渲染、没有记录商店耗时。

## 本轮真实渲染与图集优化

发现普通机体逐帧绘制较重后，将九种原创普通机体烘焙为72帧640×720 RGBA图集。原始几何/fallback保留，碰撞和伤害不改；预警、血条、精英与首领继续动态绘制。图集原图已经实际查看，源`tools/bake_enemy_sprites.gd`，登记为原创素材第37项；无新增外部资源。

同一yard/pulse压力配置的约21秒采样对比，数据分别为`artifacts/v04-render-baseline-profile.json`与`artifacts/v04-render-optimized-yard.json`：

| 检查 | 平均FPS | 帧间隔P95 | 最大帧间隔 | 采样帧数 |
| --- | --- | --- | --- | --- |
| 原逐帧机体几何 | 28.63 | 67.064ms | 264.479ms | 600 |
| 普通机体图集优化后 | 70.78 | 15.495ms | 182.903ms | 1487 |

这是Windows原生1280×720世界渲染，Intel Core Ultra9 275HX＋RTX5080 Laptop GPU，Godot4.7.2 Compatibility/OpenGL3，关闭VSync和FPS上限，窗口放在屏外。测量真实`frame_post_draw`间隔，包含CPU、提交、驱动和调度；不是独立GPU耗时或显示器呈现率。内置process/physics监控可能滞后且计账重叠，不能相减推算GPU时间。

夹具持续100敌人，峰值70弹体/18危险区/240粒子，补充掉落/危险和独立技能充能，玩家无敌并给敌人高生命；装备四种三级工具以同时覆盖三进化，超过正常三槽限制。维护夹具的开销算在内，未连接完整音频/菜单/HUD外壳。原始帧数据保留在JSON中，优化后还记录world源SHA；早期更慢的`v04-render-baseline.json`保留，不混为同一个基线。

该对照中的优化后最大帧间隔仍为182.903ms。随后完成最终三图×三技能九段矩阵，每段1秒预热后至少12秒且600帧，共7856帧、108.061秒；全部对象有界，数据和每帧原始间隔见`artifacts/v04-render-final.json`，含world/图集/测试源SHA。

| 地图 | 技能 | 平均FPS | 帧间隔P95 | 最大帧间隔 | 帧数 |
| --- | --- | --- | --- | --- | --- |
| yard | pulse | 65.77 | 16.247ms | 179.674ms | 790 |
| yard | overdrive | 75.05 | 15.003ms | 18.606ms | 901 |
| yard | singularity | 74.32 | 15.923ms | 35.077ms | 892 |
| foundry | pulse | 69.88 | 15.998ms | 18.180ms | 839 |
| foundry | overdrive | 66.58 | 17.517ms | 38.975ms | 799 |
| foundry | singularity | 68.62 | 16.690ms | 30.331ms | 824 |
| reactor | pulse | 79.46 | 14.007ms | 19.691ms | 954 |
| reactor | overdrive | 78.61 | 14.091ms | 15.392ms | 944 |
| reactor | singularity | 76.01 | 15.067ms | 23.410ms | 913 |

最终各段65.77—79.46平均FPS、P95 14.007—17.517ms，仍保留179.674ms长帧。以上为同一高配设备上的屏外世界压力夹具，不称为稳定60FPS、无卡顿、整局性能、最低配置或纯GPU耗时。九张截图位于`captures/v04-render-final-<map>-<skill>.png`；声效/完整HUD外壳与正常三槽玩法性能需另测。


`tests/capture_v04_app.gd`另生成14张原生演示图：英中菜单/设置、三技能战斗、胜利结果及960宽结果，均已实际查看且无错误；这是准备装备/敌人的截图夹具。不与12张机库UI功能夹具或真人通关混为一项；最终发布文件另以英文菜单和4秒战斗实际启动截图验证图集显示正常。

## 本地交付与浏览器验收

Godot4.7.2匹配模板已最终导出v0.4.0 Windows x64和单线程Web，构建没有ERROR/SCRIPT ERROR；ICU的一般提示不视为引擎错误。产物为`exports/windows/Scrapstorm.exe`及相邻PCK、`exports/web/index.html`及配套文件。构建日志为`artifacts/build-import.log`、`build-windows.log`、`build-web.log`，无ERROR/WARNING。最终EXE文件版本资源为0.4.0.0。

`artifacts/Scrapstorm-Night-Shift-v0.4.0-Windows.zip`为 **61,964,072字节**，SHA-256：

`DCD5966EE2783193358B0D2ECB4B7B792A4A1308C9AE35A52FA43B7309F5AA69`

`artifacts/v04-package-manifest.json`记录六文件（EXE、PCK、项目声明、字体OFL、Godot许可、组件版权）与解压目录`artifacts/v04-zip-check-78b1d030`，六项解压SHA全部匹配。声明和资产已经冻结，后续仅文档更改不改变此包。

最终原导出EXE和ZIP解压EXE都未传入源码`--path`：原导出正常显示默认英文机库；ZIP从独立解压目录实际运行4秒、有3个自然生成敌人。两个截图保存返回0；日志`artifacts/v04-windows-native.log`、`v04-zip-native.log`无ERROR/WARNING，证据汇总`artifacts/v04-native-verification.json`。`captures/v04/windows-export-menu.png`和`windows-zip-combat.png`已实际查看，图集透明背景正确、无黑底。随后按各自分发目录独立启动两个最终EXE，用保留的Process句柄等待退出并读取真实ExitCode，二者均为0；`artifacts/v04-native-exits.json`及`v04-export-exit.log`/`v04-zip-exit.log`记录该结果，与PNG写入返回值分开。所有验证EXE进程均已退出。

导出Web已有 **59项完整普通输入检查通过**，`artifacts/standard-web-v04-smoke.json`记录Microsoft Edge/Chromium、1280×720及重点960宽中英界面、33张截图，页面/控制台/网络/HTTP错误均为0。响应式输入机器人完成实际120秒第一阶段，经历商店、保存/页面重载、第二阶段进入和主动撤退，并检查三图入口与Quick入口；没有改币、改血、跳阶段或写入游戏状态。技能独立充能/施放、暂停/真实失焦和音频手势也有覆盖。

这59项来自最后Quick外观字段三行修复**之前**的v0.4 Web PCK（25,128,580字节），旧包哈希未在覆盖前记录，不能套用最终包SHA；报告已明确该限制。最终包的Quick/外观字段与本地化撤退已另做17项补测并通过，详见下段。59项不覆盖Web完整三图15—20分钟首领通关或所有商店分支/换装；这些行为由对应Godot专项覆盖，不能混成浏览器已测。


最终Web补测`artifacts/standard-web-v04-quick-smoke.json` **17/17通过、9张截图**，记录最终PCK为25,128,708字节，SHA-256：

`d6f97d27fb84e6c69c03f6003c0cf1f2b46a1f2444d5d4bd50f867ff2648d0d2`

该PCK哈希与最终Windows PCK一致。补测通过普通工坊输入装备免费Overdrive、刷新保留、Quick约18秒自然实战及独立充能/重复输入/暂停，按实际击杀结算金币，再刷新确认保留；随后中文960宽零击杀短局不发额外奖励、不重复结算。英中结果等淡入完成后截取，正确显示提前收班。JS页面/控制台/网络/HTTP错误均为0，实际查看早期敌人图集、HUD和结果。

补测保留一次失败尝试：旧测试错误假设有击杀的Quick撤退也必须零金币；改为按实际击杀奖励规则验证后重跑，游戏奖励规则未因此改变。完整59项与最终包17项分开列出，共76个检查记录、42张浏览器截图，不能说76项都运行于同一个包。最后三行Quick外观字段差异由应用回归和此补测覆盖，非默认付费外观的具体字段传播由原生43项应用测试验证。

实看浏览器机库、整备、工坊、商店、技能状态和英中关键页面，没有占位翻译键或影响选择的重叠；这是截图可读性检查，不代表创作者美术认可。付费外观传播由原生应用测试验证，此次新浏览器档使用免费工业黄/薄荷配色。

## 固定边界

商店停留不计时、不采集、不作为金币或成绩输入。正常输入探针不加血、加钱、直接伤害或跳过阶段；状态夹具明确标注，不能作为真人局长或胜率。原生/Web 实际渲染和无渲染 CPU 数据分开，音频波形检测和听感认可分开。

创作者已指出 v0.3 首领过易；新机制需要实际试玩确认。美术、首局理解、构筑选择与金币节奏同样保留真人反馈。代码和原创资源公开复用许可尚待决定；无付费采购、无 GitHub 推送、无公开 Release。
