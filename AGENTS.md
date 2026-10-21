# GeoCommander 项目规则

- Godot 4.7.2 标准版、GDScript、Forward+、Apple Silicon Metal。入口 `project.godot`，启动 `./run.command`，规则测试 `./run.command --headless --scene res://tests/test_runner.tscn`。
- 原始需求文档保持只读。全部游戏视觉由几何与 shader 生成，不引入图片、音频或打包字体。字体使用 `SystemFont`。
- `SignalBus`、`TacticalBrain` 是 Autoload。重开必须同时恢复对局与战术状态，矩阵和终端必须经过同一提交入口。
- 单文件 `--check-only` 不提供 Autoload 上下文。全工程编译使用正常项目启动的 `tests/check_scripts.gd`，并结合导入与规则场景；不要将依赖 Autoload 的脚本单独检查产生的上下文错误当作项目解析错误。
- 资源、人口、技能冷却只由 `MainArena` 结算；无效操作不得扣费；结束态禁止继续战斗与经济结算。
- 拉拽、击退和冲刺通过物理移动处理；护盾共用第 3 层，以友军碰撞例外放行，包括后生成的友军。
- `Node.owner` 是引擎属性，不能重定义成队伍编号。能源棱镜使用 `capture_owner`。
- 世界 HDR 发光只影响 Canvas 0，HUD 使用 CanvasLayer 10。HDR 帧缓冲截图须经过线性到 sRGB 编码后用于视觉验收。
- 运行时纯 Godot，无 Web 构建流程。修改战斗逻辑后运行规则测试及固定种子模拟；修改 UI 后运行原生视觉场景。具体验证与边界见 `README.md` 和 `docs/verification.md`。

- 演武与正式战场共用 `CombatContext`，单位、基地、反射面和协同信号按上下文查询；禁止用全树组扫描决定敌我、治疗、目标或人口。
- 地形与护盾统一通过物理层处理，激光使用 `BeamTrace` 的实际表面法线与逐段倍率；禁止在折射后自动扭转方向追踪目标。
- 导航缓存和稳定绕行侧以物理帧计时，避免加速模拟与原生运行行为分歧。全工程编译入口为 `tests/check_scripts.tscn`，需要真实 Autoload 上下文。

- 地图实体与预览共用 `MapCatalog`，三图通行用 `tests/navigation_probe.tscn` 验证。路径游标只有在下一段满足净空时才可跳过拐点；不能仅按距离提前跨越障碍角点。
- 每单位每帧先确定最终移动意图，再查询路由；缓存须区分意图和目标身份，追击切换撤退立即失效。修改后运行 `tests/movement_intent_runner.tscn`，避免中间编队或追击查询占用撤退路径。
- LLM的HTTPRequest保持默认非阻塞异步模式；线程模式取消时会等待阻塞socket线程，不能通过放宽超时解决。更改请求生命周期后运行 `tests/llm_lifecycle_runner.tscn`（需本地HTTP夹具），同时检查取消耗时、主循环间隙和过期响应。
- 真实HTTP请求验证使用正常时间，不带 `--fixed-fps` 或倍速；引擎定时器随模拟时间推进，会制造毫秒级假超时。网络生成与固定帧战斗回放分开，真实超时用墙钟耗时核实。
- 全局字号复用稳定生命周期的 Theme/SystemFont，并原地更新；不要在设置事件中反复销毁重建字体。字号、显示回退与暂停须运行 `tests/launcher_native_flow.tscn -- --geo-test`，检查运行日志无字体缓存错误。
- `SystemFont.font_names` 选择首个匹配字体，不能当成逐字回退链；macOS 的 PingFang 集合可能解析为 HK 字面。中文 UI 通过 `Font.fallbacks` 显式提供系统简体字形，修改字体后须验证“敌、远”等字与实际截图。
