# AI 提示词实验室与条件战术验证

验证日期：2026-10-20。Godot `4.7.2.stable.official.ed1daf0bf`，macOS / Apple M5，Forward+ / Metal 4.0 / 2D HDR，Retina 2×。入口仍为 `scenes/main_menu.tscn`，双击 `run.command` 启动。通过“兵种演练 → 提示词 · 布阵验证”进入实验室；设置新增 LLM 页。

## 实现范围

五兵种分别保存提示词、有效 JSON、来源模型和已应用实验规则。AI 生成与手动 JSON 均经过同一版本、字段、枚举、范围、嵌套和兵种能力校验。最多12条规则、32个条件节点、4层深度和4096字符提示词；不执行生成代码，不在失败后转用关键词。按约0.15秒取得基础目标与事实，自上而下执行第一条成立规则。原地防守、主动撤退、保留或尝试技能仍使用真实碰撞、冷却、控制和合法目标检查。

布阵页提供三图、双方放置/拖动/删除、初始生命与朝向、标准及五类协同预设。每方最多30单位、2个六边形，碰撞落点统一检查。使用独立 `CombatContext` / `World2D` 和局部生命周期，蓝方应用实验规则，红方固定默认；推进、编队、避障、伤害、治疗及技能复用正式实现。重跑与默认对照保留同一初始阵容和种子。1×速度、正式冷却，基地毁、一方单位全灭或120秒结束。

“应用当前兵种为开局”只合并当前兵种，其他兵种保持，仅本次进程有效。战前矩阵显示实际编译 JSON，不重新关键词解析覆盖。战中关键词提交继续明确替换整队战术。固定演武与旧战场入口保留。

LLM 使用异步 OpenAI 兼容 `GET /models` 与非流式 `POST /chat/completions`。模型列表失败可手填；测试使用选定模型。请求按拥有者、配置代次及请求对象身份隔离，取消与过期回调不会写回。保持TLS验证，响应限1MiB，默认30秒，不自动重试或跟随重定向。Key仅运行内存，连接文件只写URL/模型，实验文件只写白名单实验数据。保存失败和重试成功有独立反馈；无效实验原文件备份失败时拒绝覆盖。游戏恢复默认不删除实验或LLM连接。

## 编译与行为断言

无界面导入通过；69个脚本在真实项目、Autoload上下文中编译，0失败。检查实际日志的完成标记及错误，未仅依赖进程退出码。原255项保留，本轮新增284项，总计 **539项通过、0失败**。规则集的95项已包含本地HTTP模拟子集，未重复计算。

| 验证集 | 通过 | 证据文件（artifacts/） |
|---|---:|---|
| 原MVP规则 | 76 | ai-lab-regression-mvp.log |
| V2上下文、战术、演武 | 61 | ai-lab-regression-v2.log |
| V2真实技能、反射与地形 | 13 | ai-lab-regression-combat.log |
| 场景切换与生命周期 | 12 | ai-lab-regression-flow.log |
| 三图双向三路通行 | 18 | ai-lab-regression-nav.log |
| 首页、地图、设置与暂停 | 60 | ai-lab-regression-launcher.log |
| 旧设置独立进程读取 | 1 | ai-lab-regression-restart.log |
| 旧原生操作流程 | 14 | ai-lab-regression-native.log |
| 条件规则、正式/实验一致性、HTTP模拟 | 95 | ai-lab-rules.log |
| 实验室布阵、三图预设与界面状态 | 167 | ai-lab-flow.log |
| 实验写入与独立进程重启读取 | 2 | ai-lab-persistence-write.log、ai-lab-persistence-read.log |
| 新原生鼠标、焦点、取消与持续读数 | 20 | ai-lab-native-flow.log |

新增规则验证覆盖优先级及等值边界、all/any/not、越权字段、非法能力、版本/类型/范围、数量与深度限制、单兵种合并、旧关键词整队替换及开局保留、战前矩阵实际 JSON。三图上同一低血规则在正式与实验单位产生相同动作；验证实际过杀统计、全灭/超时结束、独立经济和暂停。同种子重置分别比较三图的90物理帧位置、生命和技能冷却。

布阵流程遍历三图六套预设及全部落点，检查单位/六边形上限、运行时禁止编辑、重置和默认对照保留站位、独立草稿、无效JSON不应用、弹层暂停与内容保留。独立进程读取确认提示词/规则/布阵保留，而Key和正式开局不跨进程。测试使用 `test_*` 文件，不覆盖正式用户数据。

另以实际按钮信号完成首页 → 兵种演练 → 实验室 → 返回演练的场景烟测，退出后无暂停与待处理请求。日志为 `ai-lab-navigation-smoke.log`；此烟测不重复计入539项断言。

## 本地接口模拟与真实连接边界

`tests/llm_mock_server.py` 只监听 `127.0.0.1:18741`，不记录请求头和请求体。验证获取模型、列表不可用后手填仍可POST、合法生成、鉴权失败、模型不可用、无效响应/JSON、拒绝重定向、响应超限、超时、取消、配置改变及无效URL后的过期请求丢弃、Key不落盘、保存失败与显式重试。

原生场景通过此服务真实发起HTTP、显示生成结果并应用自主战斗；另检查切换兵种取消旧响应。**未配置真实供应商凭据，因此没有做真实供应商烟测**。本地模拟通过不代表任意供应商或模型可用；用户需在游戏“设置 → LLM”输入Key，获取或手填模型并点击“测试连接”，再生成实际提示词。不要把Key发到聊天中。未对外部TLS服务故障做故障注入，TLS验证使用Godot默认实现。

## 三地图完整对局与性能

固定种子 `20261020`，正式战场蓝方五兵种均带条件规则，测试驱动补兵及全局技能。每图峰值60单位，无负资源、人口或六边形越界，均以基地摧毁正常结束，`failures=[]`。三次均为红方获胜；结果证明整局可完成，不作为战术平衡或胜率结论。

| 地图 | 模拟秒数 | 物理帧 | 峰值弹体 |
|---|---:|---:|---:|
| 均衡前线 | 319.12 | 19148 | 10 |
| 双翼迂回 | 131.47 | 7889 | 12 |
| 折光阵列 | 70.42 | 4226 | 8 |

证据为 `ai-lab-simulation-{balanced,flanks,refraction}.json` 及同名日志。地形、通行、部署与传送的旧规则由保留回归覆盖，新实验落点另在三图验证。

60单位压力场景为每兵种12条规则，双方均安装条件战术；将生命提高至100000维持数量，移动、技能和地形使用正式逻辑。预热3秒，采样3002ms：平均 **114.59 FPS**，物理耗时平均13.09ms，1080次决策，条件评估累计116.322ms，路由47.149ms，射线35.060ms。本机平均达到55FPS目标；这是短窗口采样，不能代表其他设备或整局最低帧。证据为 `ai-lab-performance.json/.log`。

## 原生界面与独立复核

`ai-lab-visual-report.json` 记录14张实际Metal截图，覆盖1280×720、1440×900、1920×1080及100%/130%字号、三图、提示词、JSON、运行规则、生成与错误、LLM设置。`ai-lab-focus-report.json` 另有3张实际焦点及持续阅读截图。屏幕为Retina 2×；本轮共17张，布局扫描 `overflow=[]`。原始RGBH `.pixels` 经 `tests/encode_captures.py` 线性到sRGB编码，未增添画面元素；`ai-lab-contact.png` 仅为这些截图缩略总览。

1280/1440为编辑与战场两栏，JSON/规则/事件使用页签，1920的100%和130%均展开第三栏。编辑正文和长反馈独立滚动，取消位于固定标题行；应用动作保留可见。UI处于CanvasLayer10，不受世界HDR光晕影响。规则文本只在变化时更新并保留滚动、光标和选择；原生流程实测等待2.1秒后仍保留阅读位置。

原生实际输入验证模型字段、列表、获取、测试、忙时取消的Tab可见性、Shift+Tab、Esc恢复原焦点与暂停态、弹层点击不穿透、最小窗口130%下真实鼠标取消、低动效就地更新。事件页无记录时明确空态，不填入演示数据。

使用ui-ux-pro-max与impeccable继承现有Godot主题；没有使用Web组件库、浏览器QA、图像生成或未加载的Apple设计skill。环境没有预注册专用reviewer/documenter，按技能要求使用全新独立代理执行同等清单，原生GDScript不运行HTML/CSS detector。首轮及两批定向修复评分记录在 `artifacts/ai-lab-finish-review.md`。最终 disposition 为 **ship**，F1至F8均评分 **resolved**；最后评分仅覆盖列出的修复及其相关回归，不扩大为所有平台或辅助技术认证。设计记录在 `DESIGN.md` 与 `.impeccable/design.json`。

## 复现命令

先在独立终端启动本地模拟服务，完成后按Ctrl+C停止：

```sh
python3 tests/llm_mock_server.py
```

在项目目录顺序运行：

```sh
./run.command --headless --import
./run.command --headless --scene res://tests/check_scripts.tscn
./run.command --headless --scene res://tests/ai_lab_runner.tscn -- --http-mock
./run.command --headless --scene res://tests/ai_lab_flow.tscn
./run.command --headless --scene res://tests/ai_lab_persistence.tscn
./run.command --headless --scene res://tests/ai_lab_persistence.tscn -- --read
./run.command --scene res://tests/ai_lab_native_flow.tscn -- --geo-test
./run.command --scene res://tests/ai_lab_visual.tscn -- --geo-test
python3 tests/encode_captures.py ai-lab-visual-report.json
python3 tests/encode_captures.py ai-lab-focus-report.json
./run.command --scene res://tests/ai_lab_performance.tscn -- --geo-test
./run.command --headless --fixed-fps 60 --disable-vsync --scene res://tests/simulation_runner.tscn -- --conditional --map=balanced
./run.command --headless --fixed-fps 60 --disable-vsync --scene res://tests/simulation_runner.tscn -- --conditional --map=flanks
./run.command --headless --fixed-fps 60 --disable-vsync --scene res://tests/simulation_runner.tscn -- --conditional --map=refraction
```

旧255项命令见README与上一轮验证。测试会改独立测试文件，原生QA必须带 `--geo-test`。游戏本身不依赖Python，截图编码依赖NumPy/Pillow。

## 回滚与剩余限制

源码回滚：`artifacts/pre-ai-lab-source-backup.tar.gz`，SHA-256 `458a9121112a909ed08d8c11f65e6b691036e4e9570358f12d6ad18ec7ae6831`。关闭游戏，解压至新的空目录并导入其中 `project.godot`，保留当前工程。不要覆盖当前目录，避免遗留新增脚本。回滚不修改引擎、旧游戏设置或实验数据。当前目录不是Git仓库，没有创建commit。

原始需求与升级文档未改。SHA-256：`gemini-code-1792472151386.md` 为 `13197ab7d909b5d95b975be6670d63d9bdb5587fce6e46211cc4c734c7304096`，`AGENT_PATCH_V2.md` 为 `15fedbf276e7496f8503474acc4b04541bdc0b37fd82a8fdb0ba6635faea1ec2`。

剩余边界：未验证真实供应商、其他操作系统、完整中文输入法候选窗/组合输入、屏幕阅读器或长时间性能稳定性。没有多人联网、音频、外部素材、战局存档、任意脚本或原生钥匙串依赖。实验文件是版本化本机数据；连接Key退出后需要重新填写，正式开局仍需每次运行明确应用。
