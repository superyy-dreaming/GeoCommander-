# GeoCommander V2 本机验证记录

后续首页、三地图与本机设置升级的验证见 [launcher-verification.md](launcher-verification.md)。本文件保留 V2 阶段的历史结果。

验证日期：2026-10-20。原始需求和 `AGENT_PATCH_V2.md` 已与 V1 源码快照逐字节比较，均未修改。

## 环境与工程

macOS / Apple M5（Apple9）/ Retina 屏幕缩放 2×，Godot `4.7.2.stable.official.ed1daf0bf`，Forward+、Metal 4.0、2D HDR 和 4x MSAA。引擎独立安装于 `~/.local/share/geocommander/tools/4.7.2/Godot.app`，未改系统 PATH。游戏只使用系统字体、几何绘制和 shader，无网络、外部图像或音频依赖。

- 无界面导入通过：`artifacts/v2-import.log`。
- 正常项目上下文编译 43 个脚本，0 失败：`artifacts/v2-script-check.log`。
- 原 76 项回归全部通过：`artifacts/v2-tests.log`。旧规则夹具关闭地形，并显式允许测试预设站位；正式部署始终检查落点。
- V2 演武、解析器、开局配置、上下文隔离等 61 项通过：`artifacts/v2-feature-tests.log`。
- 新地形与战斗 13 项通过：`artifacts/v2-combat.log`。
- 真实菜单/战场切换、确认暂停和取消恢复、返回与重开保留开局配置 11 项通过：`artifacts/v2-flow.log`。
- 双向北中南三路 6 组独立物理世界通行通过：`artifacts/v2-navigation.log`。三角单位约 375 至 397 帧到达对侧，测试上限 1800 帧。

共 167 项规则、战斗、流程和通行断言/用例通过。机器可读汇总：`artifacts/v2-validation.json`。不能仅根据 Godot 退出码判断成功；汇总同时要求出现结果标记且没有 SCRIPT ERROR / ERROR / FAIL。

`--check-only` 不提供 Autoload 环境，仅适用于独立脚本。全工程检查入口是 `tests/check_scripts.tscn`，不能使用单独 SceneTree 脚本的缺少单例错误代替真实项目检查。

## 规则与真实技能证据

- 演武使用独立 `World2D` 和局部 `CombatContext`；切换、重置和离开使旧代次回调失效，正式战术、双方资源和人口保持隔离。
- 五兵种真实普攻/技能入口均被演武调用。验证 110 背刺、方形护盾被真实敌弹扣除 26 耐久、友方激光借盾造成 114.75 伤害、引力拉拽/坍缩与三友军真实回血。六边形没有虚构普攻。
- 自动循环能够同时触发普攻与技能；关闭循环后当前动作完成但不追加动作，重置保留开关状态。
- 混合晶簇/护盾折射逐段倍率 1.25 / 1.35，总路径最多 750px，最多两次反射，折返同目标只结算一次。掩体阻挡真实激光、弹体及冲刺；两队均被晶簇阻挡。
- 减速重叠不叠乘，与超频相乘，冲刺同样应用倍率，离区与区域释放清理来源。部署和拓扑转移无安全落点时不扣费、不进入冷却、不部分传送。
- 中英完整短语、独立冲突顺序、均衡恢复新字段、运行内开局配置生命周期均有针对性断言。

## 固定种子完整对局

种子 `20261020`。双方扩充到峰值 60 单位，蓝方测试驱动补兵与指令、红方使用正式 AI，运行正式地形。该用例验证持续运行及结束流程，不证明兵种平衡或胜率。

本轮模拟 167.32 秒、10040 个物理帧，实际 10.099 秒。红方摧毁蓝方核心后进入结束态，峰值弹体 11，`failures` 为空。资源和人口未越界。证据：`artifacts/simulation.json`、`artifacts/v2-simulation.log`。

## 原生画面与性能

Metal 原生渲染批量覆盖 1280×720、1440×900、1920×1080，运行于 Retina 2× 屏幕。33 个状态截图包含每个尺寸的五份兵种档案、四种普攻、五种技能、低动效、准备矩阵、地形战斗、放弃确认及结算。报告 `artifacts/v2-visual-report.json` 的可见控件越界为空；滚动档案内部内容按裁剪容器处理，不把可滚动内容误算为越界。

HDR 帧缓冲为 RGBH。`tests/encode_captures.py` 保留 `.pixels`，按实际通道格式执行标准线性到 sRGB 编码，未添加画面元素。属性条截图等待 0.25 秒过渡结束，避免把合法动画中间值当成配置值。同步截图读回的帧率不用于压力测试。

关键截图：`v2-menu-triangle-1280x720.png`、`v2-menu-diamond-1920x1080.png`、`v2-skill-triangle.png`、`v2-skill-square.png`、`v2-skill-circle.png`、`v2-skill-diamond.png`、`v2-skill-hexagon.png`、`v2-battle-1280x720.png`、`v2-return-confirm.png`、`v2-result.png`，均位于 `artifacts/`。

性能场景单独运行，测试生命提高到 100000 以维持 60 个存活单位，正式移动、技能、弹体和避障持续运行。预热三秒，每段采样约两秒，统计如下：

| 场景 | 平均 FPS | 平均物理耗时 | 平均 process 耗时 | 路由 / 射线总耗时 |
|---|---:|---:|---:|---:|
| 60 单位持续战斗 | 60.00 | 9.16ms | 12.89ms | 36.07 / 24.45ms |
| 同场景低动效 | 60.08 | 9.00ms | 13.72ms | 27.70 / 26.69ms |

第一段含 218 次路由、18456 条避障射线，达到本机平均 ≥55 FPS 的目标。路由和射线耗时为整个采样窗口内累计值。证据：`artifacts/v2-performance.json`、`artifacts/v2-performance.log`。短时采样不代表所有设备或所有战局阶段的最低帧率。

最新整批重采以 `artifacts/v2-visual-report.json` 为准。此前 `v2-battle-visual-report.json` 是地形朝向修正后的八状态专项记录。两批报告均无控件越界。

## 独立界面收口

使用全新上下文的独立 reviewer 按 Impeccable 收口契约检查真实原生截图和实现。运行环境没有预注册的专用 reviewer，使用同一审查清单作为等价替代；原生 GDScript 不运行仅检查 HTML/CSS 的检测器。首次独立审查为 `fix`，唯一实质项是光束淹没伤害数字和盾面。已将演武读数移到独立 CanvasLayer 10、增加深色底并避让，减轻共享光束光晕并标出实际折射点。重采相同 33 个状态后，reviewer 将该项评分为 `resolved`，未发现修复引起的实质回归，修复复核 disposition 为 `ship`。该 verdict 只覆盖列出的修复项和回归检查。完整记录：`artifacts/v2-finish-review.md`、`artifacts/v2-finish-verdict.md`。

## 复现

从项目根目录运行 README 的验证命令。性能场景应单独启动，避免与截图或其他重负载进程竞争。可以直接运行 `scenes/main_arena.tscn` 和各测试场景，不依赖菜单。

## 限制与回滚

- 原生中文显示、Viewport 文本输入与 Enter 提交有回归证据；未自动化验收 macOS 输入法候选窗和完整组合输入过程。日志中的 `IMKCFRunLoopWakeUpReliable` 为系统输入法消息，没有 GDScript 堆栈，输入法影响仍需实机手测。不能据此宣称系统 IME 已验收。
- Godot 文档站访问曾返回 403，相关 `Viewport.world_2d`、`use_hdr_2d` 与输入 API 改用[官方源码类参考](https://raw.githubusercontent.com/godotengine/godot/master/doc/classes/Viewport.xml)核对，最终以本机 4.7.2 编译与原生运行验证兼容性；未将文档站不可访问误记为 API 不可用。
- `ui-ux-pro-max` 与 `impeccable` 用于可读性、状态、焦点和界面工艺基线，原生游戏视觉以用户批准的几何规格为准。未使用 Web 组件库、浏览器截图、图片生成或不可见的 Apple 设计 skill；本轮为 Godot 游戏，不采用 Apple 品牌视觉。
- 开局设置仅存在本次运行内，没有存档。没有真实 LLM、联网、音频或安装包，LLM 接口明确返回 `NOT_CONFIGURED`。
- V1 源码快照：`artifacts/v1-source-backup.tar.gz`。回滚前关闭游戏，先解压到独立目录核对，再恢复入口、共享战斗接口与地形相关源码；不覆盖引擎、外部目录或用户数据。`.godot/` 为可重建缓存，`artifacts/` 为验证产物并由 `.gdignore` 排除导入。
