# SCRAPSTORM: NIGHT SHIFT · 技术实现

更新：2026-09-07，v0.5.1 首领 B 方案本地可玩版，保留 v0.5 无尽、扩展工具与档案。Godot `4.7.2.stable.official.ed1daf0bf`、typed GDScript、Compatibility，1280×720 逻辑画布，Windows x64 与单线程 Web。已实现基础与本轮变更分开记录；新增设计见 [B 方案](BOSS_COUNTER_B.md)，最终发布验证见[构建报告](BUILD_REPORT.md)，不沿用历史版本的测试数量。

## 模块职责

| 模块 | 当前职责 |
|---|---|
| `scripts/ui/main.gd` | 八个菜单入口、模式部署、HUD/商店/路线/档案/结果状态，结算与检查点集成 |
| `scripts/ui/launch_hangar.gd` | 适配窗口的机库主视觉、突出 Overtime 的真实按钮、当前装备/称号摘要 |
| `scripts/ui/mission_panel.gd`、`garage_panel.gd`、`ui_kit.gd` | 三图起点/标准选择、出战整备、金币物品与目标、共享控件 |
| `scripts/ui/shop_panel.gd`、`overtime_panel.gd` | 商品、刷新/拆卸/修理/分支请求，三选一路线、返回补给/部署/首领后撤离 |
| `scripts/ui/archive_panel.gd` | 最近战斗分页与可滚动详情、成就奖章/进度/预览；仅主动装备写档 |
| `scripts/ui/hangar_visual.gd`、`skill_preview.gd` | 原创程序机体、地图与技能预览，包括成就涂装/配色 |
| `scripts/game/game_world.gd` | 单局资源、实体、伤害/回收、模式进度、检查点导入导出与聚合统计 |
| `scripts/game/map_catalog.gd` | 三图布局、名称、首领基础值和标准阶段时间 |
| `scripts/game/standard_director.gd`、`standard_boss.gd` | 标准阶段、地图危险、首领两阶段选择、护甲、预警和反制 |
| `scripts/game/overtime_director.gd` | 房间/循环/目标、地图轮换、六风险八增益、路线 RNG 与保存 |
| `scripts/game/run_loadout.gd` | 八工具、三/四槽、六改装、三候选、报价/刷新/拆卸/修理、六进化条件 |
| `scripts/game/arsenal_effects.gd` | 自动激光/导弹/无人机/地雷及新增行为进化，有界对象池 |
| `scripts/game/evolution_effects.gd` | 导电网与压缩井；环绕锯由 world 接入 |
| `scripts/game/mechanical_encounters.gd` | 精英、场地装置、三图首领反制目标及一次性击破 |
| `scripts/game/player_ability.gd` | 独立充能/回充预算、技能/分支/瞄点、实际效果与外观配色 |
| `scripts/game/enemy_atlas.gd`、`arena_detail.gd`、`combat_feedback.gd` | 普通机体图集、场地几何、有限击停/圈/碎片/位移；保留几何回退 |
| `scripts/services/player_profile.gd` | v3 本地经济、收藏/目标/徽章、历史/生涯/成就、去重与迁移事务 |
| `scripts/services/achievement_catalog.gd` | 16 项只读成就定义、进度、八件可装备奖励；与金币商店目录分开 |
| `scripts/services/settings.gd`、`sound_bank.gd` | 英中/输入/音量/特效偏好，八 SFX 声部及双三层音乐 bank |
| `localization/strings.csv` | 英文与中文的共享文本键 |

## 世界、界面与无尽推进

界面 mode 与世界 `combat/shop/finished` 分离。无尽复用三图与原首领机制，在 `endless_mode=true` 时优先采用房间完成逻辑；同时为 true 的 `standard_mode` 仅用于共享地图逻辑，不得触发标准通关、徽章或精通奖励。Quick 与旧 Demo 接口保留兼容。

标准五阶段共 870 战斗秒，最终必须实际击败首领。无尽每三房一首领，`rooms_completed` 包含已完成首领房，`cycles_completed=floor(rooms_completed/3)`；每轮按起始区域轮换地图。坚守 65 秒，其余普通目标房 80 秒上限、达标后最早 40 秒结束，首领无计时胜利。死亡优先于同帧完成，终态信号只发一次。若同一物理帧玩家与首领均死亡，首领死亡立即登记已完成房间，以失败结果结算该房与首领；不触发商店治疗或撤离奖励。

无尽 `finish_room()` 冻结三条不同增益/风险选项；`choose()` 同步安装一次增益并保存 choice，`advance()` 只在已有选择时进入下一房。八增益各最多五层，满层候选改修复/零件；风险在下一房生效。首领已完成时允许不选路线直接撤离。返回商店需刷新实际属性、货币与候选状态，不能只显示选路线前缓存。

商店和路线页不推进战斗 tick、伤害、技能计时或充能，完全不采集商店停留秒数。暂停/失焦/波末阻断回收和技能输入门控，恢复后需要新输入。

## 装备、资源与统一伤害

世界持有局内零件和喷射能量，Ability 持有 0—100 技能充能，Profile 持有金币。Loadout 校验购买、刷新、拆卸和修理后同步提交，世界扣款，交易中间不 yield；不足或重复请求不消费 RNG、机会或余额。标准三槽/价格倍率 2.8，无尽四槽/1.35；逐店加价按第五店封顶。每店一次刷新、一次非滚刷拆卸，拆卸退款为第一店各已购等级成本之和的 35%，不退后续溢价。修理只在无尽第三房之后的候选池，每店最多买一次。商品 token 带 run/shop/revision，刷新或换装后旧 token 失效。

统一伤害入口记录护甲后实际扣除值，死亡/掉落只结算一次。新增 `damage_taken`/`damage_events`、`boss_damage_taken`/`boss_kills` 反映真实受伤和击杀；治疗不回滚历史，免疫/护盾阻挡不制造受伤记录。`evolutions_seen` 保存本局曾激活的进化，换装后仍可用于历史和累计目标。

工具显示与执行共用 `tool_stats()`，属性修正不写回共享基础配置。激光锁定方向后充能射出，导弹追踪并爆炸，无人机聚焦目标，地雷有预备/触发状态；新增棱镜接力、猎手蜂群、军械连锁改变实际行为。原碎钢风暴、导电网、压缩爆破继续保留。无尽增益通过有效修正与实际事件挂接，清场时释放相关临时效果。

普通攻击、爆炸和主要牵引遵循遮挡；首领冲撞预演与真实移动共享碰撞解析。v0.5 有意允许激光线和导弹/地雷爆炸通过 `director.hit_targets()` 辅助击破节点，喷射与主动技能仍直接支持反制。节点死亡和连爆通过已结算标记避免重复，连锁不递归重伤同一地雷。

## B 方案的实际接线与边界

世界通过 `boss_supply(energy_amount, skill_amount, fill_energy=false)` 同步补能，只向已有 `energy` 与 Ability 充能注入，不调用普通 `_collect_scrap()`。入首领的一次性准备、诱撞、阀门进度、节点击毁、电池补给和破招各自有事件边界；防止重复命中、重读状态或暂停恢复再次发放。不得改动钱包、金币、累计现场零件、连击/25 零件治疗、回收自愈或历史成就指标。

常态承伤为 0.55/0.50/0.45，破招 6 秒、喷射补到实际容量上限、技能 +30；本体接触伤害在破招期间关闭，存活小怪瘫痪 2 秒。瞄准优先走实际工具目标筛选，保留距离/视线/存活条件；技能、喷射和新自动工具继续共用节点去重。暴露倍率按来源为 blast 1.85、ability 1.50、其他 1.65。`_boss_in_aim()` 使用 ±0.22 弧度和玩家视线；`_nearest_target()` 再检查实际发射点视线、射程及 excluded ID。阀门返能以 supply_progress 最高进度补差额；节点一秒吸附与武器击破共用 `_settle_node()`。电池死亡即时补 35/12，反馈丝带仅视觉 0.65 秒、最多十组；不存在延迟拾取再结算。

## 存档版本与原子恢复

`ScrapProfile` 版本为 3，默认 `user://profile.json`。外层 payload 与 SHA-256 校验，内层验证结构、有限数值、范围、选择归属和历史语义。临时文件写入并 flush 后，仅备份已验证主档再替换；主档失败尝试 `.bak`。经济/装备写入失败恢复内存快照。

v1→v3 将免费 Overdrive、已购者一次性 180 金币退款、原 v2 目标/徽章字段与新档案字段一并提交。v2→v3 保留退款标记和余额，不重复补偿。迁移保留收藏、选择、地图记录、精通与完整旧检查点；不伪造旧局详细历史。JSON 解码的整数可能为浮点类型，按有限且无小数部分验证，而非简单限定内存类型。

| 状态层 | 当前版本与兼容 |
|---|---|
| Profile | v3，读取有效 v1/v2 并事务迁移 |
| 世界商店检查点 envelope | v1，新模块字段逐项验证，旧标准检查点仍可恢复 |
| Loadout | v3，支持旧 v1/v2 的四工具三槽状态，补齐新工具和修理状态 |
| Ability | v2，兼容旧 v1 技能状态，保留独立充能与分支 |
| Overtime / Arsenal | 各自 v1；无尽路线与新增工具状态分别导入 |

只在商店保存地图/阶段、战斗时间、玩家资源、当前玩法 RNG、商店 RNG、装备、已售、刷新/拆卸/修理、技能/分支、无尽进度/路线/增益和完整伤害/首领/进化指标。世界先导入临时模块并验证整数、去重、房间/地图/首领数量一致性，再修改活世界；不只保存 seed，也不靠重读再次安装路线。

旧标准检查点缺少真实伤害指标时，`metrics_known=false`。后续即使记录了新的受伤，也不能宣称整局或首领无伤。Profile 再检查跟踪标记和必要字段，缺失证明不发无伤奖。

继续会读盘恢复到原商店、原 run ID 与已选路线。替换续玩时先 `restore_checkpoint()` 得到真实 `get_stats()`，标记 abandoned 后结算，再执行新模式回调；不能把含 nested ability/overtime 的 checkpoint 原样当作结算 stats，否则会丢失房间和技能统计。战斗中不提供任意帧快照。

## 历史、成就与金币

最近 100 局明细和终身 career 分开；结算 ID 保留最近 256 个，属于普通流程去重而非服务器防作弊服务。history 保存战斗时长、模式/区域、完成内容、击杀/回收/受伤、技能次数、最终工具/改装、曾激活进化、结果、实际到账、首领指标和风险。严格拒绝未知历史字段、非有限/负数/小数计数、未知工具与重复记录。`get_history()` 返回倒序分页的深拷贝，浏览不修改原档。

`AchievementCatalog` 将原商店 `CATALOG` 与奖励 `REWARDS` 分离，未获得的成就奖励不能购买/设为商店目标。16 项进度从地图 records 和 career 计算；新有效战斗结算自动领取达标奖励一次。金币、成就 ID/时刻、收藏、history、career、去重与检查点清除处于同一事务；失败全部回滚。奖励不自动覆盖当前外观，展柜 `equip()` 后才修改 setup。

标准奖励保留阶段、通关、首通与封顶击杀。无尽按完成房×8、首领×20、击杀 min(10,floor(kills/20))，首领后合法撤离再加 min(40,bosses×10)。`settle()` 返回 `base_coins/achievement_coins/coins/total/new_achievements/unlocks/history_entry`；实际到账受余额 1 亿上限限制。没有商店秒数、剩余钱包换金币或无限局外属性。

整局无伤要求标准获胜、至少 870 战斗秒、实际击败首领、完整指标且真实受伤/次数均零。首领无伤要求合格完成的首领战和本局首领受伤为零。Quick、空退出、未跟踪旧局不能代替无伤；标准技能精通仍要求三次合格标准通关且各至少三次施放。详细目录见[战斗档案与成就](V05_BATTLE_ARCHIVE_AND_ACHIEVEMENTS.md)。

## 技能和表现

Ability 保留兼容 `ability_ratio/cost/cooldown/uses`；ratio 是独立充能比例，cost/cooldown 为 0，不用喷射能量判断技能是否可用。HUD 使用 charging/ready/active、charge、remaining、branch/rank。现场每零件 +3 充能，首领真实非技能伤害每点 +0.1，受每战斗秒 6 点预算限制；主动技能自身伤害不直接回充；击破电池/节点领取的是独立固定事件补给，不走伤害回充预算。商店不被动站着充满。

黑洞准星使用实际 `aim_position`，最大 260 距离，预览与真实投放共用碰撞；旧夹具无落点时回退朝向。牵引直接按碰撞移动，不被普通 knock 衰减吞掉；已预警/冲锋的精英和已提交首领冲撞保持其路线。Overdrive 修改实际工具和机动速率。第二、第四补给选择/强化互斥分支，状态可恢复。

新主菜单使用生成的机库图片和 Rajdhani 英文标题字形，Noto CJK 支持中文；实际装备仍由独立资料和程序预览显示。素材来源、AI 标记和字体许可由素材台账/声明管理。普通敌人保留 640×720 RGBA 图集：九机体×四帧×普通/受击，72 个 80×80 图块，几何 fallback 保留；危险提示、血条、精英/首领实时绘制。HUD 不随世界震动。

新增工具对象池有明确上限：12 导弹、12 地雷、20 光束、16 爆炸；其余战斗反馈同样有界。减弱特效保留功能与危险图形。无渲染长局只能检查逻辑和对象上限，不能替代 GPU 帧时间或低配试玩。

## 音频与验收边界

三图各 32 小节/四段音乐，9 个同步基础/节奏/首领 Ogg。阶段改混音不重启，换图由两个三层 bank 交叉淡化；8 个 SFX 声部、预警优先，主/音乐/音效独立音量，Web 需要真实输入手势启声。实际文件、生成源和测量见音频 README/manifest；波形不是主观听感。原生测试退出等待 `SoundBank.shutdown()` 释放音频。

`tools/build.ps1` 检查精确引擎版本、进程返回与 ERROR/SCRIPT ERROR 文本，Windows/Web 使用对应模板。构建脚本读取 project.godot 的 config/version，Windows 按版本输出到 `exports/windows-v0.5.1/Scrapstorm.exe`，Web 输出到 `exports/web/index.html` 并通过 HTTP(S) 访问。`?smoke=1` 仅发布只读诊断，不提供加钱/改波入口。

本轮的 Profile、Archive、Overtime 世界和 main 集成各有专项测试。`tests/test_overtime_app.gd` 通过真实主场景按钮/信号、文件保存和重建场景验证模式入口、选路线、恢复、撤离和替换续玩；房间时长、击杀和首领伤害使用明确夹具快进，因此不能声称普通键鼠通关。检查点非法数据、一次性结算和事务失败单独验证。具体最新数量与实际截图写入各自 artifacts 报告，最终整包/浏览器证据由[构建报告](BUILD_REPORT.md)统一记录。
