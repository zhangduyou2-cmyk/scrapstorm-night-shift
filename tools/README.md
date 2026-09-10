# 本地安装、验证与构建

核心流程面向 Windows 10/11 x64：Windows PowerShell 5.1 或 PowerShell 7、系统 `curl.exe`、Python **3.11+**。Godot 使用 Standard/GDScript，不需要 .NET SDK、付费软件、管理员权限或修改全局 PATH。仅玩已导出的 Windows 包不需要这些开发工具。

## 从源码启动

在项目根目录打开 PowerShell：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/setup_godot.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File Play.ps1
```

`Play.ps1 -Editor` 打开编辑器；直接运行会先导入资源再启动。引擎不存在时启动器会安装固定版本。双击 `Play.cmd` 优先启动与 `project.godot` 版本相同的已导出 Windows 包；没有包时转为源码启动。它不会选择旧版本目录里仍然留存的 EXE。

`ExecutionPolicy Bypass` 只作用于这次 PowerShell 进程，不修改机器策略。脚本在本项目 `.tools/` 中安装便携引擎；安装记录和下载存放于 `.preproduction-local/`，均不提交 Git。

## 官方版本与下载验证

固定 **Godot 4.7.2 stable**，官方于 2026-08-18 发布。2026-09-07 已核对 [官方发布](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable)、[官方 Release API](https://api.github.com/repos/godotengine/godot-builds/releases/tags/4.7.2-stable) 的 SHA-256 与 [官方 SHA512 清单](https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/SHA512-SUMS.txt)。完整值固定在 [godot.lock.json](godot.lock.json)。

安装器会验证归档大小、SHA-256 和 SHA-512，缓存也不例外。已提取的文件会与已验证归档再比较；损坏下载不能被当成有效缓存解压。下载失败保留 `.part` 用于断点续传；若明确提示校验不符，应删除提示中的那个坏归档后重试。更换引擎需要共同审查 `.godot-version`、锁文件、导出预设与回归结果，`-Version` 不允许绕过锁文件。

编辑器归档约 86 MB。安装导出模板额外下载官方完整模板包约 1.28 GB，仅提取本工程需要的 Windows/Web 文件。首次完整流程约下载 1.37 GB，实际速度取决于网络；没有依赖开发者电脑上某个未公开下载地址或引擎缓存。

## 测试与双平台导出

```powershell
python -m unittest discover -s tools/tests -v
python -m unittest discover -s tests -p 'test_*.py' -v
python tools/check_repository.py --public-tree
python tools/run_tests.py --label local
powershell -NoProfile -ExecutionPolicy Bypass -File Play.ps1 -Smoke
powershell -NoProfile -ExecutionPolicy Bypass -File tools/setup_godot.ps1 -IncludeTemplates
powershell -NoProfile -ExecutionPolicy Bypass -File tools/build.ps1 -Target All
```

测试 runner 先检查固定引擎版本、导入全部资源，再顺序运行行为套件。非零退出、脚本错误、资源泄漏、报告失败或缺少完成检查数都使流程失败；每项日志和最终 JSON 保存在 `artifacts/`。支持在命令最后指定项目内 `.gd` 测试文件进行局部复核。套件和启动探针都用 `--test-settings` 隔离保存，不能用它们代表真人难度评价。

`Play.ps1 -Smoke` 只检查五帧无界面源码启动，不验证渲染或实际玩法。导出目标可选 `Windows`、`Web`、`All`。Windows 输出 `exports/windows-v<项目版本>/`，Web 输出 `exports/web/`；每个目录有本次输出的字节数和 SHA-256 清单。Godot 不同运行的导出不承诺逐字节完全相同，这里验证的是依赖固定、流程可复现与各包独立完整性。

第三方许可必定随导出复制；存在的 `CREDITS.md`、`PRIVACY.md`、`README-PLAY.txt` 和已确定的根 `LICENSE` 也会复制。代码许可证未确定时，构建脚本不会编造一份许可。

```powershell
python -m http.server 8765 --bind 127.0.0.1 --directory exports/web
```

通过浏览器访问 `http://127.0.0.1:8765/`。Web 必须经 HTTP 运行；源码 HTML 双击不是有效测试。

## 不带本地缓存的复现

需额外安装 Git，但不用创建提交、远程仓库或推送：

```powershell
python tools/verify_clean_checkout.py
```

脚本将 Git 当前跟踪及未忽略的新文件复制到新的临时目录（不复制 `.git`、`.tools`、`.godot`、产物或下载缓存），重新从官方安装、运行工具测试/全部行为套件、启动源码并导出 Windows/Web。它包含尚未提交的源文件，因此报告准确称为“工作区源码快照”，不是声称已经从 GitHub 克隆过。

每个文件的哈希、步骤状态和临时目录位置记入 `artifacts/clean-checkout-verification.json`。失败目录和日志保留，失败不能记成通过。`--copy-only` 仅准备目录，报告不声明完成验证。

已有可信归档时可以节省重复下载，但必须明确标注这是缓存归档复现：

```powershell
python tools/verify_clean_checkout.py --archive-cache .preproduction-local/downloads
```

即便使用该参数，新目录仍没有安装好的引擎和 `.godot`；归档每次仍按官方双哈希校验。

## GitHub Actions

[Windows source checks](../.github/workflows/check.yml) 使用 `windows-2022`，只申请 `contents: read`。push/PR 检查工具失败处理、安装、资源导入、全部隔离行为套件和源码启动。人工 `workflow_dispatch` 可勾选双平台构建，仅上传保留 14 天的 Actions artifact；没有自动 Release、Pages、仓库写入或任何发布步骤。

`checkout`、`setup-python`、`upload-artifact` 都固定完整提交 SHA，2026-09-07 从各自 `actions/*` 官方 tag API 核对；Dependabot 每周提议更新，仍需正常审查。工作流是否在 GitHub 真正执行，需要仓库获准上传后另行确认，本地等价步骤通过不能写成远程 CI 已绿。

## 可选开发依赖

核心构建和行为测试仅使用 Python 标准库。`--public-tree` 是正式上传门槛，根 LICENSE 待确认时会如实失败；不妨碍单独导入、运行或导出。以下依赖不会在普通启动/构建中自动安装：

- 浏览器探针需 Node.js 22+：`npm ci` 安装仓库锁定的 Playwright，随后 `npx playwright install chromium`。默认使用配套 Chromium；环境变量 `SCRAPSTORM_BROWSER_CHANNEL=msedge` 可选本机 Edge。先启动本地 HTTP 服务，再运行 `npm run smoke:release` 做当前版本短验收。`tools/smoke_overtime.cjs` 是需正常操作通过首房的较长无尽流程，会受真实战斗难度影响；失败需要保留，不能跳波或改属性掩盖。`smoke_web.cjs`、`smoke_demo.cjs`、`smoke_standard.cjs` 的旧入口坐标只保留作历史复核，不是当前发布的验收入口。
- 重新生成或分析原创音频：`python -m pip install -r requirements-audio.txt`。仓库已包含可用音频，正常运行无需 NumPy、SciPy 或 SoundFile。
- 无头浏览器可能使用软件渲染；普通输入探针、状态夹具、原生截图和性能测量是不同证据，不能互相替代。
