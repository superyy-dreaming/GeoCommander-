# GeoCommander 操作与开发手册

[返回项目首页](../README.md) · [实机截图](screenshots/README.md)

以下命令均在项目根目录执行。

纯程序化几何战术游戏。部署五种兵种，通过中文或英文指令改变自动战斗行为，对抗本地 AI 指挥官。

## 启动

本机双击 `run.command`，或在项目目录运行：

```sh
./run.command
```

也可以使用 Godot **4.7.2 Stable 标准版**导入 `project.godot`。本机引擎隔离安装在 `~/.local/share/geocommander/tools/4.7.2/Godot.app`，没有修改系统 PATH。其他位置的引擎可通过 `GEO_GODOT` 环境变量指定：

```sh
GEO_GODOT='/path/to/Godot' ./run.command
```

首次从其他机器复制项目时，先执行一次导入：

```sh
./run.command --headless --import
```

渲染采用 Forward+、4x 2D MSAA 和 HDR。Apple Silicon 使用 Metal。最低窗口 1280×720，推荐 1440×900 或更高。首轮着色器编译可能比后续启动慢。

## 开始界面与六张地图

启动后进入首页，可选择“单人游戏”“多人游戏”“设置”，或通过独立入口进入“兵种演练”。多人页面仅展示开发中的创建与加入菜单，多人菜单不会发起网络请求。

单人页提供六张全部解锁的地图，左侧选择，右侧预览实际地形，再点击“进入战前准备”。六图具有相同兵种、经济与胜负规则，统一使用2400×1350世界空间（地图空间版本3）：

| 地图 | 特点 |
|---|---|
| 均衡前线 | 标准三路防线，动态闸门与隐匿星云 |
| 双翼迂回 | 南北单向加速轨与侧翼星云，适合高速包抄 |
| 折光阵列 | 中央三向分光棱镜与六处晶簇 |
| 盘旋堡垒 | S型斜向墙体与一对虫洞 |
| 交叉火线 | X型走廊、两对虫洞、动态闸门和星云 |
| 晶脉迷城 | 中央过载反应堆、Flux拾取物和隐匿星云 |

选图在本次程序运行内保留，重新开局沿用当前地图；退出程序后默认均衡前线。准备矩阵仍可编辑后开战。战中返回首页需要确认，确认期间暂停，取消后继续。

## 兵种演练

首页“兵种演练”提供五兵种真实 HP、速度、射程、费用和技能冷却；“协同需求”为说明评级，不参与结算。低于1600px时名册改为横向选择条，档案独立滚动，演武完整等比缩放。

独立物理世界中的演武可切换自动循环、手动普攻和技能、重置。每1.5秒尝试普攻、每3.5秒尝试技能，当前动作结束后再触发。演示刷新冷却与站位，正式数值保持 UnitCatalog 配置。六边形没有直接普攻。

“应用为默认开局指令”经过真实编译后只在本次运行保留，返回首页和重开不清除，退出程序后恢复默认。仅选择兵种不保存指令。“选择地图”进入单人页，“返回首页”退出演武并清理上下文。

菜单支持鼠标、Tab / Shift+Tab 和 Enter / Space，滚动区域跟随焦点。

提示词实验室提供整体提示词和五兵种独立草稿、AI JSON 校验、六图双方自由布阵与预设、同种子默认对照、实际统计和规则读数。“应用当前兵种为开局”只替换当前兵种，战前矩阵直接保留已编译规则。

精细编排 v2 支持方向和时长、航点、真实掩体与探出、绕后、定向技能、分支、循环和可恢复中断。“步骤”页可编辑并撤销，“编辑路径”模式可拖动航点；暂停后可逐帧或运行到下一步骤。见[操作、规则与迁移说明](tactic-plan.md)及[验证记录](tactic-plan-verification.md)。

## 本机设置

首页和战场顶部都可打开设置，包含显示、界面、LLM、操作与关于四页。战中打开会暂停单位、经济、计时和冷却，关闭恢复打开前的暂停状态。字号调整保留战术草稿和输入内容。

- 窗口或全屏；窗口尺寸1280×720、1440×810、1440×900、1920×1080。默认1440×810，不适合当前屏幕的尺寸不可选。进入全屏时会捕获当前实际窗口布局，文字、按钮、面板与战场整体等比放大；手动调整过窗口尺寸也会保持眼前排版，显示器宽高比不同时居中留边。游戏内切换仍需在15秒内确认，取消或超时恢复；macOS原生全屏入口使用同一缩放规则。
- 字号100%、115%、130%、150%、180%，覆盖菜单、档案、演武读数、HUD、矩阵与确认窗，不改变世界和单位尺寸。
- 发光0%–150%，默认100%；0%关闭发光。低动效关闭扫描和拖尾、减少碎片并取消淡出。
- 镜头速度50%–200%，默认100%。操作页提供快捷键、玩法与版本说明。
- 普通设置即时生效并自动保存；保存失败明确提示并提供重试。“恢复默认”需要确认，不清除战局或开局指令。

配置保存为 `user://settings.cfg`；macOS 默认位于 `~/Library/Application Support/Godot/app_userdata/GeoCommander/settings.cfg`。损坏或不支持版本的配置保留 `.invalid-*` 备份，并恢复默认。自动测试使用独立测试配置，不覆盖正式设置。开局指令、选图和战局不写入此配置。

## 玩法与操作

准备阶段可以在战术矩阵中编辑规则，也可以直接开始对局。初始阵容免费，双方各有九个单位、180 Flux，基础收入每秒 12 Flux。两个能源棱镜各提供每秒 6 Flux。

| 操作 | 键位 |
|---|---|
| 部署三角、方形、圆形、菱形、六边形 | `1`、`2`、`3`、`4`、`5` |
| 移动镜头 | `WASD` 或方向键 |
| 缩放 | 鼠标滚轮 |
| 电磁脉冲、矩阵超频、拓扑转移 | `Z`、`X`、`C`，然后左键选择位置 |
| 取消瞄准 | 右键或 `Esc` |
| 打开战术矩阵 | 未编辑文本时按 `Tab`，或点击矩阵按钮 |
| 矩阵内部导航 | `Tab` / `Shift+Tab`，焦点在矩阵内循环 |
| 退出编辑 / 关闭矩阵 | `Esc` |

单位自动选择目标、占点和战斗。生命值通过几何内部填充表达，没有浮动血条。每队最多 30 单位，六边形最多 2 个。

- **三角**：高速近战、冲刺穿刺、背刺暴击。
- **方形**：高生命前线单位，部署阻挡敌军和弹体的反射护盾。友军可以穿过护盾。
- **圆形**：脉冲弹体和聚集拉拽，坍缩会提示附近三角协同冲刺。
- **菱形**：远程弹体、风筝和最多两次反射的激光。折射战术会让菱形和方形尝试配合镜面角度。
- **六边形**：范围治疗和增益。每个存活六边形使终端与全局技能冷却恢复速度增加 40%。全部阵亡后终端锁定，重新部署恢复。

十分钟内摧毁敌方基地即获胜。超时比较基地剩余生命百分比，完全相同为平局。结算页自动聚焦重新开局按钮，点击或按 `Enter` 即可重开。

## 战术指令

每次提交都从默认规则重新编译，并替换整套战术。同一条指令可以组合要求，冲突字段按文字出现顺序覆盖。

```text
三角形绕后切菱形
正方形折射激光，菱形棱镜配合
保护六边形
全军突击
风筝拉扯
均衡战术
中路推进，晶簇折射
分推，保护六边形
mid lane, crystal bounce
flank assassin
refract bounce
```

终端基础冷却 30 秒。无法识别的指令不改变当前配置、不消耗冷却。矩阵中的编辑和撤退阈值滑块仅修改草稿，提交后才应用；战中与终端共享冷却及链路限制，打开矩阵不暂停战斗。

战中终端继续采用本地关键词解析，提交会替换整队战术。兵种演练中的“提示词 · 布阵验证”可通过自行配置的 OpenAI 兼容服务将自然语言编译为单兵种行动编排 JSON，兼容已有 v1 条件规则。操作与规则见[精细战术编排](tactic-plan.md)，API 配置见 [AI 提示词实验室](ai-laboratory.md)。Key 仅保留本次运行。

## 战术地形

六图的预览、正式对局、实验室、导航及AI地图摘要共用`MapCatalog`。墙体使用倒角堡垒、V形墙、楔形胸墙和六棱立柱；墙、晶簇、关闭的闸门阻挡真实移动与攻击。V形墙按凹轮廓分解碰撞，不把凹口填平。预览为独立HDR物理世界，仅绘制地图，不推进战斗与机关。

普通激光最多750px、两次反射，护盾每次增伤35%，晶簇每次增伤25%。命中中央分光棱镜后最多分裂一次：中束85%、两侧±26°各75%，每束650px并继承已用反射次数。同次施法对同一目标只结算最高命中伤害。

加速轨同向主动移动×1.75、逆向×0.65；熵减区×0.65，和超频、虫洞移速增益相乘，不放大拉拽与击退。隐匿星云限制敌军锁定；同星云、145px近距或被扫描/EMP显形的单位仍可被感知，范围伤害和已发射攻击仍能命中。六边形扫描为独立技能，不影响治疗。

虫洞每单位8秒冷却，每对5次、耗尽14秒恢复；动态闸门20秒关闭、15秒开放。反应堆每55秒结算一次，最后6秒预警，爆炸160伤害并产生三个各50 Flux拾取物。准备、暂停及结束阶段停止机关结算。

AI使用共享路网、动态拓扑和0°/±38°三射线处理目的地移动。方向步骤保持指定方向，不擅自绕行。普通AI默认避开反应堆预警，精细方案需要明确授权。详见[地图、机关与地形提示词](map-overhaul.md)和[本轮验证](map-overhaul-verification.md)。

## 全局技能

| 技能 | 消耗 / 基础冷却 | 效果 |
|---|---|---|
| EMP STRIKE | 40 Flux / 22 秒 | 200px 范围伤害、2.8 秒控制，中断敌军冲刺和激光蓄力 |
| OVERCLOCK | 50 Flux / 25 秒 | 240×240 区域持续 5 秒，友军移动速度 +60%、技能冷却恢复速度 ×2 |
| WARP SWAP | 45 Flux / 30 秒 | 点击敌军附近，将基地 350px 内的三角和方形传送到目标区域；否则把点击点 160px 内友军送到最近六边形周围 |

传送没有可用单位、锚点或安全落点时会提示原因，不扣费。技能选中和取消不扣费，只有有效施放才消耗资源并进入冷却。

## 验证命令

```sh
./run.command --headless --import
./run.command --headless --scene res://tests/check_scripts.tscn
./run.command --headless --scene res://tests/map_overhaul_runner.tscn
./run.command --headless --scene res://tests/test_runner.tscn
./run.command --headless --fixed-fps 60 --disable-vsync --scene res://tests/v2_test_runner.tscn
./run.command --headless --fixed-fps 60 --disable-vsync --scene res://tests/v2_combat_runner.tscn
./run.command --headless --fixed-fps 60 --disable-vsync --scene res://tests/scene_flow_runner.tscn
./run.command --headless --fixed-fps 60 --disable-vsync --scene res://tests/navigation_probe.tscn
./run.command --headless --fixed-fps 60 --disable-vsync --scene res://tests/simulation_runner.tscn
./run.command --headless --fixed-fps 60 --scene res://tests/launcher_test_runner.tscn
./run.command --headless --scene res://tests/launcher_test_runner.tscn -- --persist-read
./run.command --headless --fixed-fps 60 --scene res://tests/simulation_runner.tscn -- --map=flanks
./run.command --headless --fixed-fps 60 --scene res://tests/simulation_runner.tscn -- --map=refraction
./run.command --scene res://tests/launcher_native_flow.tscn -- --geo-test
./run.command --scene res://tests/fullscreen_scale_native.tscn -- --geo-test
./run.command --scene res://tests/fullscreen_titlebar_native.tscn -- --geo-test
./run.command --scene res://tests/performance_runner.tscn -- --geo-test --launcher
./run.command --scene res://tests/launcher_visual_runner.tscn -- --geo-test
python3 tests/encode_captures.py launcher-visual-report.json
```

`fullscreen_scale_native`验证直接`Window.mode`入口；`fullscreen_titlebar_native`需要按终端提示实际点击系统绿色按钮，并从系统 Window 菜单退出全屏，验证两种不同的事件顺序。最后一条仅用于 QA 截图，需要 NumPy 和 Pillow。它把 Godot 的真实 HDR 线性帧缓冲编码成 sRGB PNG，不增加、修改任何画面元素。游戏运行不依赖 Python 或第三方库。

`artifacts/` 保存测试日志、截图与报告，`.godot/` 保存引擎缓存，两者均不属于运行源码。仓库仅保留 `artifacts/` 中八份不含凭据的真实模型 JSON 回放样例，其余日志、QA 截图、报告与源码快照为本机验收产物，不随 Git 分发；GitHub 展示截图单独保存在 `docs/screenshots/`。验证文档中的这些产物链接需在本机查看或运行对应测试重新生成。AI 实验室操作见 [使用说明](ai-laboratory.md)，最新两栏布局、40%反馈区、战场菜单与悬浮读数见 [布局验证](laboratory-layout-verification.md)，窗口与全屏的等比呈现见 [全屏缩放验证](fullscreen-scaling-verification.md)。AI实验室原有验证见 [行为验证](ai-laboratory-verification.md)。此前验证记录见 [首页、地图与设置验证](launcher-verification.md)，旧版记录保留在 [V2 验证](verification.md)。

克隆后可离线回放已验证的模型输出，无需 API Key：

```sh
./run.command --headless --fixed-fps 60 --disable-vsync --scene res://tests/real_llm_runner.tscn -- --replay
./run.command --headless --fixed-fps 60 --disable-vsync --scene res://tests/boundary_tactic_runner.tscn -- --replay
```

上述固定帧参数仅用于保存的 JSON 战斗回放。向真实供应商发起 HTTP 请求时不要使用固定帧或倍速参数。

SiliconFlow / DeepSeek-V4.1-Flash 的真实提示词生成、条件边界与实际技能验证，以及本轮修复和复现方式，见 [真实模型验证](real-llm-verification.md)。

三角已支持“沿边界绕后、用冲刺赶路、优先消灭菱形”的完整提示词；指定SiliconFlow模型采用实测的非思考JSON模式。操作、原文和生成与实战证据见 [边界绕后验证](boundary-tactic-verification.md)。更新源码后需要重启游戏再生成。

## 工程与边界

入口为 `scenes/main_menu.tscn`。旧战场仍可独立运行：`./run.command --scene res://scenes/main_arena.tscn`。

`CombatContext` 为正式战场与演武提供局部单位、反射面、战术和战斗信号，演武不改变正式经济、人口或终端状态。`main_arena.tscn` 只包含根节点和脚本，地图、碰撞、单位、特效、原生 HUD 均由代码构建。游戏运行没有外部图片、音频或字体文件；仓库截图仅用于文档展示。`GameSettings` 负责本机设置，`MatchSession` 负责运行内选图与一次性开局请求，`MapCatalog` 提供地形与预览共用定义。`SignalBus` 负责事件，`TacticalBrain` 负责规则编译，兵种数值位于 `scripts/core/unit_catalog.gd`。

当前交付是本机可玩的单人 MVP，不包含多人联网、战局存档、音频、签名安装包或内置 LLM 服务账号；可选 LLM 编译需自行配置兼容接口，也未承诺旧版 Godot 4.3 兼容性。

原始需求文档保持原样。AI 实验室升级前的源码快照为 `artifacts/pre-ai-lab-source-backup.tar.gz`，此前另保留 `artifacts/pre-launcher-source-backup.tar.gz`，另保留 V1 快照。回滚前关闭游戏，将快照解压到独立目录，使用 Godot 导入其中的 `project.godot` 运行旧版，保留当前工程以便恢复。不要向当前目录覆盖式解压，以免遗留本轮新增脚本。回滚不删除本机设置或引擎，引擎无需重装。本项目不读写其他项目或系统配置。
