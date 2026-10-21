# GeoCommander-

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

## 开始界面与三张地图

启动后进入首页，可选择“单人游戏”“多人游戏”“设置”，或通过独立入口进入“兵种演练”。多人页面仅展示开发中的创建与加入菜单，多人菜单不会发起网络请求。

单人页提供三张全部解锁的地图，左侧选择，右侧预览实际地形，再点击“进入战前准备”。三图具有相同兵种、经济与胜负规则：

| 地图 | 特点 |
|---|---|
| 均衡前线 | 原有基地掩体、中心斜柱、四处晶簇与两处熵减区 |
| 双翼迂回 | 两面中心长墙，上下路线适合包抄 |
| 折光阵列 | 开放中场与六处晶簇，突出折射协同 |

选图在本次程序运行内保留，重新开局沿用当前地图；退出程序后默认均衡前线。准备矩阵仍可编辑后开战。战中返回首页需要确认，确认期间暂停，取消后继续。

## 兵种演练

首页“兵种演练”提供五兵种真实 HP、速度、射程、费用和技能冷却；“协同需求”为说明评级，不参与结算。低于1600px时名册改为横向选择条，档案独立滚动，演武完整等比缩放。

独立物理世界中的演武可切换自动循环、手动普攻和技能、重置。每1.5秒尝试普攻、每3.5秒尝试技能，当前动作结束后再触发。演示刷新冷却与站位，正式数值保持 UnitCatalog 配置。六边形没有直接普攻。

“应用为默认开局指令”经过真实编译后只在本次运行保留，返回首页和重开不清除，退出程序后恢复默认。仅选择兵种不保存指令。“选择地图”进入单人页，“返回首页”退出演武并清理上下文。

菜单支持鼠标、Tab / Shift+Tab 和 Enter / Space，滚动区域跟随焦点。

提示词实验室提供五兵种独立草稿、AI JSON 校验、三图双方自由布阵与预设、同种子默认对照、实际统计和规则读数。“应用当前兵种为开局”只替换当前兵种，战前矩阵直接保留已编译规则。

## 本机设置

首页和战场顶部都可打开设置，包含显示、界面、LLM、操作与关于四页。战中打开会暂停单位、经济、计时和冷却，关闭恢复打开前的暂停状态。字号调整保留战术草稿和输入内容。

- 窗口或全屏；窗口尺寸1280×720、1440×810、1440×900、1920×1080。默认1440×810，不适合当前屏幕的尺寸不可选。显示变化需在15秒内确认，取消或超时恢复。
- 字号100%、115%、130%，覆盖菜单、档案、演武读数、HUD、矩阵与确认窗，不改变世界和单位尺寸。
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

战中终端继续采用本地关键词解析，提交会替换整队战术。兵种演练中的“提示词 · 布阵验证”可通过自行配置的 OpenAI 兼容服务将自然语言编译为单兵种条件 JSON。完整操作、规则与 API 配置见 [AI 提示词实验室](docs/ai-laboratory.md)。Key 仅保留本次运行。

## 战术地形

三张地图均按中心180°对称生成，掩体和晶簇数量随地图变化；每张地图保留两片熵减区。掩体阻挡移动、冲刺、弹体和激光；晶簇阻挡双方单位和普通弹体，激光按真实晶面法线折射。护盾每次增伤 35%，晶簇每次增伤 25%，最多两次折射、总长最多 750px，同次施法对同目标仅结算一次。

熵减区内主动移动及冲刺速度乘以 0.65，与超频相乘，重叠区域不进一步减速；拉拽与击退保持独立物理速度。琥珀色轮廓表示减速。AI 使用三路可见性路网和中心、左右 ±38° 三射线处理绕行。

“中路推进 / 走中路 / mid lane”偏向 Y=675；“分推 / 南北包抄 / split push”按部署序号分配南北路；“利用地形折射 / 晶簇折射 / crystal bounce”让菱形寻找可命中的晶簇发射位。

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
./run.command --scene res://tests/performance_runner.tscn -- --geo-test --launcher
./run.command --scene res://tests/launcher_visual_runner.tscn -- --geo-test
python3 tests/encode_captures.py launcher-visual-report.json
```

最后一条仅用于 QA 截图，需要 NumPy 和 Pillow。它把 Godot 的真实 HDR 线性帧缓冲编码成 sRGB PNG，不增加、修改任何画面元素。游戏运行不依赖 Python 或第三方库。

`artifacts/` 保存测试日志、截图与报告，`.godot/` 保存引擎缓存，两者均不属于运行源码。仓库仅保留 `artifacts/` 中八份不含凭据的真实模型 JSON 回放样例，其余日志、截图、报告与源码快照为本机验收产物，不随 Git 分发；验证文档中的这些产物链接需在本机查看或运行对应测试重新生成。AI 实验室验证见 [本轮验证](docs/ai-laboratory-verification.md)。此前验证记录见 [首页、地图与设置验证](docs/launcher-verification.md)，旧版记录保留在 [V2 验证](docs/verification.md)。

克隆后可离线回放已验证的模型输出，无需 API Key：

```sh
./run.command --headless --fixed-fps 60 --disable-vsync --scene res://tests/real_llm_runner.tscn -- --replay
./run.command --headless --fixed-fps 60 --disable-vsync --scene res://tests/boundary_tactic_runner.tscn -- --replay
```

上述固定帧参数仅用于保存的 JSON 战斗回放。向真实供应商发起 HTTP 请求时不要使用固定帧或倍速参数。

SiliconFlow / DeepSeek-V4.1-Flash 的真实提示词生成、条件边界与实际技能验证，以及本轮修复和复现方式，见 [真实模型验证](docs/real-llm-verification.md)。

三角已支持“沿边界绕后、用冲刺赶路、优先消灭菱形”的完整提示词；指定SiliconFlow模型采用实测的非思考JSON模式。操作、原文和生成与实战证据见 [边界绕后验证](docs/boundary-tactic-verification.md)。更新源码后需要重启游戏再生成。

## 工程与边界

入口为 `scenes/main_menu.tscn`。旧战场仍可独立运行：`./run.command --scene res://scenes/main_arena.tscn`。

`CombatContext` 为正式战场与演武提供局部单位、反射面、战术和战斗信号，演武不改变正式经济、人口或终端状态。`main_arena.tscn` 只包含根节点和脚本，地图、碰撞、单位、特效、原生 HUD 均由代码构建。没有外部图片、音频或字体文件。`GameSettings` 负责本机设置，`MatchSession` 负责运行内选图与一次性开局请求，`MapCatalog` 提供地形与预览共用定义。`SignalBus` 负责事件，`TacticalBrain` 负责规则编译，兵种数值位于 `scripts/core/unit_catalog.gd`。

当前交付是本机可玩的单人 MVP，不包含多人联网、战局存档、音频、签名安装包或内置 LLM 服务账号；可选 LLM 编译需自行配置兼容接口，也未承诺旧版 Godot 4.3 兼容性。

原始需求文档保持原样。AI 实验室升级前的源码快照为 `artifacts/pre-ai-lab-source-backup.tar.gz`，此前另保留 `artifacts/pre-launcher-source-backup.tar.gz`，另保留 V1 快照。回滚前关闭游戏，将快照解压到独立目录，使用 Godot 导入其中的 `project.godot` 运行旧版，保留当前工程以便恢复。不要向当前目录覆盖式解压，以免遗留本轮新增脚本。回滚不删除本机设置或引擎，引擎无需重装。本项目不读写其他项目或系统配置。
