# Master Upgrade Specification: Hybrid Human-AI Command, Per-Class Squad Micro, I/O/P Co-Pilot & Custom Keybindings
> **Target Project**: GeoCommander (Godot 4.3+ Procedural Geometry RTS)  
> **Document Role**: Unified Master Specification (Merges Live Micro, Ergonomic Controls & AI Co-Pilot V4)  
> **Asset Policy**: 100% Procedural Geometry (`Polygon2D`, `Line2D`, `_draw()`, `StyleBoxFlat`). Zero external textures.

---

## 0. ARCHITECTURAL SUMMARY OF THIS UPGRADE

1. **Global Custom Keybinding System (`KeybindManager`)**: Zero-conflict default keymap with full player rebinding UI, automatic conflict swapping, `user://keybinds.json` persistence, and a strict text-input focus guard so typing prompts never triggers hotkeys.
2. **Mouse-Only RTS Camera (`camera_rig.gd`)**: Removes `WASD` camera movement to free the left hand for combat micro. Uses **Mouse Wheel Smooth Zoom + Middle-Mouse Button (MMB) Drag Pan + 4-Edge Screen Hover Panning**.
3. **RTS Box-Selection & 3-State Control Handshake (`selection_manager.gd` & `base_geo_unit.gd`)**: Seamless transition between `AUTO_AGENT` (Global AI), `MANUAL_OVERRIDE` (Right-Click move/focus-fire), and `SQUAD_AI_SCOPED` (Per-squad custom AI prompt or `Shift + Right-Drag` tactical path drawing).
4. **Mixed-Squad Per-Class Skill Casting (`Q / W / E / R / F` + Clickable HUD Skill Slots)**: When a mixed squad is selected, each geometric class uses its own dedicated hotkey (`Q` Triangle, `W` Square, `E` Circle, `R` Diamond, `F` Hexagon) to Quick-Cast toward the mouse cursor, or players can click the HUD Squad Skill Slot to aim with a targeting reticle.
5. **Live AI Tactical Co-Pilot (`ai_copilot_analyst.gd`)**: Evaluates a live battlefield telemetry snapshot every 8 seconds (or on major events), respects a customizable **AI Co-Pilot Persona Prompt (`参谋提示词设置`)**, and presents **3 Ranked Tactical Proposals (`I` = #1 Highest Recommendation, `O` = #2, `P` = #3)** selectable via `I/O/P` keys, mouse clicks, or **Auto-Delegate Mode (automatically executes Option 1 `I`)**.

---

## 1. GLOBAL KEYBIND MANAGER & CUSTOM KEYBINDING UI

### 1.1 `scripts/core/keybind_manager.gd` (Autoload: `KeybindManager`)
Register `KeybindManager="*res://scripts/core/keybind_manager.gd"` in `project.godot`.

- **Mandatory Text-Input Focus Guard**:
  Whenever `get_viewport().gui_get_focus_owner()` is a `LineEdit` or `TextEdit`, `KeybindManager.is_action_just_pressed(action_id)` MUST return `false` so typing inside any prompt terminal never triggers skills, unit spawns, or AI Co-Pilot keys!
- **Zero-Conflict Default Keybinding Table (`DEFAULT_BINDINGS`)**:
  ```gdscript
  const DEFAULT_BINDINGS: Dictionary = {
      # --- 1. Per-Class Selected Squad Active Skills (混编小队分兵种独立技能) ---
      "skill_triangle": KEY_Q,          # ▲ 正三角形: 锐角穿刺 (Apex Dash)
      "skill_square": KEY_W,            # ■ 正方形: 动态棱镜 (Prism Barrier)
      "skill_circle": KEY_E,            # ● 圆形: 轨道坍缩 (Orbital Collapse)
      "skill_diamond": KEY_R,           # ◆ 菱形: 聚焦激光 (Refracting Beam)
      "skill_hexagon": KEY_F,           # ⬢ 正六边形: 全域共鸣 (Command Resonance)

      # --- 2. Squad Micro & Authority Handshake (小队微操与控制权移交) ---
      "squad_hold_orbit": KEY_A,        # 小队驻守环绕游走 (Hold & Orbit Area)
      "squad_return_ai": KEY_G,         # 一键归还 AI 托管 (Return to AI Agent)

      # --- 3. Unit Production Cards (左下角兵种生产投放) ---
      "spawn_triangle": KEY_1,          # 生产 ▲ 正三角形
      "spawn_square": KEY_2,            # 生产 ■ 正方形
      "spawn_circle": KEY_3,            # 生产 ● 圆形
      "spawn_diamond": KEY_4,           # 生产 ◆ 菱形
      "spawn_hexagon": KEY_5,           # 生产 ⬢ 正六边形

      # --- 4. Global Commander Support Abilities (右下角全局支援技能) ---
      "cmd_emp": KEY_Z,                 # 电磁脉冲 (EMP Strike)
      "cmd_overclock": KEY_X,           # 超频力场 (Overclock Field)
      "cmd_swap": KEY_C,                # 拓扑重组 (Topology Warp Swap)

      # --- 5. AI Co-Pilot Ranked Decisions (AI参谋三级推荐方案选择) ---
      "copilot_opt_1": KEY_I,           # 采纳方案 1 (推荐度最高 ★)
      "copilot_opt_2": KEY_O,           # 采纳方案 2 (推荐度次高)
      "copilot_opt_3": KEY_P,           # 采纳方案 3 (奇策备选)
      "copilot_toggle_auto": KEY_U,     # 切换 AI 参谋【自动代理】开关

      # --- 6. Tactical UI & Modals ---
      "toggle_tactical_drawer": KEY_TAB # 展开/收起战前与战中 AI 配置面板
  }
  ```
- **API & Persistence (`user://keybinds.json`)**:
  - `get_key_label(action_id: String) -> String` (e.g., returns `"Q"`, `"I"`, `"1"` via `OS.get_keycode_string()`).
  - `rebind_action(action_id: String, new_key: Key) -> String`: If `new_key` is already bound to `other_action`, automatically swap their keycodes so duplicate conflicts never exist, emit `SignalBus.keybinds_updated`, and save to `user://keybinds.json`.
  - `reset_to_defaults()`: Restores `DEFAULT_BINDINGS` and saves.

### 1.2 Key Rebinding Modal (`scripts/ui/keybind_settings_modal.gd`)
- Accessible via `[ ⌨ 按键设置 ]` button on both the Main Menu and In-Game Top HUD bar.
- Lists all actions grouped by category with clickable `[ 当前按键 ]` buttons.
- Clicking a button enters `"请按下新按键... (Esc 取消)"` state, applies `KeybindManager.rebind_action()`, shows a brief notification if a key swap occurred, and dynamically updates all hotkey badges across the HUD.

---

## 2. MOUSE-ONLY RTS CAMERA CONTROLLER (`scripts/core/camera_rig.gd`)

Remove all `WASD` and Arrow key movement from `camera_rig.gd`. Implement 3 responsive mouse camera controls:

1. **Mouse Wheel Smooth Zoom (Cursor-Centered)**:
   - `MOUSE_BUTTON_WHEEL_UP`: `target_zoom = clampf(target_zoom * 1.12, 0.45, 2.2)`.
   - `MOUSE_BUTTON_WHEEL_DOWN`: `target_zoom = clampf(target_zoom * 0.89, 0.45, 2.2)`.
   - Smoothly interpolate `zoom = zoom.lerp(Vector2.ONE * target_zoom, 12.0 * delta)`.
2. **Middle-Mouse Button (MMB) Hold & Drag Pan (`按住滚轮拖动`)**:
   - When `MOUSE_BUTTON_MIDDLE` is held (`_is_mmb_dragging = true`), on `InputEventMouseMotion`, pan camera by `global_position -= event.relative / zoom`, clamped within `Rect2(0, 0, 2400, 1350)`.
3. **Screen-Edge Hover Panning (`鼠标贴屏幕四边移动`)**:
   - In `_process(delta)`, when not MMB-dragging and no settings modal is open:
     - Check viewport mouse position `m_pos = get_viewport().get_mouse_position()` against viewport size `v_size = get_viewport_rect().size` with `EDGE_MARGIN = 24.0` px and `PAN_SPEED = 920.0`:
     - Pan Left (`m_pos.x <= 24`), Right (`m_pos.x >= v_size.x - 24`), Up (`m_pos.y <= 24`), Down (`m_pos.y >= v_size.y - 24`).

---

## 3. RTS BOX-SELECTION, 3-STATE AUTHORITY HANDSHAKE & TACTICAL PATH DRAWING

### 3.1 Box-Selection Controller (`scripts/core/selection_manager.gd` or inside `main_arena.gd`)
- **Left-Click & Drag**: Draws a translucent cyan selection box (`Color(0.15, 0.85, 1.0, 0.18)` fill, `2.0px` cyan border). On release, selects all living Blue (`team == 0`) units inside the rectangle (`selected_units: Array[BaseGeoUnit]`).
- **Single Left-Click on Blue Unit**: Selects that single unit.
- **Double Left-Click on Blue Unit**: Selects all on-screen Blue units of the same `unit_type`.
- **Left-Click Empty Ground (no drag) or `Esc`**: Clears `selected_units` (unless currently in HUD Skill Reticle Targeting Mode).

### 3.2 Three-State Control Handshake (`base_geo_unit.gd`)
Prevent the AI from fighting the player's manual micro by adding:
```gdscript
enum ControlAuthority {
	AUTO_AGENT,       # Controlled by Global Team Profile (and AI Co-Pilot updates)
	MANUAL_OVERRIDE,  # Executing player Right-Click move/focus-fire or Hold-Orbit
	SQUAD_AI_SCOPED   # Autonomous AI driven by a squad-specific prompt or Shift-drawn path!
}
var authority_state: ControlAuthority = ControlAuthority.AUTO_AGENT
var is_selected: bool = false
var manual_move_target: Vector2 = Vector2.ZERO
var manual_attack_target: Node2D = null
var manual_hold_timer: float = 0.0
var custom_squad_rule: Dictionary = {}
var tactical_waypoints: Array[Vector2] = []
```
- **Visual Selection & Authority Cues (`_draw()` in `BaseGeoUnit`)**:
  - When `is_selected == true`: Draw a rotating bright white/cyan corner-bracket selection frame around the unit + small cooldown readiness pip dots.
  - When `authority_state == MANUAL_OVERRIDE`: Draw a crisp green vector line to `manual_move_target` or `manual_attack_target`.
  - When `authority_state == SQUAD_AI_SCOPED`: Draw a subtle violet squad-link ring beneath the unit so the player knows it has a custom squad order.
- **Right-Click Manual Move & Focus-Fire**:
  - When `selected_units.size() > 0` and player **Right-Clicks** (without holding `Shift`):
    - **Clicked on an Enemy Unit/Base**: Set `authority_state = MANUAL_OVERRIDE`, `manual_attack_target = enemy`, `manual_hold_timer = 6.0`. Spawn a red target-lock ring on the enemy.
    - **Clicked on Ground**: Compute clean formation offsets around the click point so units don't overlap, set `authority_state = MANUAL_OVERRIDE`, `manual_move_target = formation_pos`, `manual_hold_timer = 4.0`. Spawn a cyan ground ripple.
- **Hold & Orbit (`A` Key — `squad_hold_orbit`) & Return to AI (`G` Key — `squad_return_ai`)**:
  - Pressing `squad_hold_orbit` (`A`) orders `selected_units` to anchor at their current area while continuously orbiting/strafing (`never_stationary = true`).
  - Pressing `squad_return_ai` (`G`) — or when `manual_move_target` is reached and `manual_hold_timer` expires — smoothly transitions the unit back to `SQUAD_AI_SCOPED` (if `custom_squad_rule` is non-empty) or `AUTO_AGENT`!

### 3.3 `Shift + Right-Drag` Tactical Gesture Path Drawing (零打字画线授意)
- Holding **`Shift` + Right-Mouse Drag** on the battlefield draws a glowing cyan-gold tactical path polyline (`Array[Vector2]`, sampled every `65px`).
- On mouse release: assigns the waypoint chain to `selected_units` (`tactical_waypoints = drawn_points.duplicate()`, `authority_state = SQUAD_AI_SCOPED`). Units advance along the drawn curve waypoints in sequence while maintaining their combat footwork and skill evasion!

---

## 4. MIXED-SQUAD PER-CLASS SKILL ROUTING (`Q/W/E/R/F`) & CLICKABLE HUD SKILL SLOTS

When the player box-selects a mixed squad (e.g., `3x ▲Triangle + 2x ■Square + 2x ◆Diamond`), avoid firing all skills on a single key. Route skills by unit class:

### 4.1 Per-Class Squad Skill Bar on HUD (`commander_hud.gd`)
Above the bottom AI Command Terminal, render **5 Clickable Squad Skill Slot Cards** (`▲`, `■`, `●`, `◆`, `⬢`):
- Each slot displays:
  - Dynamic hotkey badge read from `KeybindManager` (default `[Q]`, `[W]`, `[E]`, `[R]`, `[F]`).
  - Skill name (`锐角穿刺`, `动态棱镜`, `轨道坍缩`, `聚焦激光`, `全域共鸣`).
  - Ready count vs selected count for that class (e.g., `2 / 3 就绪`) and cooldown progress bar.
  - Slots for unit classes not currently in `selected_units` are dimmed (`modulate.a = 0.35`).

### 4.2 Dual Casting Modes (Keyboard Quick-Cast vs Mouse Slot Click)
1. **Mode A — Keyboard Per-Class Quick-Cast (`Q / W / E / R / F`)**:
   - Pressing `skill_triangle` (`Q`): Filters `selected_units` for `unit_type == "triangle"` ONLY; every selected Triangle with skill ready immediately casts `Apex Dash` aimed at `get_global_mouse_position()`.
   - Pressing `skill_square` (`W`): Filters `selected_units` for `unit_type == "square"` ONLY; every selected Square deploys `PrismBarrier` oriented perpendicular to `get_global_mouse_position()` (enabling manual mirror angling!).
   - Pressing `skill_circle` (`E`): Filters `selected_units` for `unit_type == "circle"` ONLY; launches `GravityWell` toward `get_global_mouse_position()`.
   - Pressing `skill_diamond` (`R`): Filters `selected_units` for `unit_type == "diamond"` ONLY; starts charging `Refracting Beam` aimed directly at `get_global_mouse_position()` (allowing manual bank-shots off `PrismBarrier`, `RefractingCrystal`, or `TriSplitterPrism`!).
   - Pressing `skill_hexagon` (`F`): Filters `selected_units` for `unit_type == "hexagon"` ONLY; triggers an immediate `Command Resonance` heal/buff pulse.
2. **Mode B — Mouse Click on HUD Squad Skill Slot (Reticle Target Cast)**:
   - Clicking an active Squad Skill Slot on the HUD sets `pending_squad_skill_class = class_id` and draws a holographic aiming reticle & trajectory preview at the mouse cursor.
   - **Left-Click on Battlefield**: Fires that class's skill for all selected units of that class toward the clicked world position, then exits targeting mode.
   - **Right-Click or `Esc`**: Cancels targeting mode without losing unit selection.

---

## 5. SQUAD-SCOPED AI TERMINAL PROMPTING (`commander_hud.gd` & `tactical_brain.gd`)

- **Dynamic Scope Indicator**:
  - When `selected_units.is_empty()`: Terminal badge shows `[ 全局指令模式：作用于全军 AUTO_AGENT 单位 ]`.
  - When `selected_units.size() > 0`: Terminal badge highlights in violet/cyan: `[ 局部小队指令模式：仅作用于已框选的 %d 个单位 | 按 Esc 切回全军 ]`.
- **Execution**:
  - Submitting a natural language prompt (or clicking a quick-preset chip) while `selected_units.size() > 0` compiles the prompt into a 3-Track rule dictionary and assigns it **only** to `unit.custom_squad_rule` (`unit.authority_state = ControlAuthority.SQUAD_AI_SCOPED`) on those selected units!
  - Squad-scoped prompts use a short `3.0s` local cooldown instead of triggering the 30-second global override cooldown.

---

## 6. LIVE AI TACTICAL CO-PILOT (`I / O / P` RANKED PROPOSALS, AUTO-DELEGATE & PERSONA PROMPT)

Create `scripts/core/ai_copilot_analyst.gd` (`class_name AICopilotAnalyst extends Node`) managed by `main_arena.gd`.

### 6.1 Custom AI Co-Pilot Persona / Directive Prompt (`参谋提示词设置`)
1. In `TacticalBrain`, maintain:
   ```gdscript
   var copilot_system_directive: String = "均衡分析战场局势，根据敌我兵种克制、中立能源点与晶簇刷新情况，提供三套按推荐度从高到低排列的战术变阵方案。"
   ```
2. **UI Editor & Presets**:
   - In both the Pre-Battle Configurator (`Tab` Drawer) and via a `[ ⚙ 参谋提示词设置 ]` button on the Co-Pilot HUD panel, allow the player to edit `copilot_system_directive` in a `TextEdit` and provide 3 one-click preset personas:
     - **`[激进奇袭参谋]`**: `"优先推荐利用加速轨、虫洞与三角形绕后刺杀敌方六边形和抢夺晶簇的高机动进攻方案。"`
     - **`[折光阵地参谋]`**: `"优先推荐正方形展开棱镜配合菱形折射激光、利用隐匿星云防守反击与规避狙击的方案。"`
     - **`[经济运营参谋]`**: `"优先推荐抢占南北能源点、躲避反应堆过载并循环采集算力晶簇的资源压制方案。"`
   - `AICopilotAnalyst` uses `copilot_system_directive` both in its LLM System Prompt (when LLM mode is active) and to weight its local heuristic scoring so Proposal #1 (`I`) reflects the player's chosen strategic doctrine.

### 6.2 Battlefield Telemetry & 3 Ranked Proposals (`I > O > P`)
Every `8.0` seconds (or immediately upon major events: Reactor Overload Warning, Energy Node lost, Base under attack, Enemy class surge), `AICopilotAnalyst` builds a battlefield telemetry snapshot and generates **up to 3 distinct tactical proposals sorted strictly by `recommend_score` descending**:

```gdscript
# Structure of each proposal in current_proposals: Array[Dictionary]
{
	"slot": 0,                      # 0 -> Key 'I' (Highest), 1 -> Key 'O' (Second), 2 -> Key 'P' (Third)
	"recommend_score": 93,          # Percentage 1~99%
	"title": "规避激光 + 侧翼抢矿刺杀",
	"reason": "侦测到敌方3个菱形中路集结且晶簇已刷新，建议规避正面折射并从侧翼收割资源切后排。",
	"profile_patch": { ... }        # 3-Track Tactical Profile applied to all AUTO_AGENT units when chosen
}
```

### 6.3 Co-Pilot HUD Panel (`I / O / P` Keys, Mouse Click & Auto-Delegate Mode)
Render a sleek holographic **AI Co-Pilot Command Panel** on the top-left of the HUD:
1. **Top Diagnosis & Control Row**:
   - Live situation diagnosis text (`"[AI参谋研判] ..."`).
   - **`[ 自动代理 (Auto-Delegate): ON / OFF ]` Toggle Button** (Hotkey from `KeybindManager`: default `[U]`):
     - **When `OFF` (Manual Selection)**: The 3 ranked proposal cards remain displayed. The player can press **`I`**, **`O`**, or **`P`** on the keyboard OR **Left-Click any of the 3 cards** with the mouse to immediately apply that proposal to all `AUTO_AGENT` units.
     - **When `ON` (Auto-Delegate Mode)**: Whenever a new set of 3 proposals is generated, Card #1 (`[I] 最高推荐 ★`) displays a `1.2s` golden auto-confirm progress bar and **automatically executes Proposal #1 (`slot = 0`)**! (The player can still press `O` or `P` or click another card at any time to override).
   - **`[ ⚙ 参谋提示词 ]` Button**: Opens the Co-Pilot Persona Prompt editor modal.
2. **Three Ranked Proposal Cards (Ordered Top-to-Bottom or Left-to-Right)**:
   - **Card 1 (`[I] 推荐度 93% ★ 最优方案`)**: Gold-cyan glowing border, title + summary, clickable.
   - **Card 2 (`[O] 推荐度 78% · 次选方案`)**: Cyan border, title + summary, clickable.
   - **Card 3 (`[P] 推荐度 64% · 奇袭备选`)**: Violet border, title + summary, clickable.
   - All key badges (`[I]`, `[O]`, `[P]`, `[U]`) dynamically reflect `KeybindManager.get_key_label()`.

---

## 7. END-TO-END VERIFICATION CHECKLIST FOR THE AGENT

1. **Mouse-Only Camera**: Verify `WASD` no longer moves the camera; verify Wheel Zoom, MMB Drag Pan, and 4-Edge Screen Hover Panning work smoothly.
2. **Box-Selection & Per-Class `Q/W/E/R/F` Skills**: Box-select a mixed squad (`▲ + ■ + ◆`). Verify pressing `Q` only dashes selected Triangles toward the cursor, `W` only deploys Square barriers toward the cursor, and `R` only fires Diamond lasers toward the cursor. Verify clicking any of the 5 HUD Squad Skill Slots enters reticle targeting mode and casts on Left-Click.
3. **3-State Handshake & Squad Prompting**: Verify Right-Clicking ground/enemies enters `MANUAL_OVERRIDE`, pressing `G` returns units to AI control, `Shift + Right-Drag` draws a waypoint path for the selected squad, and submitting a terminal prompt while units are selected updates ONLY those selected units (`SQUAD_AI_SCOPED`).
4. **AI Co-Pilot (`I / O / P` + Auto-Delegate + Custom Prompt)**: Verify the Co-Pilot generates 3 proposals ranked by recommendation percentage every 8 seconds, pressing `I`, `O`, or `P` (or clicking the cards) applies the chosen strategy, toggling **Auto-Delegate (`U`)** automatically selects Option 1 (`I`), and modifying the **Co-Pilot Prompt** shifts proposal rankings.
5. **Custom Keybindings & Focus Guard**: Verify rebinding keys in the Keybind Settings Modal swaps conflicting keys cleanly, persists to `user://keybinds.json`, updates HUD badges live, and typing inside any `LineEdit` / `TextEdit` never triggers hotkeys.