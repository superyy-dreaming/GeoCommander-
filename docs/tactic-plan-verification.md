# 精细战术编排验证记录

验证日期：2026-10-21。环境：Godot 4.7.2 Stable、Apple M5、Metal Forward+、2D HDR、Retina屏幕（scale 2.0）。运行入口、引擎及原始需求文档未更换。

## 行为与兼容

| 检查 | 结果 |
|---|---|
| 无界面导入与全工程脚本加载 | 88个脚本，0失败 |
| 原有规则、地图、导航、场景、实验室、HTTP生命周期和历史模型JSON回放 | 762项断言通过，日志为`artifacts/tactic-v2-regression-*.log` |
| v2扩展回归 | 135项通过，含最初52项；`artifacts/tactic-v2-extended.json` |
| v2本地HTTP生成、非法输出及真实UI异步请求 | 15项通过，`artifacts/tactic-v2-llm-mock.json` |
| 真实v2 JSON离线回放 | 10项通过，`artifacts/tactic-v2-llm-replay.json` |
| 实验写入、退出后重新读取 | 各1项通过，`artifacts/tactic-v2-persistence-{write,read}.log` |
| 新原生路径、技能调试与开局操作 | 14项通过，`artifacts/tactic-v2-native.json` |
| 原生实验室既有流程 | 20项通过，`artifacts/tactic-v2-native-legacy.log` |

覆盖方向与双方前后、时间与暂停、EMP、循环、单次物理帧、运行到下一步骤及方案结束、中断优先级/恢复/重新触发、目标丢失、无路径、无掩体、三图掩体与探出/航点、真实技能、非法施放不扣冷却、旧JSON、兵种独立设置、新部署和新对局时钟。

新增存档测试从真实v1文件读取、备份后写v2、再次读取，验证原提示词和v1程序保留，无效JSON草稿与有效程序分开恢复。超长草稿和写入失败不能覆盖已有实验，失败保留内存并显示未保存。地图不匹配阻止开战；战前单独恢复相关兵种后可开战，其他兵种保留。

独立物理世界内以相同地图、站位、朝向、冷却和方案并行运行实验室与正式战场900帧，当前位置、步骤、访问次数及实际伤害一致。

核心方案在14.5秒内完成两轮绕后与真实110背刺，之后低于30%生命触发撤退。三图完整对局使用种子20261020、初始60单位，均以基地摧毁正常结束，无人口、资源或生命周期断言失败，见`artifacts/tactic-v2-simulation-{balanced,flanks,refraction}.json`。示例侧重演示编排，本轮三局均由红方获胜，不将胜率作为接口一致性的证据。

## 真实 SiliconFlow

服务：`https://api.siliconflow.cn/v1`；模型：`deepseek-ai/DeepSeek-V4.1-Flash`。真实请求以正常时间运行，没有使用固定帧或倍速网络测试。

最终12项检查通过，记录为`artifacts/tactic-v2-llm-real.json`。本轮复杂三角方案生成耗时4618ms，保留向上2秒、最多5秒等待、真实背刺瞄准、掩体循环和低血量中断；物理运行完成两次背刺，实际伤害220。提高伤害、永久隐身及免疫攻击的要求返回明确拒绝。凭据仅通过隐藏输入进入子进程内存，测试后清空。

首次模型输出虽合法，但添加了未要求的赶路冲刺，并错误使用基地前进方向瞄准背刺。第二轮暴露了`seconds`与条件等待上限的歧义。修复后：编译提示包含合法示例和禁止擅加动作的约束；条件等待强制使用`timeout`；背刺必须检查真实轨迹；重新请求和运行均通过。修复前报告另存为`artifacts/tactic-v2-llm-real-before.json`和`artifacts/tactic-v2-llm-real-second.json`，不会作为通过证据。

本轮真实v2正反样例聚焦三角复杂编排；五兵种技能共用实现由本地战斗断言验证，历史五兵种v1模型JSON继续回放。生成结果仍需检查语义和实战效果，本地校验不等于对任意自然语言意图的证明。

## 原生界面与性能

10张原生Metal帧覆盖1280×720、1440×900、1920×1080与100%/130%字号，包含步骤、路径、JSON、错误及执行读数。截图来自Retina屏幕，RGBH原始帧按线性到sRGB编码；`artifacts/tactic-v2-visual-report.json`记录编码、尺寸和溢出检查，最终溢出为0。

收口检查集中修复了绘制中刷新Theme形成的布局反馈，以及小窗口下步骤工具占据表单空间的问题。随后按实际键鼠操作复核路径添加/拖动/删除、撤销重做、墙体选择、生成期间编辑锁、文本焦点、单帧与下一步骤、局部开局应用及退出清理。旧原生流程继续验证设置遮挡、取消、切兵种过期回调、低动效和读数滚动保持。

代表截图：

- [1280×720、130%步骤](../artifacts/ai-lab-v2-steps-1280x720-130.png)
- [航点编辑](../artifacts/ai-lab-v2-path-large.png)
- [执行读数](../artifacts/ai-lab-v2-execution-large.png)
- [1920×1080、130%步骤](../artifacts/ai-lab-v2-steps-1920x1080-130.png)

60单位保持存活并执行掩体、探出、技能与循环；预热2秒，采样8003ms。平均59.98 FPS，平均物理处理11.03ms。采样内执行器557.309ms、路由215.279ms、射线107.120ms、掩体229.563ms，37次掩体/探出查询，5份缓存几何。掩体耗时属于执行器总耗时的一部分，不应相加。见`artifacts/tactic-v2-performance.json`。

性能采样采用4步实际循环，未穷尽128条件节点的所有最坏组合，也不代表所有硬件的帧率。原生文本操作日志中有macOS `IMKCFRunLoopWakeUpReliable`端口诊断；没有GDScript解析或交互断言失败。本轮没有用自动化代替人工输入法候选窗组合输入验收。

## 重跑与回滚

```sh
./run.command --headless --import
./run.command --headless --scene res://tests/check_scripts.tscn
./run.command --headless --scene res://tests/tactic_plan_extended.tscn --fixed-fps 60
python3 tests/llm_mock_server.py
# 在另一个终端中执行，不使用 --fixed-fps：
./run.command --headless --scene res://tests/tactic_plan_llm.tscn
# 历史真实结果离线回放可使用固定帧：
./run.command --headless --scene res://tests/tactic_plan_llm.tscn --fixed-fps 60 -- --replay
./run.command --scene res://tests/tactic_plan_native.tscn -- --geo-test
./run.command --scene res://tests/tactic_plan_visual.tscn -- --geo-test
python3 tests/encode_captures.py tactic-v2-visual-report.json
./run.command --scene res://tests/tactic_plan_performance.tscn -- --geo-test
```

真实测试入口同为`tactic_plan_llm.tscn -- --real`，凭据必须由父进程的隐藏输入放入`GEO_LLM_TEST_KEY`，不要写命令参数、脚本或文件。测试采用独立的`test_*`用户配置，不覆盖正式设置。

升级前源码快照：`artifacts/pre-tactic-v2-source.tar.gz`；升级后源码：`artifacts/tactic-v2-source.tar.gz`。回滚前关闭游戏，将升级前快照解压到独立目录，并用Godot导入其中的`project.godot`；保留当前工程，避免覆盖解压后遗留新增脚本。引擎、Key、本机设置及运行数据不进入源码快照，也不需要重置。原始两份需求文档SHA256未变，凭据扫描为0，见`artifacts/tactic-v2-secret-scan.json`。
