# AI 提示词实验室

## 使用流程

首页进入“兵种演练”，选择兵种后点击“提示词 · 布阵验证”。原固定普攻和技能演示保留在“档案与演示”。实验室顶部可切换五个兵种，提示词分别保存，切换兵种及离开时保存当前草稿；也可点击“保存草稿”。

1. 在设置的“LLM”页填写服务地址、Key 和模型 ID，测试连接。
2. 编辑当前兵种提示词，点击“AI 生成 JSON”。请求期间可取消；失败保留上一份有效 JSON。
3. 在 JSON 页检查、编辑并校验。未知字段、越界数值、非法能力或无效格式均拒绝，不转用关键词解析。
4. 选择地图和快捷预设，或自行布阵。蓝红各最多 30 个单位、2 个六边形。左键放置或选中，拖动后松开调整站位；生命比例和朝向作用于选中单位，也作为下次放置的默认值。删除按钮或战场焦点下的 Delete 删除选中单位。滚轮缩放，中键平移。
5. “应用当前兵种并重跑”仅替换蓝方该兵种的实验配置，使用同一初始阵容、地图和种子重跑。红方始终使用默认战术。“默认战术对照”使用相同站位和种子，蓝方也采用默认战术。“重置布阵”恢复初始数据。
6. 确认效果后点击“应用当前兵种为开局”。其他兵种保留；此开局设置只在本次程序运行内生效。正式对局准备矩阵展示实际编译 JSON，直接开始会保留条件规则。编辑或提交关键词会明确替换整队战术。

布阵、运行、暂停、结束为独立状态。运行或暂停时不能改变初始阵容；重置后可编辑。验证使用真实 1×时间和正式冷却，基地摧毁、一方单位全灭或120秒结束。结果中的实际伤害不计过杀溢出，治疗不计超出最大生命的部分，技能次数按真实启动计算。点击单位可在规则读数查看当前命中规则、事实与技能受阻原因。事件记录最多保留80条。

实验室与正式战场隔离物理世界、生命周期、战术、人口和经济；使用共用的目标评分、移动、编队、占点推进、地形导航、伤害、治疗和技能实现。正式技能已启动的蓄力与冲刺不会被新一轮条件决策中断。

## LLM 配置

支持 OpenAI 兼容协议。Base URL 可填 `https://example.com/v1`，也可填完整 `https://example.com/v1/chat/completions`，后者会规范化。版本路径保留；不能在地址中夹带用户凭据、查询参数或片段。

“获取模型”调用 `GET /models`。列表失败仍可手填模型 ID，并用“测试连接”发起真实最小 `POST /chat/completions` 请求。连接测试分别报告鉴权、模型或路径、网络/TLS、HTTP和响应格式问题。更改地址、Key或模型会使旧测试状态失效，取消现有请求。连接测试成功不代表任何兼容服务都能严格遵守 JSON；生成结果仍在本地校验。

生成采用非流式 `model`、`messages`、`stream:false`，不执行生成代码。对已实测的精确组合 `https://api.siliconflow.cn/v1` 与 `deepseek-ai/DeepSeek-V4.1-Flash`，额外使用 `enable_thinking:false`，生成时使用 `response_format:{"type":"json_object"}`。界面请求状态会说明“SiliconFlow 非思考 JSON 模式”；其他地址或模型保持通用协议。请求默认30秒超时、响应上限1MiB、禁止重定向，保留默认TLS验证，无自动重试。离开页面、切换兵种、更改连接配置或点击取消均会取消对应请求；配置代次与拥有者检查拒绝过期结果。

已用 SiliconFlow `https://api.siliconflow.cn/v1` 和模型 `deepseek-ai/DeepSeek-V4.1-Flash` 完成真实生成及五兵种运行验证，记录见 [真实模型验证](real-llm-verification.md)。该服务实测有超过30秒的生成和不符合规则格式的返回；错误会明确显示，保留旧配置，可手动重试。测试连接通过仅表示最小请求成功。

API Key 仅存在本次进程内存，界面遮罩显示；退出程序后需重新填写。Key 不写入游戏配置、连接配置、实验文件或日志。请在游戏界面输入真实 Key，不需要发送到聊天。

协议依据：

- [Chat Completions 官方参考](https://developers.openai.com/api/reference/resources/chat/subresources/completions/methods/create)
- [Models 官方参考](https://developers.openai.com/api/reference/resources/models/methods/list)

## 规则格式与能力

权威定义在 `scripts/core/unit_tactic_program.gd`，同时供模型系统提示、本地校验与执行器使用。根对象严格包含 `version:1`、`unit_type`、完整 `base`、有序 `rules`。每兵种最多12条规则、全部规则合计32个条件节点、条件深度4，提示词最多4096字符。

```json
{
  "version": 1,
  "unit_type": "triangle",
  "base": {
    "movement": "flank_sides",
    "priority": "ranged_or_commander",
    "skill_cond": "backstab_or_grav",
    "retreat_hp": 0.2,
    "lane_mode": "auto",
    "stance": "balanced",
    "behavior": "normal",
    "skill_usage": "auto"
  },
  "rules": [
    {
      "id": "低血量撤退",
      "when": {"fact": "self_hp", "op": "lt", "value": 0.3},
      "actions": {"behavior": "retreat", "skill_usage": "hold"}
    }
  ]
}
```

每约0.15秒先用基础优先级选目标并采集事实，再自上而下匹配第一条规则，将动作合并到基础配置；没有匹配使用基础。动作改变目标优先级时重新选敌，条件本次仍基于基础目标，避免递归匹配。规则没有累积状态，不支持任意脚本、连招或新技能数值。

| 字段 | 值与含义 |
|---|---|
| movement | direct_charge、flank_sides、guard_rear、protect_hexagon、frontline_screen、midline_support、max_range_kite、safe_backline；菱形另支持 align_with_square、align_with_crystal |
| priority | closest、ranged_or_commander、diamond_first、lowest_hp、highest_threat、cluster；diamond_first精确优先菱形，无菱形时选择其他敌军；六边形仅 none，无直接普攻 |
| skill_cond | 三角 backstab_or_grav / travel_and_backstab；方形 ally_threatened / reflect_laser；圆形 cluster_3plus；菱形 refract_or_snipe；六边形 always_pulse。所有兵种支持 on_cooldown，但仍检查合法目标与真实射程 |
| retreat_hp | 0至0.9的生命比例 |
| lane_mode | auto / mid / split，只影响该兵种 |
| stance | balanced / flank / defensive / aggressive / kite，只影响该兵种；flank偏向接敌侧翼，kite让远程保持距离 |
| behavior | normal / hold / retreat，原地防守仍可攻击；主动撤退向友方基地安全区域移动 |
| skill_usage | auto 按技能条件，hold保留技能，try尝试施放；仍检查冷却、控制、射程、技能自身合法性。圆形最少两个目标，cluster_3plus要求三个 |

三角另支持 `movement:boundary_infiltrate`：开局先向两侧边缘移动，沿边界绕过障碍推进，再根据目标实际朝向接近背后。左右按前进方向的两侧解释，对应上/下边路；按部署序号稳定分配，红方旋转镜像。它是引擎内置机动，不接受AI生成的任意代码或逐帧航点。

搭配 `priority:diamond_first` 与 `skill_cond:travel_and_backstab`，可执行“边路绕后、冲刺赶路、优先菱形”的完整提示词。安全且足够长的路段才用冲刺赶路，与攻击共享真实4.5秒冷却；抵达目标背后时优先攻击。冲刺仍有0.25秒蓄力、0.28秒持续与真实碰撞，保留原伤害；受EMP、熵减、超频和敌盾影响。会按可达距离靠近后再启动背刺。无敌方单位时继续攻击基地。原 `backstab_or_grav` 与旧关键词逻辑保留。原文、真实JSON及实战证据见 [边界绕后验证](boundary-tactic-verification.md)。

规则为 `{id,when,actions}`，id唯一且1至80字符，actions为上述字段非空子集。条件为 `{fact,op,value}` 或 `{all:[条件]}`、`{any:[条件]}`、`{not:条件}`。all / any 必须至少包含一个条件。默认动作放在 base，没有规则匹配时直接使用 base；不能用空 all 表示“否则”。比较支持 eq / ne / lt / lte / gt / gte；布尔和类型仅eq/ne。

| 事实 | 范围/定义 |
|---|---|
| self_hp / target_hp | 0至1的生命比例；无目标时target_hp为1 |
| target_type | triangle / square / circle / diamond / hexagon / base / none |
| target_distance | 0至3000px；无目标时3000 |
| nearby_allies / nearby_enemies | 300px内单位数，整数0至30，友军不含自身 |
| ally_min_hp | 300px内其他友军最低生命比例，无友军为1 |
| hexagon_alive | 己方上下文中有存活六边形 |
| skill_ready | 冷却归零且未被控制 |
| target_visible | 对目标的射线未被地形或敌方盾遮挡，友方盾放行 |
| target_cluster | 目标160px内敌军数量，含目标本身，整数0至30 |

## 本机数据与回滚

macOS 数据目录默认是 `~/Library/Application Support/Godot/app_userdata/GeoCommander/`：

- `settings.cfg`：原游戏设置。
- `llm_connection.cfg`：版本号、Base URL和模型，不含Key。
- `tactic_laboratory_v1.json`：各兵种草稿、有效JSON、已应用实验JSON、来源模型和布阵方案。正式开局配置不写入此文件。

保存失败显示“本次运行已生效，未保存”，提供重试。恢复游戏默认不删除实验或LLM配置。无效实验文件在恢复前保留 `.invalid-*` 备份。测试使用独立的 `test_*` 文件，不覆盖正式数据。

源码回滚快照为 `artifacts/pre-ai-lab-source-backup.tar.gz`。关闭游戏，将快照解压到新的空目录后重新导入 `project.godot`；不要覆盖当前目录，避免遗留新增脚本。回滚不卸载引擎，不删除任何本机配置或实验数据。原始需求文档保持不变。
