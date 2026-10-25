# 战斗开始后的镜头抖动修复

本机环境：Godot 4.7.2 Stable、Forward+、Metal 4.0、Apple M5、Retina 2×。本轮仅修改战场镜头、增加回归与验证说明，保留此前工作区改动，不提交或推送。

## 原因和行为

HUD 使用独立 CanvasLayer，因此录屏中 HUD 稳定而战场偏移。1920×1080 逻辑视口、默认缩放 0.68 时，视野约 2824×1588，大于 2400×1350 地图。原实现直接把视野半尺寸和地图尺寸减视野半尺寸作为 `clamp` 上下界，产生最小值大于最大值。镜头目标在 `(1411.765,794.118)` 和 `(988.235,555.882)` 间交替。矩阵打开时提前返回，开始战斗关闭矩阵后才暴露问题。

`camera_rig.gd` 现在按横纵轴使用 `中心 ± max(地图半尺寸 − 当前视野半尺寸, 0)`。视野较大的轴居中，较小的轴继续允许平移；视野依据实际 `zoom`，而非仍在过渡的目标倍率。矩阵和文本编辑只屏蔽移动与滚轮，边界仍随窗口尺寸和缩放维护。850 移速、速度倍率、0.48–1.4 缩放范围及平滑效果保持原样。

## 验证

| 检查 | 结果 |
| --- | --- |
| 全工程导入 | 退出 0，无解析和缺失资源错误 |
| 真实 Autoload 脚本检查 | 109 文件，0 失败 |
| 镜头行为回归 | 47/47 |
| 既有战斗规则 | 76/76 |
| 六图移动意图回归 | 60/60 |
| 原生三尺寸与设置全屏 | 15/15 |
| 真实系统绿色按钮 | 8/8 |
| 既有原生设置与镜头速度检查 | 20/20 |

镜头行为回归覆盖视野小于、等于、大于地图及仅一个轴超出，四边移动、速度倍率、连续缩放、矩阵和文本焦点期间调整窗口、准备转战斗、暂停恢复及真实场景重载。1280×720、1440×900、1920×1080，分别在 0.48、0.68、1.4 缩放下，稳定后连续采样 300 帧，目标和实际画面中心波动均为 0。

原生 Metal 使用真实渲染、真实时间和保留的平滑，另采样 300 帧。原生结果以 JSON 中的 `screen_center_drift` 为准，验收阈值为 0.1 世界单位。设置入口和真实绿色按钮分别验证逻辑画布、镜头稳定性与退出恢复。绿色按钮通过系统 UI 实际点击进入，系统 Window 菜单退出，没有使用 `Window.mode` 赋值冒充。

鼠标验证分为两部分：三尺寸和全屏下的输出坐标与世界坐标往返，以及窗口/系统全屏中的真实鼠标点击。真实点击记录实际技能调用点、当时的世界鼠标位置与生成的超频区，允许 AppKit 事件取整的一输出像素误差。合成 `Input.parse_input_event` 不会移动原生系统鼠标，不能用于证明 `get_global_mouse_position()` 的实际点击位置。初次夹具因此失败，已改用真实点击，不涉及产品逻辑修补。

原生日志中的 `IMKCFRunLoopWakeUpReliable` 是 macOS 输入法端口提示；通过的最终日志无 Godot 脚本或资源错误。

## 对照录制与记录

[修复前后对照录像](../artifacts/camera-jitter/before-after.mp4)，左侧 BEFORE，右侧 AFTER。两侧使用同一固定种子、同一地图和 1920×1080 / 0.68 镜头配置，各取开始战斗后 90 个原生渲染帧，以 60 FPS 并排播放并重复三次。画面来自实际 HDR 帧缓冲，按真实 RGBH 格式经过线性到 sRGB 转换；仅等比缩小、添加对照标题，没有稳定画面或改动单位轨迹。录制采用固定模拟步长；实时原生验证单独进行。

修复前录像夹具明确失败：目标位置波动约 **485.94** 世界单位，实际画面中心波动约 **94.87** 世界单位。修复后相同录制条件下两者均为 **0**，固定墙体和基地不再往返移动。原生截图也已目视检查。

本机记录位于 `artifacts/camera-jitter/`，该目录按项目规则不进入 Git：

- `regression-report.json`、`regression.log`：镜头回归。
- `native-before-video-report.json`、`native-after-video-report.json`：对照录像与稳定性采样。
- `native-after-report.json`：三种窗口尺寸、设置全屏、技能坐标与恢复窗口。
- `native-titlebar-report.json`：真实绿色按钮、真实鼠标、退出恢复。
- `check-scripts.log`、`import.log`、`rules.log`、`movement-intent.log`、`launcher-native.log`：工程和既有回归。
- `camera_rig.before.gd`、`camera-fix.patch`：本轮修改前快照和独立差异。

[窗口 1920×1080 截图](../artifacts/camera-jitter/window-1920x1080.png) · [设置全屏截图](../artifacts/camera-jitter/settings-fullscreen.png) · [系统绿色按钮全屏截图](../artifacts/camera-jitter/titlebar-fullscreen.png)

## 重跑与回滚

```sh
./run.command --headless --import
./run.command --headless --scene res://tests/check_scripts.tscn -- --geo-test
./run.command --headless --fixed-fps 60 --scene res://tests/camera_regression_runner.tscn -- --geo-test
./run.command --headless --fixed-fps 60 --scene res://tests/movement_intent_runner.tscn -- --geo-test
./run.command --headless --fixed-fps 60 --scene res://tests/test_runner.tscn -- --geo-test
./run.command --scene res://tests/camera_native_runner.tscn -- --geo-test
./run.command --scene res://tests/camera_native_runner.tscn -- --geo-test --camera-titlebar
./run.command --scene res://tests/launcher_native_flow.tscn -- --geo-test
```

原生测试顺序运行。`--camera-titlebar` 按日志提示依次点击窗口战场、实际绿色按钮、全屏战场，再通过系统 Window 菜单退出。它需要桌面可操作且不被其他原生 Godot 测试抢占。`--camera-mouse` 可选，在设置全屏中增加真实鼠标检查。

录像使用 `--fixed-fps 60 -- --geo-test --camera-video`，对照旧版另加 `--camera-before`，后者要求先存在本轮修改前快照。使用 `python3 tests/encode_captures.py camera-jitter/native-after-report.json` 等入口转换截图；录像源帧同样通过现有编码脚本转换。

回滚仅恢复 `artifacts/camera-jitter/camera_rig.before.gd` 到 `scripts/core/camera_rig.gd`，并移除本轮两套镜头测试及本说明。不要按 Git HEAD 还原该脚本，因为 HEAD 之前还存在用户尚未提交的地图边界改动。快照 SHA-256：`0467efca267497de341a9be1ad37bd0582fd1dd017dc022b422703e8d1e7db3b`。
