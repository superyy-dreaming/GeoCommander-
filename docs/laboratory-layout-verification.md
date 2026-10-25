# 实验室布局与可读性验证

2026-10-24，本机 Godot 4.7.2 Stable、Forward+、Metal 4.0，Apple M5。当前工作区原有地图、精细战术、LLM 与实验数据功能保留，本轮只调整桌面实验室、共用字号尺寸计算和相关弹层。

## 改动与原因

原布局的第三数据栏和常驻布阵控件挤占编辑与战场宽度；反馈只设置最小高度，无法保证实际占比。现在使用原生左右、上下分隔容器，左侧默认约 42%，反馈按编辑内容区的实际可用高度默认分配 40%，可拖动到 30%–60%。固定操作区在分隔容器外，长反馈内部滚动，支持独立展开阅读。

1280×720、180% 字号下，反馈至少两行正文的可读最小高度使其实际占比约 54%，仍在允许上限内；其余八组尺寸与字号组合约为 40%。这些比例不包含页签、兵种选择和底部两行动作区。详见 [实际几何测量](../artifacts/lab-layout-report.json)。

编辑分为兵种提示词、JSON、步骤、整体提示词四页；窄窗口和大字号采用选择菜单。战场使用地图、布阵、编辑、验证、显示五个菜单，布阵属性以固定关闭入口、正文独立滚动的有界弹层展示。读数框替代原第三栏，可以拖动、调整尺寸、收起、关闭及恢复位置。操作说明见 [AI 提示词实验室](ai-laboratory.md#界面与布局操作)。

字号切换曾基于已放大的控件高度继续取最大值，切回 100% 无法恢复。本轮改为从控件的基准尺寸和当前文字实际高度重新计算。设置的显示确认仍保留 15 秒保留或回退流程，长正文滚动、按钮固定。

原生操作还发现两项问题：读数框的滚轮事件经过 `MOUSE_FILTER_STOP` 后仍会向战场传递，现显式关闭 `mouse_force_pass_scroll_events`；`MenuButton` 默认焦点模式不能经普通 Tab 到达，现为实验室任务菜单与“更多”操作设置 `FOCUS_ALL`。

## 验证结果

| 检查 | 结果 | 本机日志 |
|---|---|---|
| 全工程导入 | 通过 | [导入日志](../artifacts/lab-layout-import.log) |
| 真实 Autoload 上下文脚本检查 | 95 文件，0 失败 | [脚本日志](../artifacts/lab-layout-scripts.log) |
| 原生布局与交互 | 168 通过，0 失败，裁切扫描 0 项 | [布局日志](../artifacts/lab-layout-native.log) |
| 原生菜单与键盘操作 | 45 通过，0 失败 | [菜单日志](../artifacts/lab-layout-menus.log) |
| 基础规则回归 | 76 通过，0 失败 | [规则日志](../artifacts/lab-layout-rules.log) |
| AI 实验室行为回归 | 93 通过，0 失败 | [实验室日志](../artifacts/lab-layout-ai-regression.log) |
| AI 原生操作流程，本地 HTTP 模拟 | 20 通过，0 失败 | [AI 原生日志](../artifacts/lab-layout-ai-native.log) |
| 精细战术原生流程 | 14 通过，0 失败 | [编排日志](../artifacts/lab-layout-plan-native.log) |
| 首页、地图与设置回归 | 102 通过，0 失败 | [首页行为日志](../artifacts/lab-layout-launcher.log) |
| Metal 显示、设置及暂停流程 | 15 通过，0 失败 | [设置原生日志](../artifacts/lab-layout-launcher-native.log) |

`git diff --check` 通过。日志中的 macOS `IMKCFRunLoopWakeUpReliable` mach port 提示未伴随 GDScript 错误或断言失败；不把它作为中文输入法候选窗已验证的证据。

布局检查覆盖 1280×720、1440×900、1920×1080 的 100%、130%、180% 字号，并验证 100%、115%、130%、150%、180% 往返后按钮恢复原始高度。断言计算控件与可裁切祖先的实际交集，并检查固定操作与反馈、两列按钮之间的重叠，结合真实点击、拖动、滚动及截图复核。

操作覆盖四页草稿保留、生成与取消同槽位、成功/非法 JSON/保存失败/保存重试、反馈展开、左右及上下分隔、读数拖动和缩放、收起和关闭、滚轮不缩放战场、全部任务菜单入口、恢复默认及地图切换取消、弹层阻止布阵、Tab 焦点、Space 打开菜单、Esc 关闭及统一设置入口。布局和字号变化不重建战斗上下文。生成完成仅产生候选 JSON，正式开局仍需明确应用。

原生 macOS 全屏夹具先将窗口置于前台，再验证真实模式和尺寸完成切换，避免尚未完成 AppKit 全屏过渡就发起反向操作。测试使用 `--geo-test` 独立配置，不覆盖正式游戏设置与实验数据。

## 截图

共 16 张实际 Metal 帧缓冲截图，清单、尺寸与比例记录在 [布局报告](../artifacts/lab-layout-report.json)。HDR `RGBH` 原始像素按实际格式读取，经过线性到 sRGB 编码，没有修改画面元素。

- [1920×1080，100% 字号](../artifacts/ai-lab-layout-1920x1080-100.png)
- [1440×900，180% 字号](../artifacts/ai-lab-layout-1440x900-180.png)
- [1280×720，180% 字号](../artifacts/ai-lab-layout-1280x720-180.png)
- [大字号长错误](../artifacts/ai-lab-layout-error-180.png)
- [展开反馈](../artifacts/ai-lab-layout-expanded-180.png)
- [布阵属性滚动弹层](../artifacts/ai-lab-layout-placement-180.png)
- [有界设置确认](../artifacts/ai-lab-layout-settings-confirm-180.png)

本机为 Retina，报告中 `screen_scale=2`、屏幕尺寸为 3420×2136。截图像素尺寸与请求窗口尺寸一致，不宣称另外完成了 3840×2160 渲染。已完成一轮批量截图检查、集中修复和最终确认。

## 复现

先在独立终端运行本地模拟服务，完成后按 Ctrl+C 关闭：

```sh
python3 tests/llm_mock_server.py
```

在项目目录依次运行原生测试，避免多个窗口同时争抢前台：

```sh
./run.command --headless --import
./run.command --headless --scene res://tests/check_scripts.tscn -- --geo-test
./run.command --headless --scene res://tests/test_runner.tscn -- --geo-test
./run.command --headless --scene res://tests/ai_lab_runner.tscn -- --geo-test
./run.command --scene res://tests/lab_layout_native.tscn -- --geo-test
./run.command --scene res://tests/lab_menu_native.tscn -- --geo-test
./run.command --scene res://tests/ai_lab_native_flow.tscn -- --geo-test
./run.command --scene res://tests/tactic_plan_native.tscn -- --geo-test
./run.command --headless --scene res://tests/launcher_test_runner.tscn -- --geo-test
./run.command --scene res://tests/launcher_native_flow.tscn -- --geo-test
python3 tests/encode_captures.py lab-layout-report.json
```

本轮只请求 `127.0.0.1:18741` 的模拟服务，验证候选、错误、取消和应用流程；未再次请求真实供应商，不把模拟通过当作真实模型准确率。历史供应商证据见 [真实模型验证](real-llm-verification.md)。游戏运行不依赖 Python；截图编码脚本需要 NumPy、Pillow。

## 改动边界与局部回滚

布局拆为 `LabFeedbackPanel`、`LabPlacementPanel`、`LabFloatingReadout`、`LabDialog`；设置确认使用 `BoundedConfirmation`。本轮未增加第三方 UI 依赖、联网功能或素材，未调整战斗数值、地图定义或 AI 编译规则。

已有工作区包含未提交的先前功能，不能用 Git HEAD 或历史整包覆盖。五个文件的本轮前局部备份和逐文件差异位于 [备份清单](../artifacts/lab-layout-before/manifest.json)。这是局部备份，不是完整工程快照；`TacticPlanEditor` 和测试没有本轮前快照。若需回滚，先另存当前工程，只在确认本轮之后没有新改动的情况下恢复清单中的五个文件，再撤销步骤编辑器的布局尺寸调整、移除本轮新增布局组件及测试，并运行全工程导入和脚本检查。不要回滚此前地图、编排、LLM 或实验数据，不删除本机配置。

本轮依据既有 CommanderTheme、`ui-ux-pro-max` 与 `impeccable` 做桌面 Operate / Read 审计及视觉收口。Godot 文档站访问受限，以官方 Godot 源码及本机真实运行验证替代容器和菜单行为依据，未声称读取到受限页面。未使用 Apple 专项技能；没有认证其他操作系统、移动端、屏幕阅读器或中文输入法候选窗。
