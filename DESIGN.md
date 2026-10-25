---
name: GeoCommander
description: 原生桌面几何战术游戏与提示词实验室的指挥界面
colors:
  text: "rgb(88% 94% 99%)"
  muted: "rgb(61% 75% 83%)"
  accent: "rgb(20% 80% 100%)"
  gold: "rgb(100% 77% 30%)"
  panel: "rgb(2.2% 4.3% 6.7% / 96%)"
  panel-stroke: "rgb(13% 29% 38%)"
  control: "rgb(4% 9% 13%)"
  control-stroke: "rgb(15% 33% 43%)"
  control-hover: "rgb(5.5% 16% 21%)"
  control-pressed: "rgb(6% 22% 28%)"
  control-disabled: "rgb(2.8% 5.5% 7.5%)"
  disabled-stroke: "rgb(11% 22% 29%)"
  input: "rgb(1.2% 2.5% 4.1%)"
  input-stroke: "rgb(16% 34% 44%)"
  selection: "rgb(8% 32% 45%)"
  focus: "rgb(72% 92% 100%)"
typography:
  display: {fontFamily: "PingFang SC", fontSize: "36px"}
  headline: {fontFamily: "PingFang SC", fontSize: "30px"}
  body: {fontFamily: "PingFang SC", fontSize: "18px"}
  label: {fontFamily: "PingFang SC", fontSize: "16px"}
  readout: {fontFamily: "PingFang SC", fontSize: "14px"}
rounded: {control: "4px"}
spacing: {inline: "12px", vertical: "10px", section: "16px", lab-inset: "18px", academy-inset: "24px", page-inset: "32px"}
components:
  button: {backgroundColor: "{colors.control}", textColor: "{colors.text}", typography: "{typography.body}", rounded: "{rounded.control}", padding: "10px 14px"}
  button-hover: {backgroundColor: "{colors.control-hover}", textColor: "{colors.text}", rounded: "{rounded.control}", padding: "10px 14px"}
  button-pressed: {backgroundColor: "{colors.control-pressed}", textColor: "{colors.text}", rounded: "{rounded.control}", padding: "10px 14px"}
  button-disabled: {backgroundColor: "{colors.control-disabled}", textColor: "{colors.muted}", rounded: "{rounded.control}", padding: "10px 14px"}
  field: {backgroundColor: "{colors.input}", textColor: "{colors.text}", typography: "{typography.body}", rounded: "{rounded.control}", padding: "10px 14px"}
  panel: {backgroundColor: "{colors.panel}", rounded: "{rounded.control}", padding: "10px 14px"}
---
# Design System: GeoCommander

## Overview

**Creative North Star: "几何指挥台"**

原生桌面几何 RTS，战场与实验室以 Operate 为主，菜单、兵种档案和规则读数兼有 Read。当前扩展采用 Redesign-Preserve：继承深色网格、青蓝控件、金色协同与清晰文字，用真实几何战场解释战术，不替换现有视觉身份。

全部游戏视觉由几何和 shader 生成，只用系统字体，无外部图片、音频或打包字体。最低窗口为1280×720，面向键鼠操作；没有移动端或浅色主题。提示词实验室将编辑、校验、真实验证与正式开局应用分开呈现，状态与恢复动作优先于装饰。

**Key Characteristics:**

- 深色几何战术台，青蓝操作与金色协同语义。
- 全局100/115/130/150/180%字号，受限区域独立滚动，保留阅读位置。
- 世界HDR与界面文字分层，沿用系统低动效设置。

## Colors

前置token按Godot `Color`原值记录，保持既有命名和数值；世界HDR轮廓不压成普通UI色。

### Primary

- **青蓝操作色**（`accent`）：共享按钮悬停、按下、选中边界与输入光标，强调当前可操作对象。
- **浅青焦点色**（`focus`）：键盘焦点边界，和青蓝选中态保持区别。

### Secondary

- **协同金**（`gold`）：六边形、协同与支援语义；能源点也沿用金色世界视觉。红蓝阵营、黄青紫白金兵种轮廓保留独立游戏语义，并以形状、名称、中心点辅助识别。

### Neutral

- **冷白正文与灰蓝辅助色**（`text`、`muted`）：正文、说明和共享按钮禁用文字。
- **蓝黑底与面板**（`input`、`panel`）：编辑底色、实验室背景和分组面板；实验室背景使用不透明的`input`色。
- **控件状态层**（`control`及其状态token）：普通、悬停、按下和禁用的轻微明度差；对应描边保留结构。
- **输入选区**（`selection`）：可编辑文本的选择背景，不用世界发光代替文本选区。

**The Clear Text Rule.** 世界发光只表达几何与战斗状态，不影响标题、正文、输入值和按钮文字。

## Typography

共享`SystemFont`优先PingFang SC，其他候选为Microsoft YaHei、Noto Sans CJK SC、sans-serif。`font_names`仅选首个匹配家族；显式`Font.fallbacks`以Hiragino Sans GB等系统字体提供简体覆盖，不把候选列表当作逐字回退链。字体不打包进游戏。

前置字号为100%基准，经`GameSettings.font_px`统一换算100/115/130/150/180%，覆盖自绘文字与确认窗，不缩放世界。首页产品名、档案/设置/矩阵标题、正文与辅助说明沿用前置层级；主入口与实验室标题24、主句/计时32、演练标题26、核心数值和提示词栏标题22、设置分组20。窄窗名册与实验室来源模型、JSON编辑、规则、事件、反馈使用14；属性/状态15。正式战术矩阵JSON使用系统Menlo/monospace（15），实验室JSON沿用共享中文字体（16），两者不混同。

**The Stable Font Rule.** 复用稳定生命周期的Theme/SystemFont，在设置事件中原地更新。字体改动后检查“敌、远”等简体字形及原生日志，不用替换文案掩盖缺字。

## Layout

首页/选图按实际窗口布局，外边距32、底部44；首页左栏最小330，三主入口纵排，下方独立演练，右侧是真实地图预览。选图左栏最小300，底部返回与进入准备保持在正文外。

演练外边距24、主间距16；宽度<1600为顶部横向名册、下方档案和演武两列，≥1600为名册/档案/演武三列，≥1900扩大前两列。档案独立纵向滚动；演武820×680等比居中，状态和两列动作位于画布外。

实验室外边距16，始终保持“左侧编辑、右侧战场”两栏，不再设置第三数据栏。原生HSplitContainer默认将42%宽度分配给编辑区，左右可拖动，编辑区最小360、战场最小420。兵种条在宽度不足1600或字号超过130%时改为顶部选择菜单；编辑页签按文字实际宽度切换为选择菜单。

编辑区分为兵种提示词、JSON、步骤、整体提示词四页；整体提示词不常驻展开。原生VSplitContainer按可用高度分配编辑60%、反馈40%，拖动允许反馈30%至60%。反馈至少显示两行正文，1280×720的180%字号可因可读最小高度提高至约54%。反馈集中显示当前结果、来源模型及识别说明，长内容内部滚动，支持展开阅读。固定两行动作位于分隔区外：AI生成/取消生成与校验JSON；应用并重跑与应用开局。生成与取消复用同一槽位，避免忙状态改变布局。保存、LLM设置、示例、重试与恢复默认收进“更多”。

战场顶部为地图与状态、开始/暂停，以及地图、布阵、编辑、验证、显示五个任务菜单。布阵属性使用有界PopupPanel，关闭固定、正文纵向滚动。结果/规则/事件合并为战场内读数框，默认右上角、约40%宽和35%高，最大60%宽和65%高；大字号优先保证标题及操作可用。标题可拖动，底部调整柄可缩放，支持收起/关闭/恢复位置，内部以选择菜单切页。窗口与字号变化会将读数框约束回战场内。布局比例与位置只在当前运行内记忆，不写入实验方案。

设置四周留32，标题/关闭、四页签与底部状态/动作固定，中间正文滚动并跟随焦点。LLM字段和动作可滚入视口，Tab焦点不留在不可见位置。矩阵正文与JSON可滚动。

窗口模式按实际像素在1280×720、1440×810、1440×900和1920×1080之间响应式重排。进入全屏时捕获最后稳定的实际窗口布局作为逻辑画布，并通过`canvas_items / keep`将菜单、演练、实验室、HUD、弹层和世界整体等比缩放；手动改变过的窗口尺寸同样保留。游戏内显示设置与macOS原生全屏入口进入同一状态机。显示器宽高比不同时居中留边，不扩展可见区域，也不单独改变字体。字号档位在逻辑画布内继续独立生效。验收尺寸为上述窗口尺寸及Retina 2×全屏，最小窗口重点检查130%和180%字号；不定义手机或平板重排。

**The Bounded Reading Rule.** 长正文、JSON、反馈和实时读数在各自区域内滚动；正文长度不能将取消、应用、关闭或底部消息挤出窗口。

## Elevation & Depth

平面深底、细边界与遮罩分层，无投影体系。世界HDR发光只影响Canvas 0；菜单/HUD/演武读数及实验室控件在CanvasLayer 10，设置在30。演武有独立World2D与HDR SubViewport，读数用深底金字；实验室同样使用独立World2D与HDR SubViewport，真实地图和战斗发光留在世界中，文字与按钮边缘保持清晰。HDR截图先经线性到sRGB编码后验收。

## Shapes

兵种为三角、正方、圆、菱形、六边形；内填充缩放表达生命，中心点辅助识别阵营。共享控件沿用前置圆角与内边距，普通边框1，按下/选中和焦点2。灰蓝棱角掩体、青白菱形晶簇、琥珀六边形减速区、金色能源圆环与红蓝基地共同构成地图语义。实验室使用这些真实地图实体，不以UI矩形代替战场。

## Components

### Buttons and Navigation

共享按钮有普通/悬停/按下/禁用/浅青焦点状态，最低高度44；首页动作52、三主入口62、地图选项84。实验室五兵种与设置分类使用原生按钮的toggle选中态。原生TabContainer承载编辑与读数页面，TabBar或OptionButton按可用宽度提供切换；原生菜单与弹出面板复用既有主题。多人明确“开发中”，创建/加入禁用并解释原因。

### Inputs and Feedback

LineEdit和TextEdit复用共享深底、描边、文字、光标与选区；字段标签置于上方。实验室JSON、规则和事件自动折行，读数为原生只读TextEdit。只读TextEdit与可编辑字段共用蓝黑底、浅色文字和清晰边界。中文输入和模态界面阻断战场快捷键。错误就近说明原因、保留内容和可执行的恢复动作，长消息可独立滚动；保存重试仅在未保存状态出现。

### Prompt Editor

五兵种分别读取草稿、有效JSON和来源模型。编辑、AI生成、严格JSON校验、应用并重跑、应用为开局为明确分离的动作；“应用当前兵种为开局”只作用于当前兵种，且仅本次运行生效。生成成功切到JSON页供检查，不自动应用正式开局。忙时禁用编辑、生成和两项应用，固定动作区的取消保持可见可用，位置与生成按钮相同。失败或取消保留上一份有效规则；JSON错误写明字段原因、“上一份有效JSON与验证场保持”及校验或重新生成的下一步。

### Laboratory World and Readouts

六图与预览共用`MapCatalog`，规则相同、真实地形不同，地图和预设名称与实际布阵同步。实验室在独立世界中运行双方自主AI；左键放置/选中，拖动后松开调整位置，滚轮缩放，中键平移，战场焦点下Delete/Backspace删除。生命和朝向既编辑选中单位，也作为下次放置默认值。运行及暂停时禁用阵容编辑；暂停按钮切换“暂停/继续”，重置回到可编辑布阵。

结果、规则、事件在可移动的悬浮读数框内组织，操作不穿透到战场；无事件时解释何时会记录真实事件，不填演示数据。`ReadoutText`仅在文本变化时写回，并恢复滚动、光标和可保留的选区，使持续更新不打断阅读。应用重跑与默认战术对照复用同一初始阵容与种子；读数来自真实战斗，不将短时演示冒充验证结果。固定演武仍调用真实机制并单独说明教学冷却加速，实验室使用正式冷却与1×速度。

### Settings and LLM

设置有显示、界面、LLM、操作与关于四页。普通修改即时生效并本机持久化；显示变化15秒确认，超时/取消/关闭回退。战中及实验室打开设置暂停推进，关闭恢复原暂停态、焦点及草稿，Tab/Shift+Tab留在面板，Esc关闭。原生ConfirmationDialog保留显示确认和15秒回退，正文改为内部滚动；实验室确认与展开反馈共享独立遮罩层，标题与动作固定，焦点限制在弹层并在关闭后恢复。

LLM页的Base URL、API Key、模型ID均有明确标签，Key以secret字段遮罩且仅存本次进程内存。模型列表不可用时仍可手填，获取模型、测试连接和取消请求提供独立状态反馈；请求中禁用获取/测试，启用取消。更改配置使旧测试状态失效。URL/模型与实验保存失败分别提示并提供重试，恢复游戏默认不删除实验或LLM连接。

### Motion

低动效由本机持久化设置统一驱动：关闭网格扫描、名册旋转与拖尾，减少碎片，取消场景淡出（普通0.18秒）和属性条过渡（普通0.25秒）。实验室返回沿用此设置；真实战斗与规则读数保持功能性更新。

## Do's and Don'ts

### Do:

- **Do** 复用CommanderTheme、稳定的系统字体、真实地图与战斗机制，保留几何指挥台的视觉身份。
- **Do** 保持桌面窗口边界、独立滚动、固定取消与应用动作、清晰键盘焦点及HDR文字分层。
- **Do** 用真实字段与按钮名解释错误、已保留内容和恢复动作；让实时读数保留用户阅读位置。
- **Do** 在1280×720的180%字号及1920×1080两栏状态中检查原生截图与实际输入流程。

### Don't:

- **Don't** 引入外部图片、音频、打包字体，或虚构演武、截图、事件与战斗结果。
- **Don't** 缩小全局字号掩盖布局越界，或让长正文把固定操作挤出窗口。
- **Don't** 用替换中文文案掩盖缺字，把世界发光施加到正文，或将原生控件描述为运行时Web组件。
- **Don't** 自动将生成结果应用到正式开局，或混同单兵种实验应用、单兵种开局与整队关键词提交。

本次布局以实际原生Metal运行与[16张截图清单](artifacts/lab-layout-report.json)为依据，168项布局与操作断言通过、0失败、裁切扫描0项。截图覆盖三个桌面尺寸的100/130/180%字号、四页编辑、长错误、展开反馈、布阵属性及设置确认；五档字号往返另有原生断言。具体验证结果、局部回滚与边界见[布局验证记录](docs/laboratory-layout-verification.md)。

未引入Web构建、第三方UI或新素材。本轮未调用Apple HIG技能，Godot文档站访问受限时以官方引擎源码和实际运行作为原生容器行为依据。真实供应商请求、其他操作系统、中文输入法候选窗与屏幕阅读器不由本次布局检查认证；本地HTTP模拟与真实供应商历史记录分开保留。
