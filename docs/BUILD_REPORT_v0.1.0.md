# v0.1.0 构建与验证记录

日期：2026-09-07（北京时间）。M1三分钟核心原型已实现，自动验证完成；完整三分钟真人试玩和手感调整待进行。M2商店、多武器、六波与首领尚未实现。

## 工具和交付

- 引擎：Godot 4.7.2.stable.official.ed1daf0bf，Standard、GDScript、Compatibility。
- 构建：同版本Windows x86_64与Web模板，Web明确使用`web_nothreads_release.zip`。
- Windows：`exports/windows/Scrapstorm.exe`及相邻数据包；根目录`Play.cmd`可直接启动。
- Web：`exports/web/index.html`及配套文件；需HTTP服务，不能双击HTML运行。
- 配置和构建入口：`.godot-version`、`export_presets.cfg`、`tools/setup_godot.ps1`、`tools/build.ps1`。
- 每个平台均附字体OFL、Godot MIT与组件版权声明，以及第三方素材说明。

## 已完成的验证

| 检查 | 实际结果 | 证据与边界 |
| --- | --- | --- |
| 引擎导入及双端release导出 | 成功，无脚本/导出错误 | 本地`artifacts/build-*.log`；构建脚本同时检查退出码和Godot错误文本 |
| 核心规则与压力 | 27项通过，0失败 | `scripts/game/test_world.gd`；包括单次记账、币能分离、暂停/冲刺取消吸附、无敌、障碍/边界、重开、维修、终态优先及信号顺序 |
| 主场景集成 | 22项通过，0失败 | `tests/test_app.gd`；菜单/战斗/暂停/设置/结算，语言与配置保存、重开清理和结算不被实时状态覆盖 |
| 浏览器交互 | 21项通过，0错误 | `tools/smoke_web.cjs`和本地`artifacts/web-smoke.json`；Microsoft Edge/Chromium，实际导出产物、正常键鼠输入 |
| Windows实际运行 | 菜单及18秒战斗画面成功渲染 | NVIDIA GeForce RTX 5080 Laptop GPU，OpenGL；`media/menu.png`及`media/gameplay.png`是实际程序截图 |
| 字体和授权文件 | 已纳入源文件与构建包 | 英文/中文菜单截图无明显缺字，素材台账记录实际字体、声音与程序视觉来源 |

浏览器检查覆盖：新配置默认英语、切中文并刷新保留、切回英语、W/D移动、右键吸附与释放喷射、能量减少但货币不被消耗、冲刺、暂停冻结与恢复、真实标签页失焦自动暂停。页面、控制台、网络与HTTP错误列表均为空。Web游玩交互约10.5秒，整组运行约24秒；没有完成整局真人通关。音频资源与触发已经接入，听感、音量平衡和不同设备播放仍需试玩确认。

180秒压力检查使用固定步长共10,800 tick，逻辑均值约0.229ms/tick，峰值100敌人／150掉落／240粒子。它是无渲染、玩家刻意无敌的逻辑测试，不代表正常难度、真实显卡帧率或整局可玩性。浏览器自动化使用软件渲染，也不作为硬件性能验收。

## 重现

先按[开发入口](DEVELOPMENT_START.md)准备引擎和导出，然后在项目根目录运行：

```powershell
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script scripts/game/test_world.gd -- --test-settings --stress
& '.\.tools\godot\Godot_v4.7.2-stable_win64_console.exe' --headless --path . --script tests/test_app.gd -- --test-settings
```

浏览器回归需本机Microsoft Edge，以及Node.js和局部安装的Playwright。先在一个终端启动Web服务，再在另一个终端执行：

```powershell
npm install --prefix .tools/browser playwright@1.58.2 --no-save --no-audit --no-fund
node tools/smoke_web.cjs
```

检查脚本只在测试URL`?smoke=1`读取运行状态，操作仍通过正常键鼠完成。测试配置与用户游戏配置分开，避免覆盖用户偏好。诊断JSON、日志、引擎缓存和导出产物留在被Git忽略的本地目录；公开文档只保留摘要和代表画面。

## 待验收

- 完整三分钟真人试玩：吸附是否易理解、喷射是否爽快、冲刺能否避险、伤害与维修是否合理。
- Windows与Web实际听测、长期游玩、不同分辨率与显卡上的帧率和输入延迟。
- Firefox及其他浏览器兼容性；当前只对Edge作出实际验证结论。
- 原型手感反馈后调整数值，再开始M2。公开GitHub仓库、作者信息与代码许可在发布阶段处理。
