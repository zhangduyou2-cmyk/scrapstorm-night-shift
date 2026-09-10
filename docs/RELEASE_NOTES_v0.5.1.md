# v0.5.1 · Counter, recharge, burst

**发布状态：2026-09-10 已公开发布 Windows 试玩版。** [Release 与下载](https://github.com/zhangduyou2-cmyk/scrapstorm-night-shift/releases/tag/v0.5.1)。完整解压后双击 Play.cmd；暂未发布在线 Web 试玩。历史候选包数据保留如下，当前附件以 Release 的 SHA256SUMS.txt 为准。

[English overview](../README.md) · [完整中文说明](README.zh-CN.md) · [完整构建证据](BUILD_REPORT.md) · [版本历史](../CHANGELOG.md)

## 本次变化

v0.5.1 采用创作者批准的首领 B 方案，让自动工具在常态持续输出，通过有限机制补能抓住破招后的集中爆发窗口。

- 首领入场一次补足基础喷射储能并充满主动技能；保留高于基础值的已有储能。
- 三图常态承伤分别为 55% / 50% / 45%；破招持续六秒，补满当前喷射容量并加 30 技能充能。
- 诱撞、吸阀、双节点和电池小怪提供各自有限资源回流。资源立即到账，回流丝带只作视觉；专用补给不产生零件或治疗。
- 破招时首领本体不造成接触伤害，存活支援小怪短时瘫痪；明确的 HUD 显示爆发窗口。
- 瞄准首领时，符合方向、射程与遮挡条件的自动工具优先首领。没有新增左键基础枪或新货币。

OVERTIME 无尽、三图 NIGHT SHIFT、三分钟 QUICK SWEEP、八工具六进化、16 成就和最近百局档案全部保留。商店始终自由停留，不记录耗时。详细数值和事件边界见 [B 方案](BOSS_COUNTER_B.md)。

## Windows 候选包与发布准备

本地包名：`Scrapstorm-Night-Shift-v0.5.1-Windows.zip`。解压到可写目录后运行 `Scrapstorm.exe`，保持其余文件相邻。需要 Windows x86_64；此说明不代表已验证其他系统或特定最低配置。

以下为发布准备前的候选包存档；补齐制作署名、说明与构建清单后已重新打包，**当前公开包以 Release 附件和 SHA256SUMS.txt 为准，启动与存档隔离检查见 [分发报告](DISTRIBUTION_CHECK.md)**。

| 项目 | 发布准备前候选包（历史） |
| --- | --- |
| 大小 | 62,547,561 字节 |
| ZIP SHA-256 | `726d1b9b185d54d6c568adc0023c2e5ed3f52b7ef0e86d1f981491b8be707ed9` |
| PCK SHA-256 | `c4ef62642fc8c98feea3749237f5b92655bee08c5e83ea452c308e5cab143bc0` |
| EXE 文件版本 | 0.5.1.0 |

旧包内七文件：`Scrapstorm.exe`、`Scrapstorm.pck`、`THIRD_PARTY_NOTICES.md`、`FONT-LICENSE.txt`、`RAJDHANI-LICENSE.txt`、`GODOT_LICENSE.txt`、`GODOT_COPYRIGHT.txt`。本表不能沿用到重打包后的资产；正式许可确认后的公开包仍须另验。

源码打开方式及本地 Web 服务命令见 [README](../README.md)。源码仓库不附带导出包；没有把内部 `artifacts/` 路径当成公开下载地址。Web 必须通过 HTTP/HTTPS 服务运行。

## 保存兼容性

本版继续使用 Profile v3，迁移合法 v1/v2 档案，保留金币、收藏、记录及标准检查点，旧付费 Overdrive 只退款一次。标准/无尽从最近商店检查点恢复；不支持任意战斗帧续玩。Windows 与浏览器存档独立，没有云账号；清理浏览器站点数据可能清除其进度。历史暂无导出按钮。

## 实际验证与已知边界

- **本地 Godot：25 套 / 1,390 项通过。** Windows 原导出和独立解压版本实际启动均退出 0；这是分发与短时运行核验，不是完整整局通关。
- **首领样本：12 个早期构筑隔离夹具实际击败首领，约 67.7–113.5 秒。** 预设房间/装备后使用普通战斗输入，不能推断完整经济、所有构筑或真人胜率。
- **最终 Web 全流程未通过。** 两次普通输入分别在约 41.08 秒、59.47 秒自然死亡。各自已到达九项检查通过且无页面/控制台/网络错误；商店、路线、重载续玩与下一房未到达。旧 v0.5.0 的完整流程不能算成本版通过。
- 当前没有新的 v0.5.1 完整场景性能基准或稳定 60 FPS 承诺。较低配置、长无尽局、真人难度和音乐听感仍需继续验证。
- 代表图为实际渲染的未修图 PNG；首领、构筑及成就使用明确标注的展示状态，不冒充自然游玩或人类成绩。

## 贡献与授权

创作者 **zhangduyou2-cmyk** 提供创意、范围决策、试玩反馈和最终批准；Codex 主导代码、集成，并协助设计、原创程序素材、验证和文档。项目源码、文档及原创资产在创作者有权授权的范围内采用 [MIT 许可](../LICENSE)。字体、引擎和其他组件继续保留各自条款，见[第三方声明](../THIRD_PARTY_NOTICES.md)。

English release summary: v0.5.1 improves sustained boss damage, finite resource recovery and six-second counter openings. The Windows playtest is now publicly available in the linked GitHub Release. Windows launch and 1,390 local checks passed; the final Web runs did not reach the shop/checkpoint flow. See the English README for controls, source builds, save behavior and AI-assisted authorship.
