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
- 全局100/115/130%字号，受限区域独立滚动，保留阅读位置。
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

前置字号为100%基准，经`GameSettings.font_px`统一换算100/115/130%，覆盖自绘文字与确认窗，不缩放世界。首页产品名、档案/设置/矩阵标题、正文与辅助说明沿用前置层级；主入口与实验室标题24、主句/计时32、演练标题26、核心数值和提示词栏标题22、设置分组20。窄窗名册与实验室来源模型、JSON编辑、规则、事件、反馈使用14；属性/状态15。正式战术矩阵JSON使用系统Menlo/monospace（15），实验室JSON沿用共享中文字体（14），两者不混同。

**The Stable Font Rule.** 复用稳定生命周期的Theme/SystemFont，在设置事件中原地更新。字体改动后检查“敌、远”等简体字形及原生日志，不用替换文案掩盖缺字。

## Layout

首页/选图按实际窗口布局，外边距32、底部44；首页左栏最小330，三主入口纵排，下方独立演练，右侧是真实地图预览。选图左栏最小300，底部返回与进入准备保持在正文外。

演练外边距24、主间距16；宽度<1600为顶部横向名册、下方档案和演武两列，≥1600为名册/档案/演武三列，≥1900扩大前两列。档案独立纵向滚动；演武820×680等比居中，状态和两列动作位于画布外。

实验室外边距18，顶行标题/返回/设置，其下为五兵种横向选择。左侧编辑面板最小宽340；中间战场列扩展填充。宽度<1700为编辑/战场两栏，结果、规则读数、事件页签置于战场下方，读数区最小高150；≥1700将读数移到独立第三栏，最小宽为330乘字号倍率，130%时为429。1280/1440保持两栏，1920在100%和130%均为三栏。此断点按窗口宽度决定，不因大字号强制退回两栏。

提示词与JSON各有独立的正文滚动容器，页签区最小高180，内部编辑框最小高80；长反馈另有最小高72的独立滚动区。固定标题行放“取消生成”，两项应用动作位于正文外，底部全局消息位于主列外缘。最小窗口的大字号允许正文和读数滚动，不要求所有行同时展示。地图/预设、放置参数与验证动作使用流式容器换行；世界显示区最小300×160，按可用空间缩放2400×1350战场，不裁掉控件以扩大画面。

设置四周留32，标题/关闭、四页签与底部状态/动作固定，中间正文滚动并跟随焦点。LLM字段和动作可滚入视口，Tab焦点不留在不可见位置。矩阵正文与JSON可滚动。

正式战场HUD保留1920×1080逻辑视口与`canvas_items / expand`；顶部核心/计时/资源，底部部署/终端/技能，字号变化抬高底栏并扩大矩阵。菜单、演练和实验室关闭逻辑缩放，不能混同为全局固定画布。验收尺寸为1280×720、1440×900、1920×1080及Retina 2×，最小窗口重点检查130%字号；不定义手机或平板重排。

**The Bounded Reading Rule.** 长正文、JSON、反馈和实时读数在各自区域内滚动；正文长度不能将取消、应用、关闭或底部消息挤出窗口。

## Elevation & Depth

平面深底、细边界与遮罩分层，无投影体系。世界HDR发光只影响Canvas 0；菜单/HUD/演武读数及实验室控件在CanvasLayer 10，设置在30。演武有独立World2D与HDR SubViewport，读数用深底金字；实验室同样使用独立World2D与HDR SubViewport，真实地图和战斗发光留在世界中，文字与按钮边缘保持清晰。HDR截图先经线性到sRGB编码后验收。

## Shapes

兵种为三角、正方、圆、菱形、六边形；内填充缩放表达生命，中心点辅助识别阵营。共享控件沿用前置圆角与内边距，普通边框1，按下/选中和焦点2。灰蓝棱角掩体、青白菱形晶簇、琥珀六边形减速区、金色能源圆环与红蓝基地共同构成地图语义。实验室使用这些真实地图实体，不以UI矩形代替战场。

## Components

### Buttons and Navigation

共享按钮有普通/悬停/按下/禁用/浅青焦点状态，最低高度44；首页动作52、三主入口62、地图选项84。实验室五兵种与设置分类使用原生按钮的toggle选中态。原生TabContainer承载提示词/JSON及结果/规则/事件切换，保留其原生深底与活动页签指示，不伪造另一套Web页签。多人明确“开发中”，创建/加入禁用并解释原因。

### Inputs and Feedback

LineEdit和TextEdit复用共享深底、描边、文字、光标与选区；字段标签置于上方。实验室JSON、规则和事件自动折行，读数为原生只读TextEdit。只读背景及文字保留引擎实际样式，不将它们误记为共享可编辑字段token。中文输入和模态界面阻断战场快捷键。错误就近说明原因、保留内容和可执行的恢复动作，长消息可独立滚动；保存重试仅在未保存状态出现。

### Prompt Editor

五兵种分别读取草稿、有效JSON和来源模型。编辑、AI生成、严格JSON校验、应用并重跑、应用为开局为明确分离的动作；“应用当前兵种为开局”只作用于当前兵种，且仅本次运行生效。生成成功切到JSON页供检查，不自动应用正式开局。忙时禁用编辑、生成和两项应用，固定标题行的取消保持可见可用。失败或取消保留上一份有效规则；JSON错误写明字段原因、“上一份有效JSON与验证场保持”及校验或重新生成的下一步。

### Laboratory World and Readouts

三图与预览共用`MapCatalog`，规则相同、真实地形不同，地图和预设名称与实际布阵同步。实验室在独立世界中运行双方自主AI；左键放置/选中，拖动后松开调整位置，滚轮缩放，中键平移，战场焦点下Delete/Backspace删除。生命和朝向既编辑选中单位，也作为下次放置默认值。运行及暂停时禁用阵容编辑；暂停按钮切换“暂停/继续”，重置回到可编辑布阵。

结果、规则、事件按页签组织；无事件时解释何时会记录真实事件，不填演示数据。`ReadoutText`仅在文本变化时写回，并恢复滚动、光标和可保留的选区，使持续更新不打断阅读。应用重跑与默认战术对照复用同一初始阵容与种子；读数来自真实战斗，不将短时演示冒充验证结果。固定演武仍调用真实机制并单独说明教学冷却加速，实验室使用正式冷却与1×速度。

### Settings and LLM

设置有显示、界面、LLM、操作与关于四页。普通修改即时生效并本机持久化；显示变化15秒确认，超时/取消/关闭回退。战中及实验室打开设置暂停推进，关闭恢复原暂停态、焦点及草稿，Tab/Shift+Tab留在面板，Esc关闭。Godot原生灰色ConfirmationDialog不推广为全局配色，内容随字号更新。

LLM页的Base URL、API Key、模型ID均有明确标签，Key以secret字段遮罩且仅存本次进程内存。模型列表不可用时仍可手填，获取模型、测试连接和取消请求提供独立状态反馈；请求中禁用获取/测试，启用取消。更改配置使旧测试状态失效。URL/模型与实验保存失败分别提示并提供重试，恢复游戏默认不删除实验或LLM连接。

### Motion

低动效由本机持久化设置统一驱动：关闭网格扫描、名册旋转与拖尾，减少碎片，取消场景淡出（普通0.18秒）和属性条过渡（普通0.25秒）。实验室返回沿用此设置；真实战斗与规则读数保持功能性更新。

## Do's and Don'ts

### Do:

- **Do** 复用CommanderTheme、稳定的系统字体、真实地图与战斗机制，保留几何指挥台的视觉身份。
- **Do** 保持桌面窗口边界、独立滚动、固定取消与应用动作、清晰键盘焦点及HDR文字分层。
- **Do** 用真实字段与按钮名解释错误、已保留内容和恢复动作；让实时读数保留用户阅读位置。
- **Do** 在1280×720大字号及1920×1080三栏状态中检查原生截图与实际输入流程。

### Don't:

- **Don't** 引入外部图片、音频、打包字体，或虚构演武、截图、事件与战斗结果。
- **Don't** 缩小全局字号掩盖布局越界，或让长正文把固定操作挤出窗口。
- **Don't** 用替换中文文案掩盖缺字，把世界发光施加到正文，或将原生控件描述为运行时Web组件。
- **Don't** 自动将生成结果应用到正式开局，或混同单兵种实验应用、单兵种开局与整队关键词提交。

本次增量以当前源码、[14张实验室截图清单](artifacts/ai-lab-visual-report.json)、[3张焦点与阅读截图清单](artifacts/ai-lab-focus-report.json)及[独立最终复核](artifacts/ai-lab-finish-review.md)为依据；布局扫描`overflow=[]`，最终`ship`仅覆盖F1-F8已评分修复项。文档刷新实际查看了最小窗口130%编辑、生成、JSON错误、1920宽屏130%和设置动作焦点截图；并读取既有验证记录的539项通过/0失败、69脚本编译/0失败，未在文档阶段重跑测试。旧入口继续参考[原生截图清单](artifacts/launcher-visual-report.json)及其[最终复核](artifacts/launcher-finish-review.md)。

sidecar仅扩展原生布局断点、动效与叙述，不生成HTML/CSS近似组件或不存在的色阶。未运行Web检测器或Apple HIG技能；真实LLM供应商、其他系统、中文输入法候选窗、屏幕阅读器及长期性能不由此设计记录认证，验证边界见[实验室验证](docs/ai-laboratory-verification.md)。
