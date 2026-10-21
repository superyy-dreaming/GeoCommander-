# 首页、地图与设置升级验证

验证日期：2026-10-20。Godot `4.7.2.stable.official.ed1daf0bf`，macOS / Apple M5，Forward+ / Metal 4.0 / 2D HDR，Retina 2×。本轮工程入口为 `scenes/main_menu.tscn`，双击 `run.command` 启动。

## 完成范围

首页提供单人、多人、设置和独立兵种演练。三张地图全部可玩，正式地形、导航及菜单预览读取同一 `MapCatalog`。`MatchSession` 管理本次运行内选图与一次性开局请求，重开沿用当前地图，直接启动旧战场默认均衡前线。

`GameSettings` 管理本机设置，逐项校验版本与字段，经临时文件写入后替换 `user://settings.cfg`。损坏配置保留备份并说明恢复结果，备份失败明确报告；保存失败保留运行内效果，显示“未保存”和重试按钮。窗口或全屏变化需15秒内确认，取消或超时恢复。普通设置即时保存，恢复默认需确认，不清除开局指令或战局。

战中设置暂停单位、经济、计时与冷却，关闭恢复此前暂停状态。打开会取消技能瞄准，保留矩阵草稿、输入及对局数据；字号原地刷新，不重建战场。设置与放弃确认互斥，子确认优先处理Esc，焦点限制在面板内。多人功能为禁用菜单，没有实现网络请求。

## 编译与行为回归

无界面导入通过，52个脚本在真实项目及Autoload上下文中编译，0失败。检查日志同时要求结果标记、0失败且无Godot `SCRIPT ERROR`、`ERROR` 或 `FAIL`，不只依赖退出码。记录为 `artifacts/launcher-import.log`、`launcher-script-check.log`。

| 验证集 | 通过项 | 日志 |
|---|---:|---|
| 原MVP规则 | 76 | launcher-v1-tests.log |
| V2上下文、兵种演武、战术及生命周期 | 61 | launcher-v2-tests.log |
| V2真实技能与地形战斗 | 13 | launcher-v2-combat.log |
| 实际场景切换、演练往返及重开保留地图 | 12 | launcher-flow.log |
| 三图双向三路物理通行 | 18 | launcher-navigation.log |
| 新菜单、地图、设置、持久化及暂停 | 60 | launcher-tests.log |
| 独立进程重新读取设置 | 1 | launcher-settings-restart.log |
| 原生Metal窗口、鼠标、焦点、冷却及字形 | 14 | launcher-native-flow.log |
| 合计 | **255** | launcher-validation.json |

原167项全部保留，场景及导航夹具扩展到三地图。三图分别通过实际部署与拓扑转移入口验证扣费及地形落点，并以物理形状查询核对无碰撞。新检查覆盖首次默认、逐项非法配置恢复、损坏备份、真实写盘失败及重试、恢复默认不重置战局、显示确认/取消/超时、已有暂停所有权与字号保留草稿。原生检查包括真实鼠标选图、真实全屏与窗口尺寸、取消及倒计时回退、Tab限制焦点、Esc关闭、0%发光和镜头速度2倍位移。独立进程读取上一进程保存的字号、速度与低动效设置。

路径修复：旧路径游标在距离拐点35px时提前跳点，长墙地图会把单位送回被遮挡方向，与射线避障相互拉扯。现改为仅在下一整段净空时跳点，当前段受阻时回退游标。三图双向三路18组通行均通过，最慢397个物理帧。实体对称性、预览定义数量、掩体/晶簇部署落点及原传送安全规则均有回归覆盖。

## 三地图完整对局与性能

固定种子 `20261020`，每图使用正式地图、移动、技能与敌方AI，峰值60单位，资源及人口未越界，`failures` 为空。测试驱动蓝方补兵与提交指令。三次均由红方摧毁蓝方核心进入结束态；这些结果证明可完成整局，不证明战术平衡或胜率。

| 地图 | 模拟秒数 | 物理帧数 | 峰值弹体 |
|---|---:|---:|---:|
| 均衡前线 | 126.53 | 7593 | 12 |
| 双翼迂回 | 141.18 | 8472 | 14 |
| 折光阵列 | 193.35 | 11602 | 17 |

证据为 `artifacts/launcher-simulation-<地图ID>.json` 及同名日志。地图ID为balanced / flanks / refraction。完整模拟在地形与导航最终改动后运行；后续修复仅影响字体与设置状态提示，没有重跑相同战斗模拟。

性能独立采样，单位生命提高到100000以维持60单位，其他移动、技能、避障使用正式逻辑，预热3秒，每段采样约2秒：

| 场景 | 平均FPS | 物理耗时 | process耗时 | 路由 / 射线累计耗时 |
|---|---:|---:|---:|---:|
| 60单位战斗 | 60.02 | 10.34ms | 12.68ms | 38.04 / 24.85ms |
| 同场景低动效 | 60.17 | 9.09ms | 12.44ms | 28.60 / 21.50ms |

第一段193次路由、18183条射线，达到本机平均55FPS目标。证据为 `launcher-performance.json` / `.log`。短采样不代表其他设备或所有对局阶段的最低帧率；同步截图不用于性能结论。

## 原生视觉与界面收口

`artifacts/launcher-visual-report.json` 列出40个真实Metal画面，涵盖1280×720、1440×900、1920×1080，运行于Retina 2×屏幕。首页100%/130%、三地图选择、三个设置页、15秒显示确认、多人菜单、五兵种档案、演武、准备矩阵、三图战斗、战中设置、放弃确认及结算均有证据。可见控件越界为0；滚动区域内部内容按裁剪容器处理。最大字号不通过缩小字号消除溢出。

保留真实RGBH `.pixels`，由 `tests/encode_captures.py` 按实际格式执行线性到sRGB编码，未添加画面元素。`launcher-contact.png` 为同40张的缩略总览。关键截图：

- `launcher-home-large-1280x720.png`：首页与独立演练入口。
- `launcher-map-flanks-large-1440x900.png`、`launcher-map-refraction-large-1440x900.png`：地图差异与图例。
- `launcher-settings-1-large-1280x720.png`、`launcher-display-confirm-large-1280x720.png`：130%设置及确认窗。
- `launcher-academy-diamond-large-1280x720.png`：最小窗口、大字号档案与完整演示操作。
- `launcher-prepare-large-1280x720.png`、`launcher-result-large-1280x720.png`：矩阵及结算。

完成有界批量检查后，由全新上下文的独立代理按Impeccable收口清单审查。运行环境没有预注册的专用reviewer/documenter，因此采用独立代理执行同等清单；原生GDScript没有适用的HTML/CSS detector，未声称运行Web检查。完整首轮与修复评分保存在 `artifacts/launcher-finish-review.md`。

首轮发现两项字体问题。字号变化重复创建Theme/SystemFont导致 `Parameter "fd" is null`，现改为共享稳定主题并原地更新；原生流程14/0且无此错误。中文缺字的根因经Godot系统字体API验证：本机PingFang SC解析成PingFang HK字面，缺少“敌”“远”。现通过 `Font.fallbacks` 显式加入系统Hiragino Sans GB，关键简体字形断言通过，真实截图保持原文显示。没有打包字体或替换文案规避问题。独立定向复核B的disposition为 **ship**，两项字体问题均评分 **resolved**，未发现这批修复引入的布局回归。该结论限于报告列出的修复与原生桌面证据，不等于所有平台或辅助技术认证。

## 原文、复现与回滚

原需求 `gemini-code-1792472151386.md` 与 `AGENT_PATCH_V2.md` 已分别与V1快照逐字节比较，均一致。SHA-256依次为 `13197ab7d909b5d95b975be6670d63d9bdb5587fce6e46211cc4c734c7304096`、`15fedbf276e7496f8503474acc4b04541bdc0b37fd82a8fdb0ba6635faea1ec2`。

运行命令见README。自动化无界面测试使用独立配置，原生QA必须带 `-- --geo-test`；不会覆盖正式 `settings.cfg`。旧战场与测试入口无需经过主菜单。

本轮修改前的 `artifacts/pre-launcher-source-backup.tar.gz` 包含105个源码及文档文件，已检查归档可读取。回滚前关闭游戏，将归档解压至独立目录，以Godot导入其中的 `project.godot` 运行旧版，保留当前工程副本。不要覆盖式解压至当前目录，避免遗留本轮新增脚本。此流程不覆盖引擎和用户配置。V1快照继续保留。源码、`.godot/`缓存和 `artifacts/`验证证据分开。

## 剩余限制

- 多人为菜单占位，不提供房间或网络对战；没有音频、安装包、外部素材、真实LLM服务或战局存档。
- 未验收macOS输入法候选窗及完整组合输入。原生日志偶有 `IMKCFRunLoopWakeUpReliable` 系统mach port消息，之后游戏检查全部完成；没有把此消息当作游戏失败，也没有宣称系统输入法全部验证。
- 未验证其他操作系统、屏幕阅读器或移动端；本轮桌面最低1280×720，不将Web移动断点要求套用于原生游戏。
- 设计使用ui-ux-pro-max与impeccable，继承原生现有主题；不声称使用Web组件库、浏览器QA、图片生成或未加载的Apple设计skill。Godot字体接口参考官方SystemFont/OS类文档，并在本机4.7.2运行确认。
