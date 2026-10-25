# 原生 UI 布局与输入排查

修改全局字号、实验室分隔布局、菜单、弹层或悬浮控件时阅读。

- 占比必须依据父容器实际可分配高度计算，不能用 `custom_minimum_size` 冒充比例。分隔拖动只记录用户操作，在窗口或字号变化后用绝对偏移恢复比例，避免累加布局偏移。可读最小尺寸与目标比例冲突时，先保证核心操作与正文可读，并记录实际比例。
- 字号尺寸从不可变基准和当前字号重新计算，不从上一档已放大的高度取最大值。字体与 Theme 复用现有生命周期，覆盖五档字号往返，检查 180% 回到 100% 后实际高度恢复。
- 有界 `PopupPanel` 不能让 `wrap_controls` 按临时换行最小高度把窗口撑大。窗口控制外框尺寸，正文使用独立滚动；子节点最小高度改变后重新分配内部尺寸，标题和关闭入口保持固定。
- `MOUSE_FILTER_STOP` 默认仍可能向父控件传递滚轮。覆盖在战场上的读数框须按需关闭 `mouse_force_pass_scroll_events`，用真实滚轮验证不会触发下层缩放。按钮、拖动、调整尺寸及弹层同样验证不穿透。
- `MenuButton` 默认焦点模式不保证普通 Tab 可达。需要键盘操作的任务菜单显式使用 `FOCUS_ALL`，验证 Tab、Space/Enter、方向键和 Esc。打开菜单先取消未完成的单位或航点拖动。
- 测试嵌入式 PopupMenu 键盘输入须经过 Window 的输入分发；只向 `Viewport.push_input()` 注入不能覆盖该路径。合成鼠标与滚轮事件应发送成对按下/释放，通过实际方向键导航菜单，避免直接设置焦点被原生鼠标事件覆盖。
- 原生全屏测试先取得前台焦点，等待真实模式与尺寸切换完成后再反向操作，不能只凭调用完成判定 AppKit 过渡结束。
- 全屏缩放由`GameSettings`统一维护：窗口模式使用原生像素响应式布局，正常窗口几何稳定后记录实际逻辑尺寸；进入全屏时以该尺寸为逻辑画布并使用`canvas_items / keep`整体等比缩放。macOS绿色按钮会先发送屏幕尺寸的`size_changed`，稍后才更新`Window.mode`；过渡尺寸须进入临时状态，不得仅按mode或稳定帧数覆盖原窗口记录。全屏模式确认后提交，恢复窗口几何则撤销临时状态。场景脚本不得自行设置画布尺寸，也不得用保存分辨率代替用户眼前的窗口布局。
- 系统绿色按钮、直接`Window.mode`赋值和游戏内设置属于不同事件入口，测试结论必须分别记录。直接赋值通过不能证明真实系统按钮通过；系统按钮用`tests/fullscreen_titlebar_native.tscn`配合实际点击验证，并记录进入、退出、过渡期间的原画布和控件布局。

- 战场镜头边界按当前实际 `Camera2D.zoom` 与视口计算，逐轴使用 `中心 ± max(地图半尺寸 − 视野半尺寸, 0)`；视野超过地图的轴固定在中心，禁止把颠倒的上下界传给 `clamp`。矩阵和文本焦点只屏蔽操作，不跳过边界维护。验收须采样平滑收敛后的 `get_screen_center_position()`，不能仅比较节点 `position`，使用 `tests/camera_regression_runner.tscn` 与 `tests/camera_native_runner.tscn`。

验收使用 `tests/lab_layout_native.tscn`、`tests/lab_menu_native.tscn`、`tests/launcher_native_flow.tscn`、`tests/fullscreen_scale_native.tscn` 与交互式 `tests/fullscreen_titlebar_native.tscn`。前者需要本地 `tests/llm_mock_server.py`。原生窗口测试顺序运行，并带 `-- --geo-test`。检查可裁切祖先的实际交集、相邻控件重叠、点击隔离与真实截图，不能仅断言节点坐标在窗口内。
