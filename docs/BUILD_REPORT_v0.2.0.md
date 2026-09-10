# v0.2.0 构建与验证记录

日期：2026-09-07（北京时间）。M2 Demo已实现，本轮202项自动检查通过。创作者对原型反馈“好玩”并要求继续开发；完整M2真人验收尚未完成。原型历史记录保存在[BUILD_REPORT_v0.1.0.md](BUILD_REPORT_v0.1.0.md)。

## 实现与交付

- 默认Demo为五个55秒普通波＋第六波二阶段首领；保留独立三分钟快速模式。
- 已接入波末回收与维修、三选商店、3种工具各三级、6种改装各三级、远程敌人、装备组合与重新开局。
- 首启英文、简体中文可选并保存，菜单、HUD、商店及结算均接入翻译。
- Godot `4.7.2.stable.official.ed1daf0bf`，Standard／GDScript／Compatibility；Windows x86_64与Web使用匹配模板，Web为`web_nothreads_release.zip`。
- Windows产物：`exports/windows/Scrapstorm.exe`及相邻数据包；Web产物：`exports/web/index.html`及配套文件，必须通过HTTP运行。
- 11个程序生成WAV与Noto字体已纳入工程及授权记录。headless检查只加载音频资源，不启动dummy音频播放；实际听感仍待真人确认。

## 本轮检查

| 检查 | 实际结果 | 证据与范围 |
| --- | --- | --- |
| 原型规则与压力 | 27项通过 | `scripts/game/test_world.gd`，含180秒逻辑压力 |
| App集成 | 22项通过 | `tests/test_app.gd`，菜单、偏好、暂停、结算与重开 |
| Demo世界 | 43项通过 | `tests/test_demo_world.gd`，波次、结算、装备、敌人与首领规则 |
| Loadout与商店经济 | 37项通过 | `tests/test_loadout.gd`，候选、等级、购买、价格与重复请求 |
| Demo App集成 | 39项通过 | `tests/test_demo_app.gd`，商店、设置返回、波次切换及结算 |
| 实际Web交互 | 34项通过 | `tools/smoke_demo.cjs`；`artifacts/demo-web-smoke.json` |
| 合计 | **202项通过** | 六组断言合计；下述AI探针与截图不重复计入 |
| Windows/Web release导出 | 已成功 | `tools/build.ps1 -Target All`；本地构建日志 |
| Windows v0.2最终release启动 | 已通过 | 实际启动最终Scrapstorm.exe，NVIDIA RTX 5080 Laptop GPU渲染12秒Demo；native-v02.log无错误，截图结果0，EXE产品版本0.2.0.0 |
| Windows分发包 | 已通过 | v0.2.0 ZIP约54MiB，6成员CRC校验通过；独立解压后启动菜单并成功截图，package-v02.log无错误 |

原型压力为无渲染、玩家刻意无敌的180秒模拟，共10,800 tick；本轮逻辑均值约**0.237ms/tick**，峰值100敌人／150掉落／231粒子。它验证逻辑与数量上限，不证明正常难度、GPU帧率或最低配置。

## 真实Web与画面证据

Edge／Chromium使用普通键鼠输入及只读可见目标观测。34项覆盖英文默认、中文刷新持久化、移动、吸附释放、币能分离、冲刺、暂停与真实失焦，以及第一波、商店购买和进入第二波。页面JavaScript、控制台、网络请求、HTTP错误均为0。

反应式输入AI正常经过55.0167秒，以100HP、50击杀、56份已回收零件进入第一家商店；结算钱包75。购买22零件的泡沫工具后钱包53、等级0→1；重复点击未再次扣款或升级。中英文设置返回同一商店，单次继续仅进入第二波。截图：`captures/menu-v02.png`、`gameplay-v02.png`、`shop-en.png`、`shop-zh.png`，已实际检查中英文排版。

此前两条固定路线分别在28.58秒、31.8秒因接触伤害败北，记录保留在同一JSON的`previous_attempts`。后续改为观察敌人、避险和正确瞄准后通过；这是测试策略变化，不是据失败降低游戏难度。Web只验证第一家商店；后续商店附加价格0／12／24／36／48已由规则测试覆盖，尚无浏览器多店回归。SwiftShader结果不作为真实硬件帧率结论。

`tools/capture_demo.gd`在NVIDIA显卡上实际渲染商店与首领界面，产物为`captures/shop-fixture-en.png`、`shop-fixture-zh.png`、`boss-fixture-en.png`。该夹具设置波次与生命以准备画面，属于阶段画面验证，**不构成正常游玩或完整通关证据**。

## 正常规则AI探针

`tests/probe_demo_balance.gd`以输入AI、固定60Hz逻辑步长运行完整五个55秒普通波和首领；不授予生命、不直接伤害敌人、不跳过战斗时间。商店购买正常执行，商店停留时间为0，无画面渲染。

| 策略／seed | 结果 | 战斗时间／剩余生命 | 报告 |
| --- | --- | --- | --- |
| combo／982 | 胜利 | 302.12秒／103.6HP（上限140） | `artifacts/demo-balance-probe-priced-baseline.json` |
| brush／8102 | 胜利 | 355.47秒／31.2HP | `artifacts/demo-balance-probe.json` |
| brush／982 | 胜利 | 344.43秒／15.2HP | `artifacts/demo-balance-probe.json` |

调价基线报告保留同一AI的4局对照，并非4局均获胜；最新报告为修正首领避险半径后的2局brush。brush转为胜利的变动在探针策略，没有修改首领。以上说明两类打法存在AI成功样本，不能替代真人平衡验收，也不能当作包含商店思考时间的玩家局长或渲染帧率。

## 待验收

- 完整M2真人试玩：普通波节奏、三种工具与改装选择、首领预警和死亡原因可读性。
- 两端声音、音量、输入手感及原生切窗体验；Windows最终release启动与12秒渲染已经通过。
- 浏览器后续商店与完整首领流程、多分辨率、Firefox及目标设备性能。

重现入口见[DEVELOPMENT_START.md](DEVELOPMENT_START.md)，分层覆盖与试玩记录见[TEST_PLAN.md](TEST_PLAN.md)。诊断JSON、构建日志与导出产物保留在本地忽略目录。
