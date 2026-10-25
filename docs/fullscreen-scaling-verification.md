# 全屏等比缩放验证

2026-10-24，本机 Godot 4.7.2 Stable、Forward+、Metal 4.0、Apple M5、Retina 2×。

## 行为

窗口模式继续使用实际窗口像素进行响应式布局，并记录正常窗口几何下稳定的实际逻辑尺寸。切换全屏时，这份眼前的布局成为逻辑画布，`canvas_items / keep`将文字、按钮、面板、弹窗、战场和特效统一等比放大。即使保存分辨率是1440×810、窗口后来被手动调整为1920×1080，全屏也继承1920×1080的当前排版。显示器宽高比与逻辑画布不同时居中留边，不拉伸画面，也不扩展布局空间。全局字号仍是独立设置，在逻辑画布内生效。

缩放生命周期由`GameSettings`统一维护，并观察实际`Window.mode`变化。首页、兵种演练和提示词实验室不再进入时关闭缩放、离开时写回固定画布，因此场景切换不会改变全屏呈现。游戏内切换仍使用原有15秒确认和回退；macOS窗口原生全屏控制即使绕过设置面板，也会进入相同缩放状态并同步界面设置值。

## 系统绿色按钮的根因与修复

真实点击绿色按钮时，AppKit先发送屏幕尺寸的`size_changed`，此时`Window.mode`仍为窗口模式；本机约0.7秒后才确认全屏。此前仅凭窗口模式和稳定帧数记录尺寸，会将3420×2136屏幕尺寸误记成原窗口布局，导致全屏重新排版而非等比放大。修复前事件记录在`artifacts/titlebar-trace-before-fix.json`。

`GameSettings`现在监听窗口几何变化。当macOS发送尚未确认模式的屏幕尺寸时，进入`native_fullscreen_pending`临时状态，立即沿用最后正常窗口的逻辑画布，暂停覆盖窗口尺寸记录。全屏模式确认后提交该状态；若恢复普通窗口几何则撤销。退出全屏后恢复原生像素布局。修复依据事件所有权和模式确认，没有增加等待延时。

Godot的[macOS窗口代理源码](https://raw.githubusercontent.com/godotengine/godot/master/platform/macos/godot_window_delegate.mm)也区分`windowWillEnterFullScreen`与`windowDidEnterFullScreen`，不能假定尺寸和全屏模式同时更新。

## 验证结果

三种入口分别验证，直接赋值`Window.mode`的结果不作为真实绿色按钮的证据。

| 入口或检查 | 结果 | 验证内容 |
| --- | --- | --- |
| 实际点击系统绿色按钮 | 16/16 | 首页1440×810、150%字号；演练1920×1080、180%字号。进入前、过渡期间、全屏和退出均保持原画布，21个首页控件、65个演练控件的逻辑矩形保持一致 |
| 直接`Window.mode`赋值 | 12/12 | 保存分辨率1440×810、实际窗口1920×1080；全屏继承实际布局，鼠标命中演武开关，退出恢复窗口 |
| 游戏内设置 | 20/20 | 显示确认与回退、全屏倍率、有界确认窗、字号、焦点、暂停和镜头 |
| 无界面导入 | 退出0 | 无导入错误 |
| 全工程脚本 | 97文件，0失败 | 使用真实Autoload上下文 |
| 首页与设置回归 | 102/102 | 设置、地图、导航等既有行为 |
| 场景流程 | 12/12 | 开局、返回及相关生命周期 |

真实按钮交互夹具`tests/fullscreen_titlebar_native.tscn`不赋值`Window.mode`。本轮通过实际系统UI点击进入，并使用系统`Window → 退出全屏幕`退出。报告包含尺寸、模式、画布、临时状态及事件顺序：[完整报告](../artifacts/titlebar-fullscreen-report.json)。

| 页面 | 窗口截图 | 真实系统全屏截图 |
| --- | --- | --- |
| 首页，150%字号 | [1440×810](../artifacts/titlebar-home-windowed.png) | [等比全屏](../artifacts/titlebar-home-fullscreen.png) |
| 兵种演练，180%字号 | [1920×1080](../artifacts/titlebar-academy-windowed.png) | [等比全屏](../artifacts/titlebar-academy-fullscreen.png) |

上述截图已目视检查。全屏内容图为3420×1923的16:9区域，3420×2136屏幕剩余高度为`keep`产生的居中留边。原始RGBH像素通过`tests/encode_captures.py`按线性到sRGB编码，没有修改画面元素。直接mode测试另见`artifacts/fullscreen-scale-report.json`。

本轮日志为`artifacts/titlebar-import.log`、`titlebar-script-check.log`、`titlebar-launcher-tests.log`、`titlebar-scene-flow.log`、`titlebar-native-settings.log`和`titlebar-direct-mode.log`。这些本机验收产物不随Git分发，可通过下面的命令重新生成。

## 复现

```sh
./run.command --headless --import
./run.command --headless --scene res://tests/check_scripts.tscn -- --geo-test
./run.command --scene res://tests/launcher_native_flow.tscn -- --geo-test
./run.command --scene res://tests/fullscreen_scale_native.tscn -- --geo-test
./run.command --scene res://tests/fullscreen_titlebar_native.tscn -- --geo-test
python3 tests/encode_captures.py fullscreen-scale-report.json
python3 tests/encode_captures.py titlebar-fullscreen-report.json
```

原生测试顺序运行。交互夹具按终端提示，分别在首页和演练点击真实绿色按钮，然后使用系统Window菜单退出全屏。它需要人工或原生UI自动化输入；运行命令本身不会替代点击。macOS原生全屏是异步Space切换，应等待模式与实际尺寸稳定、AppKit过渡结束后再反向操作，不能只检查`Window.mode`赋值。
