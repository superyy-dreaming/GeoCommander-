# 地图、机关与地形AI验证

本机Godot 4.7.2 Stable、Forward+、Metal 4.0、Apple M5、Retina 2×。实现与[操作说明](map-overhaul.md)对应。原始需求文档未编辑，本轮未提交或推送远端。

## 工程及行为

最终导入成功；真实Autoload上下文加载107个脚本，0失败。以下11组共920项行为检查全部通过，检查日志同时排查了SCRIPT ERROR、ERROR和FAIL，未只凭退出码判断。

| 场景 | 通过 |
|---|---:|
| `test_runner` | 76 |
| `v2_test_runner` | 61 |
| `v2_combat_runner` | 13 |
| `movement_intent_runner` | 60 |
| `launcher_test_runner` | 102 |
| `scene_flow_runner` | 12 |
| `tactic_plan_runner` | 61 |
| `tactic_plan_extended` | 159 |
| `ai_lab_runner` | 93 |
| `navigation_probe` | 144 |
| `map_overhaul_runner` | 139 |

[机器汇总](../artifacts/map-overhaul-verification.json)，[最终日志目录](../artifacts/map-overhaul-logs/)。

机关覆盖真实护盾35%→晶簇25%→分光的混合光路、分光继承两次反射预算、每分支650px、实际伤害最高段去重、不可感知目标不参与分光选敌、扫描与治疗冷却独立、准备/暂停/结束冻结、虫洞安全出口原子结算、传送冲刺不跨跨度伤害、闸门物理推离与受阻重试、反应堆伤害/待生成奖励/竞争拾取，以及地形释放清理。

迁移覆盖空间2乘0.75、空间1/3不缩放、备份先于保存、重读不重复迁移、无效候选和已应用原文保留且阻止开战、关键词按出现顺序覆盖。旧v1/v2、终端、开局生命周期和精细编排回放继续通过。

## 六图几何与通行

| 地图 | 实体数量（墙+晶簇+实体机关） | 最小实体轮廓间距 |
|---|---:|---:|
| 均衡前线 | 12 | 58.23px |
| 双翼迂回 | 8 | 172.54px |
| 折光阵列 | 15 | 139.00px |
| 盘旋堡垒 | 9 | 128.72px |
| 交叉火线 | 9 | 133.64px |
| 晶脉迷城 | 14 | 87.02px |

这不是所有单位必须经过的通道宽度。最大半径26px的六边形和高速三角分别验证六图、双方、三路，且各测试允许/禁止虫洞，共144次真实物理推进，全部到达；最慢2644物理帧。实体相交、ID、边界、镜像、V形凹轮廓分解和预览/物理实体数一致性通过。六图新标准阵容均能合法布置。

固定种子20261020，六图各完成一局，最高人口均为60，未发现运行错误：

| 地图 | 模拟时长 | 结果 |
|---|---:|---|
| 均衡前线 | 127.55秒 | 红方摧毁蓝方基地 |
| 双翼迂回 | 284.38秒 | 红方摧毁蓝方基地 |
| 折光阵列 | 102.97秒 | 红方摧毁蓝方基地 |
| 盘旋堡垒 | 236.23秒 | 红方摧毁蓝方基地 |
| 交叉火线 | 158.43秒 | 红方摧毁蓝方基地 |
| 晶脉迷城 | 321.10秒 | 蓝方摧毁红方基地 |

报告位于`artifacts/map-overhaul-simulation-<地图ID>.json`。这是功能回放，不代表阵营平衡结论。

## 原生布局与截图

`map_overhaul_native`最终399项通过、0失败、88张真实帧缓冲截图：六图×三窗口×三字号的54张选择页；六张准备、六张战斗、一张低动效预警；21张战场工具布局。窗口为1280×720、1440×900、1920×1080，字号100%/130%/180%。覆盖裁切祖先后的可见区域、页脚遮挡、独立HDR物理世界、预览无战斗节点、核心生命文字完整和顶部按钮不遮资源。

实验室原生布局168项通过，含五档字号往返、40%反馈区、固定按钮、弹层、上下文保留，以及本地HTTP夹具生成和应用流程。菜单45项通过，含Tab/Space/方向键/Esc、取消不丢草稿、弹层互斥和滚轮不穿透战场。模型请求使用127.0.0.1可控夹具，没有真实供应商新增机关生成烟测。

已批量采集后目视复核六图总览、1280×720/180%地图页、实验室长错误、折光阵列和晶脉迷城实战、最大字号战场工具页。集中修复战场底部横排撑出窗口、顶部文字/按钮重叠及新标准阵容落点，然后完成一轮确认。

- [六图总览](../artifacts/map-overhaul-contact.png)
- [小窗口180%地图页](../artifacts/map-native-crossfire-1280x720-180.png)
- [折光阵列战斗](../artifacts/map-native-live-refraction.png)
- [晶脉迷城预警](../artifacts/map-native-low-motion-warning-crystal_maze.png)
- [180%战场终端](../artifacts/map-native-tools-1280x720-180-1.png)
- [180%全局技能](../artifacts/map-native-tools-1280x720-180-2.png)
- [实验室长错误](../artifacts/ai-lab-layout-error-180.png)
- [完整地图截图清单](../artifacts/map-overhaul-native-report.json)

RGBH/RGBAH等真实格式按`tests/encode_captures.py`转换线性RGB到sRGB，没有补画或修改元素。Retina屏幕缩放为2×，截图分辨率按测试逻辑输出记录。

## 性能

1440×900窗口、Metal Forward+、关闭VSync，每图60个真实单位，预热3秒并采样8秒。夹具提高生命以维持60单位，不修改正式数值。最终样本如下：

| 地图 | 平均FPS | 最大帧间隔 | 路由总耗时 | 射线总耗时 | 感知总耗时 | 机关总耗时 |
|---|---:|---:|---:|---:|---:|---:|
| 均衡前线 | 110.17 | 21ms | 21.47ms | 77.08ms | 71.16ms | 150.56ms |
| 双翼迂回 | 108.32 | 22ms | 21.88ms | 82.10ms | 67.50ms | 124.03ms |
| 折光阵列 | 108.24 | 27ms | 230.73ms | 81.70ms | 66.50ms | 100.24ms |
| 盘旋堡垒 | 108.96 | 41ms | 217.48ms | 73.81ms | 68.01ms | 139.84ms |
| 交叉火线 | 108.31 | 36ms | 223.96ms | 79.20ms | 67.65ms | 132.58ms |
| 晶脉迷城 | 103.94 | 24ms | 65.29ms | 84.35ms | 75.62ms | 89.35ms |

全部超过55 FPS目标。渲染CPU平均约0.35–0.42ms；GPU监视器返回0，视为不可用，不宣称GPU零成本。类别计时存在包含关系，不应相加。前一轮基线225–250 FPS日志也保留；不同采样值仅描述各次运行，不用于归因。最终以[本轮报告](../artifacts/map-overhaul-performance.json)为准。

另测60个活跃精细编排：8.015秒平均318.78 FPS，执行器总1663.93ms、路由1139.24ms、射线71.82ms、掩体1247.35ms/222次。报告为`artifacts/tactic-v2-performance.json`；该夹具同样使用高生命维持负载。

## 未完成的环境验收

macOS处于锁屏，CUA明确返回“The Mac is locked and automatic unlock could not unlock it”。Metal窗口截图和自动布局可以运行，但系统全屏Space切换无法完成。游戏设置全屏测试20项中4项、直接Window.mode测试12项中2项未通过进入/倍率确认，均按本次失败记录保留；本轮没有重复实际绿色按钮点击。未据此修改全屏代码或增加等待参数。

此前真实系统绿色按钮16/16、直接入口12/12、设置20/20的历史证据见[全屏缩放验证](fullscreen-scaling-verification.md)，不能替代本轮复验。Mac解锁后依次运行下面三项，实际点击绿色按钮完成最后一项，才能关闭这项验收。其余工程、行为、地图布局、整局与性能验证已完成。

Godot文档站本次访问受限，相关接口核对采用官方仓库类参考XML，最终以本机4.7.2编译和原生运行验证为准。没有引入第三方UI依赖或外部素材。

## 复现与回滚

```sh
./run.command --headless --editor --import
./run.command --headless --scene res://tests/check_scripts.tscn
./run.command --headless --fixed-fps 60 --scene res://tests/map_overhaul_runner.tscn
./run.command --headless --fixed-fps 60 --scene res://tests/navigation_probe.tscn
./run.command --headless --fixed-fps 60 --scene res://tests/simulation_runner.tscn -- --map=crossfire
./run.command --scene res://tests/map_overhaul_native.tscn -- --geo-test
python3 tests/encode_captures.py map-overhaul-native-report.json
./run.command --disable-vsync --scene res://tests/map_overhaul_performance.tscn -- --geo-test
python3 tests/llm_mock_server.py
# 另一个终端，原生测试顺序运行：
./run.command --scene res://tests/lab_layout_native.tscn -- --geo-test
./run.command --scene res://tests/lab_menu_native.tscn -- --geo-test
# 解锁桌面后完成：
./run.command --scene res://tests/launcher_native_flow.tscn -- --geo-test
./run.command --scene res://tests/fullscreen_scale_native.tscn -- --geo-test
./run.command --scene res://tests/fullscreen_titlebar_native.tscn -- --geo-test
```

本机源码快照：[本轮前](../artifacts/map-overhaul-before-source.tar.gz)、[本轮后](../artifacts/map-overhaul-current-source.tar.gz)、[逐文件哈希清单](../artifacts/map-overhaul-source-manifest.json)。本轮前快照包含此前未提交工作，但并未纳入全部根目录原始需求文档；清单中“新增”仅表示不在旧快照，不能直接当作本轮新写文件删除。

回滚时先把快照解到独立目录，对清单中的同名源文件逐项比较，只恢复本轮改动并重新运行导入与规则检查；保留`.godot`以外的用户实验文件、设置和原始需求文档。不要直接覆盖项目或执行Git硬重置。实验数据迁移的回退使用各自`.pre-map-v3-*`备份，先保留当前文件，再按来源引擎版本恢复，不与源码回退混为一步。

`artifacts/`中的日志、截图、报告和快照为本机验收产物，不随Git分发；克隆后按以上入口重新生成。
