# v0.5.1 GitHub 发布前报告

日期：2026-09-07。当前完成的是**本地发布准备**，尚未创建 GitHub 仓库、推送、发布 Release 或部署在线试玩。创作者署名采用 [zhangduyou2-cmyk](https://github.com/zhangduyou2-cmyk)，仓库名计划为 `scrapstorm-night-shift`。

## 已补齐

- 英文首页、完整中文 README、四张真实未修图的展示截图及逐图来源/状态说明；架构、更新日志、路线、贡献指南、问题/PR 模板。
- CREDITS、PRIVACY、SECURITY 和随包游玩说明；保留字体 OFL、Godot 及其第三方组件声明、原创/AI 辅助资源的实际来源。
- 官方 Godot 4.7.2 双哈希锁定、缓存校验、源码首次导入、版本匹配启动、非零退出/脚本错误/测试报告失败处理，以及 Windows/Web 构建清单。
- GitHub Actions 的只读源码检查、33 项 Python 工具检查、全部 Godot 回归；手动构建仅产临时 artifact，不自动上线。工作流固定 action 提交 SHA，远程执行尚未发生。
- 可选浏览器测试依赖 package.json/lock 和可选音频 requirements。修掉四个浏览器脚本对开发者私有目录的依赖，并新增本版短流程。
- 发现 Godot 会把 npm 工具的图片/字体/JSON 收入游戏包，已用导入忽略及导出排除修复。最终构建日志确认不含 node_modules 和根 npm 清单。
- Windows/Web ZIP 验证版本、成员大小、SHA-256、CRC 与独立解压字节；验证后才替换输出，失败不覆盖旧候选包。修复 Windows PowerShell 5.1 对 UTF-8 中文路径 JSON 和进程退出码的处理。
- 当前公开源码扫描、确定性源码 ZIP 和干净解压复核。当前文件中的私人目录已移除；原始概念文档保持不变。

## 实际验证

| 范围 | 本轮结果 | 边界 |
| --- | --- | --- |
| 最新源码 Godot 回归 | 25 套、1,390 项全过 | 隔离档案；不是真人胜率 |
| Python 工具 | 构建 5 项 + 仓库 19 项 + 分发清单 9 项，全过 | 包含错误/损坏/旧清单的失败路径 |
| 干净源码复现 | 首次导入、全部回归、源码启动、Windows/Web 导出通过 | 新目录无引擎安装及 .godot 缓存；使用官方双哈希验证的离线归档 |
| 当前 Windows | 原导出菜单、ZIP 独立解压后的约 4 秒战斗均退出 0，截图保存成功 | ZIP 短战斗用旧 Demo 启动探针，不是整局通关 |
| 当前 Web ZIP | 从解压包经本地 HTTP 服务，16 项全部通过，浏览器/网络错误 0 | Edge，正常鼠标键盘、全新隔离档案；三模式进入、暂停、技能、主动退场、语言/历史刷新 |
| 已有音频素材 | 170 项波形/清单检查通过 | 没有重新生成素材；不代替试听 |

Web 短验证包括 1280×720 与 960×540 窗口、中英文切换后刷新保留、无尽四槽/标准三槽/快速 180 秒模式的独立入口、三次正常退场生成恰好三条历史、刷新不重复结算。

本轮最终 PCK 仍与原 v0.5.1 游戏 PCK 完全一致，SHA-256：
`c4ef62642fc8c98feea3749237f5b92655bee08c5e83ea452c308e5cab143bc0`。
此次完善工程与分发，不改变游戏平衡。

本机原始报告保存在未纳入源码包的 `artifacts/`：
`publication-final-regressions.json`、`clean-checkout-verification.json`、
`v051-windows-native-validation.json`、`release-web-2026-09-07T12-26-54-535Z.json`、
`windows-v0.5.1-package.json`、`web-v0.5.1-package.json`。
公开截图与元数据则在 [docs/media](media/README.md)。

## 当前本地候选包

这些是许可待确认的本地候选包，不是公开 Release 附件：

| 文件 | 大小（字节） | SHA-256 |
| --- | ---: | --- |
| Scrapstorm-Night-Shift-v0.5.1-Windows.zip | 62,552,829 | `9a34013d22f9aaae0954016d6725c8a871c278cc8b5fbb4f3f8491d8c9c03ee3` |
| Scrapstorm-Night-Shift-v0.5.1-Web.zip | 34,727,108 | `a1395bf95209ea7d2e06ca6963f8a37ca4ee3d0dc1bd6a906ff4c45880b7a65b` |

Windows 11 文件；Web 18 文件。均包含第三方许可、制作署名、数据说明、游玩说明与构建清单；Web 不附编辑器 .import 旁文件。选定根 LICENSE 后需重新打包并刷新校验值。源码审阅包为 `Scrapstorm-Night-Shift-v0.5.1-Source-REVIEW.zip`，清单与 SHA 保存在包外，避免自引用。

## 公开副本与唯一待确认决策

原 Git 开发历史的九个提交使用个人邮箱，13 个历史文本版本含私人路径。扫描没有发现高置信度密钥或超过 50 MiB 的历史文件；这不等于覆盖所有可能的敏感信息。原历史完整保留，本轮未重写、删除或推送。

源码审阅 ZIP 和 `artifacts/github-upload-v0.5.1-review/` 副本不带旧 .git、引擎、缓存、存档、日志和导出包。应从这类干净副本建立新的公开初始历史，使用 GitHub 隐私提交邮箱。不要直接推送原开发目录的旧历史。

**仍需创作者选择代码及自有素材的公开复用许可。** [MIT 建议范围与含义](LICENSING.md) 已写好，本机 `artifacts/preflight/MIT-PROPOSAL.txt` 是可审阅草案，尚未作为有效许可证安装。严格上传检查因此保留 `license_pending` 一项；`--prepare` 只允许制作本地审阅快照，不绕过其他错误。确认后同步许可证与素材台账、重打包、建立干净的首发提交。

## 未覆盖与保留的失败

- 完整联网下载曾因链路停滞失败，记录保留；不把“离线归档 + 干净源码复现”写成全联网成功。可选 Chromium 安装在完整下载进度后未完成，已停止该安装进程；实际 Web 验证使用本机 Edge，npm ci 成功。
- 原 v0.5.1 无尽长 Web 流程两次在首房自然阵亡，未抵达商店/路线/检查点。新短流程未覆盖这些环节；原失败见 [构建报告](BUILD_REPORT.md)。
- 尚无真实远程 Actions、公开 HTTPS 试玩或 GitHub Release 验证；Windows 未签名。
- 长无尽局的平衡、更多硬件性能、真人首领难度和音乐听感仍需后续迭代；不承诺所有设备稳定 60 FPS。

具体首发操作和仓库元信息见 [PUBLISHING](PUBLISHING.md)。原开发资料、失败日志及本地进度均保留。
