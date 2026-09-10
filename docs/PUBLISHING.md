# GitHub 发布

目标仓库：[zhangduyou2-cmyk/scrapstorm-night-shift](https://github.com/zhangduyou2-cmyk/scrapstorm-night-shift)。账号已通过登录态核对。源码及项目自有素材按 [MIT](LICENSING.md) 授权；第三方条款独立保留。

## 发布内容

- 仓库使用独立的公开源码副本和全新 main 历史，不推送原开发仓库的私人提交邮箱及本机路径。提交使用账号的 GitHub noreply 邮箱。
- Windows v0.5.1 ZIP 与 SHA256SUMS.txt 作为 Release 附件。完整解压后双击 Play.cmd；源码目录不包含预编译游戏。
- 录制工作台、玩家存档、编辑器、缓存、原始录屏和本地配置均排除。公开截图的展示状态与来源保留在 docs/media/README.md。
- Windows 包的运行文件沿用已验证的构建，仅补齐 MIT 和发布声明。来源与运行验证见 [分发检查](DISTRIBUTION_CHECK.md)。

## 后续版本检查

```powershell
python tools/check_repository.py --public-tree
python -m unittest discover -s tools/tests -v
python -m unittest discover -s tests -p 'test_*.py' -v
python tools/run_tests.py --label release
```

构建和打包命令见根 README 与 tools/package_windows.py。GitHub Actions 在 push/PR 执行只读检查，手动构建仅产生临时候选 artifact，不自动发布。发布后应核对实际 Actions 结果、Release 附件大小和 SHA-256，不能以本地测试替代远程成功。

本次只发布 Windows 试玩与源码。Web 尚无正式托管试玩地址；发布网页前仍需完成真实 HTTPS 环境的音频、存档和完整关卡流程验证。长线平衡和低配置性能不由打包检查证明。
