# 真实 LLM 提示词转换与运行验证

后续更新：本文保留首次验证历史。用户的完整“边界绕后、冲刺赶路、精确优先菱形”提示词现已增加引擎支持并用原文真实验证；SiliconFlow指定模型改用已验证的非思考JSON模式。当前能力与结果见 [边界绕后验证](boundary-tactic-verification.md)。本文后文的“不支持”描述对应更新之前。

验证时间：2026-10-20（America/Los_Angeles；本机日志为2026-10-21 Asia/Shanghai）。使用用户授权的 SiliconFlow `https://api.siliconflow.cn/v1/chat/completions` 和 `deepseek-ai/DeepSeek-V4.1-Flash`，实际发起 HTTPS 请求。Godot 4.7.2 / Apple M5 / Forward+ / Metal。Key未写入源码、测试命令参数、日志、配置或实验数据。

## 验证结论

五兵种均取得真实模型生成、未经手工改写的合法战术 JSON。验证同时检查语义边界、真实战场事实、自主施放、实际伤害或治疗、反例不施放，以及正式开局矩阵与解释器一致性。

最终真实接口轮次 **78项通过、0失败**。这一轮重新测试连接、获取98个模型并重新生成六边形JSON（4422ms），其他四兵种使用本轮此前真实生成的JSON。连接测试1023ms，模型列表233ms。五份JSON的无网络确定性回放另为 **75项通过、0失败**，两组检查存在重复，不累计为独立覆盖量。

原有相关回归重新执行 **522项通过、0失败**，新增移动意图30项、异步取消6项全部通过。72个脚本在真实Autoload上下文编译，导入通过。三张地图完成固定种子、峰值60单位的完整对局，无资源、人口和六边形上限异常。这些整局使用测试驱动的条件战术，用于移动与战斗回归；真实模型JSON的技能效果由独立夹具验证，不将两者混为同一测试。

这验证了下列提示词样本，不能推导任意自然语言均能准确编译或服务每次都会成功。真实服务的超时、非法输出和不支持的要求仍会明确报错并保留上一份有效配置。

## 五兵种实际结果

完整输入与生成JSON集中在 [real-llm-examples.json](../artifacts/real-llm-examples.json)，测试原文位于 `tests/real_llm_runner.gd` 的 `PROMPTS`。单份输出为 `artifacts/real-llm-{triangle,square,circle,diamond,hexagon}.json`。

| 兵种 | 验证的条件 | 实际技能结果 |
|---|---|---|
| 三角 | HP严格低于30%优先撤退；目标110至340px且技能就绪才冲刺 | 启动1次，背刺实际110伤害；低血5秒内从(1000,350)退至约(350,675)，不施放 |
| 方形 | HP小于等于25%撤退；目标不超过220px且技能就绪才护盾 | 启动1次，真实友方护盾存在；低血朝基地撤退且不施放 |
| 圆形 | 目标160px内聚集至少3个敌军且技能就绪 | 启动1次，真实引力、坍缩造成合计126伤害；2目标时不施放 |
| 菱形 | 目标可见、不超过650px且技能就绪 | 启动1次，激光实际85伤害；掩体遮挡时不施放 |
| 六边形 | 300px内友军最低HP严格低于60%且技能就绪 | 启动1次，实际恢复35HP；60%时不施放，priority为none，无直接普攻 |

三角109/110/340/341px、方形220/221px、菱形650/651px、HP严格和含等号边界均由事实求值检查；另在真实物理世界中验证各兵种正反例。测试为了隔离技能会禁用夹具普攻、让对手固定站位并将蓝方初始技能置为就绪，使用正式技能实现和结算，未修改UnitCatalog正式冷却、伤害、射程或治疗数值。

用户界面中的原三角草稿还要求“沿边界逐段前进、用技能无目标加速赶路、只优先消灭菱形”。真实模型返回不支持原因，旧配置保留。这些要求超出现有路线和技能能力，不能称为已经准确执行。可使用现有的分推、侧翼绕后、优先远程或指挥官，以及合法距离内冲刺；逐段航点和无目标赶路冲刺需要另行开发。

## 验证中修复的问题

1. **请求取消阻塞主循环。** 原HTTPRequest线程模式使用阻塞socket，取消时等待工作线程结束。慢响应使30秒超时拖至约60秒，并影响下一请求。改为Godot默认的非阻塞异步HTTP流程，保留拥有者、配置代次、请求对象校验和TLS。超时单独分类为timeout。未放宽默认30秒、增加自动重试或模型专用参数。
2. **主动撤退使用了进攻缓存。** 原单位同帧依次查询推进、追击、编队、撤退，单单位路由缓存最终仍属于先前目标。改为先确定最终移动意图，每帧只为最终目标查询导航；意图或目标身份切换立即失效缓存，同一目标的位置更新仍复用既有节奏。物理移动、地形碰撞和分离转向保留。三图双方均检查追击、撤退、原地防守及恢复推进。
3. **系统提示遗漏非空组合条件约束。** 一次六边形返回空all作为默认分支，严格校验正确拒绝。补充“all/any不能为空，默认动作放base，无匹配使用base”，显式重测后取得合法JSON。没有放松校验或修补模型输出。

本地1.25秒延迟服务实测：修复前取消阻塞1213ms、0.1秒超时实际1257ms；修复后取消0ms、超时115ms、最大帧间隙9ms。证据为 `llm-lifecycle-before-report.json` 与 `llm-lifecycle-report.json`。正式服务修复后仍有一次真实30,004ms超时，这是服务响应时间边界，保留在 `real-llm-post-fix-timeout-report.json`，没有隐藏。

Godot类文档站在本轮访问不可用，替代读取官方仓库的 [HTTPRequest类定义](https://github.com/godotengine/godot/blob/master/doc/classes/HTTPRequest.xml) 和 [HTTPRequest实现](https://github.com/godotengine/godot/blob/master/scene/main/http_request.cpp)，用于核实timeout与cancel的线程生命周期；未把文档站访问失败等同为游戏请求失败。供应商协议参考实际读取的 [SiliconFlow Chat Completions](https://docs.siliconflow.cn/cn/api-reference/chat-completions/chat-completions)。

## 日志与运行证据

| 检查 | 结果 | artifacts中的证据 |
|---|---:|---|
| 真实模型生成、边界、技能及正式一致性 | 78通过 | real-llm-report.json / real-llm.log |
| 保存的真实JSON确定性回放 | 75通过 | real-llm-replay-report.json / real-llm-replay.log |
| 原MVP、V2、战斗、切场景、通行、首页设置 | 240通过 | real-llm-regression-{mvp,v2,combat,scene-flow,navigation,launcher}.log |
| 条件规则及本地HTTP模拟 | 95通过 | real-llm-regression-ai-rules.log |
| 布阵与实验室流程 | 167通过 | real-llm-regression-ai-flow.log |
| 原生Metal输入、取消、切兵种、焦点、暂停与读数 | 20通过 | real-llm-native-flow.log |
| 三图双方的移动意图切换与真实撤退 | 30通过 | movement-intent-report.json / movement-intent.log |
| 延迟响应下超时、取消及过期响应 | 6通过 | llm-lifecycle-report.json / llm-lifecycle-after.log |
| 导入 / 72脚本编译 | 0错误 | real-llm-regression-import.log / real-llm-compile.log |
| Key落盘扫描 | 239文件，0匹配 | real-llm-secret-scan.json |

最终汇总为 [real-llm-validation.json](../artifacts/real-llm-validation.json)。初次失败证据保留在 `real-llm-initial-report.json`、`real-llm-generation-report.json`、`real-llm-retreat-before-report.json`、`real-llm-empty-condition-report.json`；它们为诊断过程而非最终通过报告。早期技能夹具未等待初始1.5秒技能就绪，造成假阴性，已显式准备冷却并采用独立World2D后重测；实际撤退错误另有生产修复，没有放松断言。

| 地图 | 固定种子 | 模拟秒数 | 峰值单位 | 结果 |
|---|---:|---:|---:|---|
| 均衡前线 | 20261020 | 142.50 | 60 | 红方摧毁蓝方基地 |
| 双翼迂回 | 20261020 | 232.80 | 60 | 红方摧毁蓝方基地 |
| 折光阵列 | 20261020 | 126.98 | 60 | 红方摧毁蓝方基地 |

整局证据为 `real-llm-simulation-{balanced,flanks,refraction}.json/.log`，均 `failures=[]`。用于证明可完成整局，不作为平衡或胜率结果。没有把旧539项历史验收重新标记为本轮全部执行。

原生20项使用本地可控HTTP服务测试UI流程，真实供应商78项使用HTTPS，分别记录。原生3张截图见 `real-llm-native-focus-report.json`；1280×720、130%字号、Retina屏幕，RGBH真实帧缓冲经 `encode_captures.py` 转为sRGB，无额外画面绘制。截图中的地址与模型为本地夹具，不冒充真实供应商截图。人工检查取消焦点、输入框遮罩、固定关闭按钮和滚动内容。日志仅有macOS IMK mach-port诊断，无Godot脚本或资源错误。本轮没有UI设计改动，没有重复多尺寸视觉重设计验收、完整IME或屏幕阅读器验收。

## 复现与使用

在游戏“设置 → LLM”填完整端点或 `https://api.siliconflow.cn/v1`、本次Key以及 `deepseek-ai/DeepSeek-V4.1-Flash`，点击测试连接。进入“兵种演练 → 提示词 · 布阵验证”，编辑提示词、生成JSON、检查预览、应用并重跑，最后明确应用为正式开局。当前已运行的旧游戏进程需要重新启动才能加载源码修复；Key退出后需重新填写。原用户窗口和草稿未由本轮测试关闭或覆盖。

不需要Key即可回放保存的真实JSON：

```sh
./run.command --headless --fixed-fps 60 --scene res://tests/real_llm_runner.tscn -- --replay
./run.command --headless --fixed-fps 60 --scene res://tests/movement_intent_runner.tscn
```

手动再次请求真实服务，终端会隐藏读取Key；不要把Key写进命令文本。下列命令使用已有四份JSON，仅刷新六边形；去掉 `--resume --refresh=hexagon` 将请求全部五兵种。请求失败后不会自动重试。

```sh
read -rs GEO_LLM_TEST_KEY
export GEO_LLM_TEST_KEY
./run.command --headless --scene res://tests/real_llm_runner.tscn -- --resume --refresh=hexagon
unset GEO_LLM_TEST_KEY
```

测试在Godot读取后立即清除环境变量，使用独立test配置，不保存Key。模型列表、生成及测试均可能计入供应商用量。

本地故障回归：先在独立终端运行 `python3 tests/llm_mock_server.py`，再执行：

```sh
./run.command --headless --scene res://tests/llm_lifecycle_runner.tscn
./run.command --headless --fixed-fps 60 --scene res://tests/ai_lab_runner.tscn -- --http-mock
./run.command --scene res://tests/ai_lab_native_flow.tscn -- --geo-test
```

完成后停止该本地测试服务。游戏本身不依赖Python或此服务。

## 源码与数据边界

源码修复为LLMService、UnitTacticProgram系统提示，以及BaseGeoUnit / CombatContext / ArenaObstacles的移动意图接口。测试新增真实服务、延迟生命周期和移动意图场景，旧HTTP夹具增加延迟分支并更新timeout分类期望。原始需求文档哈希保持原值。

修复后的源码检查点为 `artifacts/post-real-llm-source.tar.gz`，只包含工程源码、测试与文档，不含Key、用户数据、引擎、缓存或截图。恢复时解压至新的空目录并导入project.godot。本轮寻路和提示词修改前的单文件副本在 `artifacts/real-llm-pre-navigation/`（.gd.before）；该时间点已包含网络取消修复，不是整轮之前的完整快照。更早的 `pre-ai-lab-source-backup.tar.gz` 会回到整个AI实验室开发前，不适合只撤销本轮修复。当前目录不是Git仓库，未创建commit。

未验证其他供应商、所有自然语言表达、长时间服务稳定性或其他操作系统；默认30秒超时仍可能需要用户显式重试。没有启用任意代码、网络对战、Key持久化或新增外部素材。
