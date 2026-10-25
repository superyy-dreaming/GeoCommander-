# 战术执行与编辑器排查

修改编排、实验持久化或地图叠层时阅读。

- AI生成按“请求已发起、完整响应、本地校验、地图校验、预览、显式应用”分阶段。`LLMService.start()`只返回请求状态，不包含program；不得在响应到达前读取program。
- Godot JSON数字读取为浮点值，`Array.has()`枚举匹配可能区分数值类型。版本、队伍编号先用有限数值及明确比较校验，再转换；不要因`1.0`与整数枚举不匹配而把正常存档备份为损坏文件。
- `_draw()`只消费现有字体、主题和状态，不调用会写Theme属性的工厂。全局Theme变更可能触发布局和重绘，绘制中写主题会形成反馈循环。字体在稳定生命周期获取，字号变化使用现有全局设置。
- 编排输出优先于普通追击、编队和撤退。每单位每帧只计算最终移动意图；方向段不加射线转向，目的地段共享路由。中断恢复应恢复时间、游标和掩体，并清除上一处理步骤的移动输出。
- 生成合法JSON不能等价于行为正确。至少回放方向、时长、真实伤害、中断和失败分支；模型与本地模拟的结果分开记录。

验收入口：`tests/tactic_plan_extended.tscn`、`tests/tactic_plan_llm.tscn`、`tests/tactic_plan_visual.tscn`。真实HTTP不使用固定帧加速；生成结果可另行离线固定帧回放。

地图与交互机关改动时，先读取`docs/map-overhaul.md`：地图空间以`MapCatalog.SPACE_VERSION`为准；迁移必须备份并按来源空间版本执行一次，不能按文件名判断坐标尺度。机关仅用所属`CombatContext`的模拟时钟，正式Flux只能由`MainArena`结算。隐匿影响感知列表，不得过滤真实伤害实体；分光寻敌遵守感知，伤害与绘制消费同一`BeamTrace.segments`。传送先检查出口，再原子扣次数，保留技能动作但清除跨传送段冲刺轨迹。验收入口为`tests/map_overhaul_runner.tscn`和六图`tests/navigation_probe.tscn`。
