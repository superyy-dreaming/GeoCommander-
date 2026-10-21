# 三角边界绕后提示词：修复与验证

本次直接使用用户原文测试，没有要求用户删去“赶路冲刺”或“菱形优先”。当前工程已支持该战术。更新源码后，关闭旧游戏进程并重新运行 `run.command`；旧进程不会热更新。Key仍仅保留本次进程，重启后需在设置中重新填写。

## 为什么此前不能生成

截图中的错误是生成请求未在30秒内收到完整响应，不能由此推断Key错误。上轮实测也出现过真实30秒超时。原引擎还有独立的能力缺口：只有宽泛侧翼移动、有目标冲刺、远程或指挥官优先，不能完整表达边界推进、无目标赶路冲刺和精确菱形优先。此前合法地拒绝不支持要求，未执行这套动作。

本次补齐引擎能力、统一模型提示与本地枚举校验，并调整已实测供应商的请求格式。没有延长30秒超时，没有自动重试、关键词替代、手工修改AI输出或执行模型生成代码。

## 原文与真实生成

> 开局就向左或右边移动，绕过障碍物后，沿着边界向前移动，使用技能加快运动速度，快速推进到敌方单位后方，在技能范围内，使用技能攻击敌方单位，以消灭菱形为主要目标。

用 SiliconFlow `https://api.siliconflow.cn/v1/chat/completions`、`deepseek-ai/DeepSeek-V4.1-Flash` 连续发起三次独立生成，三次均成功：**2570ms、1516ms、1511ms**，`finish_reason=stop`。这是三个显式测试样本，不是自动重试，不能承诺所有后续请求都会在这一时间内完成。证据为 [boundary-real-report.json](../artifacts/boundary-real-report.json)，三份原始有效JSON为 `boundary-generated-1/2/3.json`。三个核心策略字段相同；第三份stance为flank，前两份为balanced，三份分别用于三张地图的实战检查，均未手工修改。

模型返回的核心配置如下，完整文件由真实返回直接保存：

```json
{
  "version": 1,
  "unit_type": "triangle",
  "base": {
    "movement": "boundary_infiltrate",
    "priority": "diamond_first",
    "skill_cond": "travel_and_backstab",
    "retreat_hp": 0.0,
    "lane_mode": "auto",
    "stance": "balanced",
    "behavior": "normal",
    "skill_usage": "auto"
  },
  "rules": []
}
```

`rules`为空是合法的：这条提示词选择一个完整内置战术，默认动作已在base，无须伪造条件。原有八字段、版本1和全部旧条件规则保持兼容。新增移动与技能枚举只允许三角使用；其他兵种不能借此获得冲刺。

## 实际行为

- 开局先向相对前进方向的左/右侧边缘移动，地图上对应上/下边路。按稳定部署序号分配，红方镜像；不逐帧随机换边。
- 通过真实地形路网绕过基地L掩体，沿边缘推进，再根据目标实际朝向接近背后。边缘目标位于晶簇外扩导航轮廓之外，避免目标X恰好对齐晶簇时无路可走。目标死亡后重新选敌；变更战术或拓扑传送重置当前机动。
- `diamond_first`在有存活菱形时精确优先选菱形，优先级高于更近的方形。没有菱形时选择其他敌军；没有敌方单位时继续接近并普攻基地。
- 安全且长度足够的直线路段可以使用同一真实冲刺赶路。赶路与攻击共享4.5秒冷却、0.25秒蓄力、0.28秒冲刺和980px/s原速度。接近目标时优先从背后攻击，背刺原始伤害110，不修改UnitCatalog。
- 冲刺受真实掩体、敌盾和边界阻挡，友盾放行；受EMP、熵减、超频和规则保留技能约束。赶路前检查路线净空与剩余距离，避免冲过拐点。攻击按实际可达距离靠近再释放，避免在340px标称射程边缘空冲。目标在蓄力后移动仍可能躲开，战术不保证每次攻击命中或赢得对局。

## 生成链路

只对已核实的精确端点 `https://api.siliconflow.cn/v1` 和模型 `deepseek-ai/DeepSeek-V4.1-Flash` 使用 `enable_thinking:false`，生成时另带 `response_format:{"type":"json_object"}`。界面生成状态明确显示“SiliconFlow 非思考 JSON 模式”。其他端点或未知模型维持原通用参数，不静默降级或自动重发。

依据实际读取的 [SiliconFlow Chat Completions 官方参考](https://docs.siliconflow.cn/cn/api-reference/chat-completions/chat-completions)，并用该模型的真实响应验证两个参数确实被服务接受。JSON模式只约束JSON语法，本地字段、能力、范围与规则校验继续执行。TLS、拥有者、配置代次、取消、1MiB响应限制、禁止重定向和Key仅内存的边界保留。返回新增安全诊断字段：耗时、请求模式、finish_reason，不记录请求头、Key或模型思维内容。

默认思考过程可能延长这类结构转换的等待；新模式实测减少了本次样本耗时。供应商排队、网络及服务故障仍可能导致超时，失败时保留原JSON和战场，用户可显式重试。没有将一次测试连接成功当作生成成功。

## 测试证据

| 验证 | 结果 | artifacts证据 |
|---|---:|---|
| 用户原文连续三次真实生成与能力检查 | 29通过，0失败 | boundary-real-report.json / boundary-real.log |
| 保存的三份真实JSON实战、碰撞与正式一致性 | 175通过，0失败 | boundary-replay-report.json / boundary-replay.log |
| 原生Metal界面真实生成、应用、开局与字号焦点 | 7通过，0失败 | boundary-native-report.json / boundary-native.log |
| 原MVP、V2、战斗、导航、场景、首页设置、AI规则/HTTP、实验室、原生流程 | 522通过，0失败 | boundary-regression-*.log |
| 上轮移动意图回归 | 30通过，0失败 | boundary-regression-movement.log |
| 上轮五兵种真实JSON回放 | 75通过，0失败 | boundary-regression-real-json-replay.log |
| 超时、取消与过期回调生命周期 | 6通过，0失败 | boundary-lifecycle.log |
| 全工程脚本编译 | 75脚本，0失败 | boundary-compile.log |

各集合存在重复断言，不将它们相加冒充独立测试覆盖率。汇总为 [boundary-validation.json](../artifacts/boundary-validation.json)。

175项包括三图×双方×两条边路的12套自主机动，另有双方目标反向朝向、双方目标X对齐晶簇的4套，共16套。每套使用独立World2D、正式伤害/技能/物理移动、真实地形；敌方靶人固定站位，禁用攻击以隔离机动效果。每套都实际到达边缘、沿边推进、优先选择菱形、启动赶路冲刺，再从背后以110原始伤害命中并消灭105HP菱形。每次施放间隔检查不低于正式4.5秒，未通过缩短冷却获得结果。

典型蓝方从L掩体后方(560,675)出发：约2.55秒在边路启动第一次赶路冲刺，7.07秒启动接近后排的赶路冲刺，11.58秒在背后启动攻击冲刺，随后真实结算110背刺。实际生命损失只记录105HP，过杀没有计入实际伤害。另测EMP、原地防守、撤退禁用前冲、蓄力不能排队、敌盾/掩体截停且墙后靶人不掉血、友盾放行，以及对基地正常普攻。

三图以固定种子20261020、峰值60单位完成正式整局，三角使用本次真实生成程序，其余蓝方兵种使用测试驱动的旧条件战术，红方保留原AI指挥。报告为 `boundary-original-simulation-{balanced,flanks,refraction}.json/.log`，均 `generated_boundary=true`、`failures=[]`。结果用于验证整局生命周期和规则兼容，不作为战术胜率或平衡结论。

原生界面通过真实“AI生成JSON”按钮信号发送用户原文、真实回调展示JSON，再使用“应用当前兵种并重跑”和“应用当前兵种为开局”进入同一引擎逻辑。截图为真实Metal帧缓冲，RGBH经现有脚本编码sRGB，未绘制额外元素：

- [1440×900 JSON](../artifacts/boundary-native-json.png)
- [1440×900 边路推进](../artifacts/boundary-native-edge.png)
- [1280×720、130%字号和生成按钮焦点](../artifacts/boundary-native-large-font.png)

最小窗口下提示词区域可独立滚动，Tab焦点会将生成按钮完整滚入可见范围，应用按钮保持可见。没有改动界面布局或引入UI库，因此未做视觉重设计，也未声称调用设计skill或代理审查。仍保留原用户游戏窗口和正式草稿；测试使用独立test配置。

诊断过程中两个测试夹具被纠正并保留日志：`--fixed-fps`会加速引擎定时器，造成8ms以内的假HTTP超时，因此真实网络与固定帧战斗回放分开；碰撞夹具最初在熵减区内站位200px，超过该区实际可达攻击距离约199px，后来改为190px以真实启动碰撞测试。没有放宽生产校验或跳过失败断言。

## 使用与复现

1. 退出旧游戏并双击 `run.command` 重新启动。
2. 设置 → LLM：填写原SiliconFlow地址、Key和模型，测试连接。
3. 兵种演练 → 提示词 · 布阵验证 → 三角：粘贴原文，点击“AI生成JSON”。生成状态应显示非思考JSON模式。
4. JSON中应出现 `boundary_infiltrate`、`diamond_first`、`travel_and_backstab`。点击应用并重跑；确认后应用为开局。

无需Key即可重放本次真实生成JSON：

```sh
./run.command --headless --fixed-fps 60 --scene res://tests/boundary_tactic_runner.tscn -- --replay
```

真实网络验证使用正常时间，禁止追加 `--fixed-fps`。终端隐藏读取Key，不要将Key写进命令文本：

```sh
read -rs GEO_LLM_TEST_KEY
export GEO_LLM_TEST_KEY
./run.command --headless --scene res://tests/boundary_tactic_runner.tscn -- --generate-only
unset GEO_LLM_TEST_KEY
```

这会显式执行三次独立请求并保存生成JSON；游戏本身不会自动重试。原生真实生成流程可将上述运行命令替换为 `./run.command --scene res://tests/boundary_native_runner.tscn -- --geo-test`，会打开测试窗口并使用独立test文件，完成后自行退出。

正式整局回归：

```sh
./run.command --headless --fixed-fps 60 --disable-vsync --scene res://tests/simulation_runner.tscn -- --conditional --boundary --map=balanced
```

地图可替换为flanks或refraction。无需密钥，不读取正式用户实验。

## 回滚与限制

修改范围为LLMService请求构造与诊断、UnitTacticProgram枚举/模型提示、新BoundaryManeuver、BaseGeoUnit选敌与移动接入、三角技能入口，以及传送后清理机动状态。八字段及旧关键词行为保留，未修改正式兵种数值。测试场景和文档独立于游戏入口。

变更前源码为 `artifacts/pre-boundary-tactic-source.tar.gz`，包含上一轮AI实验室与网络/撤退修复。关闭游戏后解压至新目录，使用其中project.godot启动；不要覆盖当前目录。快照不包含Key、用户数据、引擎缓存或外部服务。新版枚举编译的实验数据不适用于旧引擎实现；如已在正式实验中保存，回滚前保留实验文件副本，不删除用户数据。原需求文档不变。

当前程序只增加这套有界内置机动，不支持任意脚本、自定义无限航点、修改伤害或绕过碰撞。网络不保证永久可用；该战术不保证对所有移动敌军命中或获胜。本轮未重新测其他操作系统、长时间性能或完整中文输入法候选窗。
