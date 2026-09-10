# SCRAPSTORM: NIGHT SHIFT · 开发入口

更新：2026-09-07，当前为 **v0.5.1 首领 B 方案**。本地已可玩并完成 Windows/Web 导出；25 套回归 1,390 项通过，原导出和独立 ZIP 程序启动均退出 0。最终 Web 两次普通输入在首店前自然死亡，商店/路线/重载链路未覆盖，不套用旧版通过结果。

从含 `project.godot` 的**仓库根目录**运行以下命令。源码目录可以放在自己的任意工作区；本说明不依赖创作者的机器路径。新读者先看[英文 README](../README.md)或[中文说明](README.zh-CN.md)，接续开发先读 [AGENTS](../AGENTS.md)、[决策](DECISIONS.md)与[架构](ARCHITECTURE.md)。

## 环境和运行

使用 Godot **4.7.2 Standard**、GDScript 和 Compatibility。维护的辅助脚本面向 Windows PowerShell；构建验证及打包要求 Python **3.11+**。Node/浏览器自动化与音频生成是可选工具，不是运行游戏的前置条件。

```powershell
.\tools\setup_godot.ps1
.\Play.ps1
.\Play.ps1 -Editor
```

第一条把固定引擎下载到本地项目工具目录；不要求管理员权限或修改全局 PATH。运行与编辑二选一即可。源码不携带引擎、缓存、导出包或本地测试产物。

```powershell
.\tools\setup_godot.ps1 -IncludeTemplates
.\tools\build.ps1 -Target All
.\Play.cmd
```

`Play.cmd` 优先启动 `exports/windows-v0.5.1/Scrapstorm.exe`，没有当前版本包时转为源码启动。构建脚本根据 `project.godot` 版本创建 Windows 目录，Web 输出到 `exports/web`。保持 EXE、PCK 与随包许可相邻；已打开的旧版本窗口不会自动更新。

```powershell
python -m http.server 8765 --bind 127.0.0.1 --directory exports/web
```

浏览器访问 `http://127.0.0.1:8765/`，不要直接双击 HTML。正式公开托管和下载尚未建立。PowerShell 策略、锁定下载验证、干净源码快照和可选工具依赖见[工具说明](../tools/README.md)。

## 当前玩法与持久化

主机库 → OVERTIME → 起始地区 → 技能整备 → 无尽房间。每三房首领，每房购物与一次风险/增益选择；首领后可撤离或继续。三图按循环轮换，音乐随地区与阶段变化。标准模式五阶段共 870 战斗秒后首领；Quick 为 180 秒。

八工具三等级，标准三槽、无尽四槽；商店有有限拆卸、维修与新工具发现，六套进化改变攻击行为。Pulse/Overdrive 免费，Singularity 蓝图 160 金币；主动技能独立充能，第二和第四店有分支选择。商店不计时，也不提供停留回充。

Profile v3 保存最近百局、终身记录与 16 成就，兼容合法 v1/v2、旧标准检查点及付费过载一次退款。无尽检查点保存已选路线、增益、当前随机状态和实际损伤等指标；恢复不重复支付或叠加。旧档未知受伤数据不给无伤成就，治疗也不能抹除命中记录。

## B 方案接续与验证

常态工具持续推进首领血条；地图机制和电池补给充入现有喷射/技能资源，破招形成六秒集中输出窗口。专用补给不产货币、不治疗，不新增左键基础枪。机制上限、目标优先与防重放规则以 [BOSS_COUNTER_B](BOSS_COUNTER_B.md) 为准。

```powershell
python tools/run_tests.py
```

测试使用隔离档案，检查退出码及 Godot 错误文本。当前记录是本地执行结果，不是假定托管 CI 已运行。普通输入探针、状态夹具、原生图检、浏览器和真人评价必须分开；精确日志、包哈希和未通过范围见[构建报告](BUILD_REPORT.md)。

继续设计与实现时使用[玩法](GAME_BRIEF.md)、[技术方案](TECHNICAL_PLAN.md)、[成就数据](V05_BATTLE_ARCHIVE_AND_ACHIEVEMENTS.md)、[素材台账](ASSET_REGISTER.csv)和[路线](ROADMAP.md)。首次公开说明见[版本说明](RELEASE_NOTES_v0.5.1.md)；公开许可尚待创作者确认，本地整理不等于已经创建或推送仓库。
