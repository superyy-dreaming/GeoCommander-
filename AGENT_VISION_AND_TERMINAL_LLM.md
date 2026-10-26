# Upgrade Specification: Fog of War Vision System, Live Battlefield Telemetry Terminal & Direct LLM Tactical Control
> **Target Project**: GeoCommander (Godot 4.3+ Procedural Geometry RTS)  
> **Core Problems to Solve**:  
> 1. **No Fog of War**: Currently, all enemy units are visible across the entire map from second 0. Enemy units must ONLY be visible when inside the vision radius of friendly units/structures, with a 5-second "Last Seen Radar Ghost" when they leave vision.  
> 2. **AI Co-Pilot Stuck on Local Heuristics**: Currently, the AI Co-Pilot fails to use real LLM analysis in live battles or lacks a structured battlefield representation.  
> 3. **Low AI Freedom**: We need a **Live Battlefield Telemetry Terminal (`战场态势终端`)** that formats the exact known battlefield environment, friendly unit states, and spotted/ghost enemy states into a structured live text feed, displays it to the player, and sends that **exact terminal text directly to the LLM (`LLMService`)** so the LLM can issue high-freedom, coordinate-aware and unit-specific tactical commands.

---

## 1. FOG OF WAR & DIFFERENTIATED VISION SYSTEM (`CombatContext` & `BaseGeoUnit`)

### 1.1 Vision Radius Per Unit & Structure (`vision_radius`)
Assign distinct `vision_radius` values so scouting and vision-sharing become core tactical mechanics (especially for ◆ Diamond, whose `750px` laser outranges its own `300px` vision!):
- **`CoreMatrixBase` (基地)**: `520.0 px`
- **Captured `EnergyPrism` (已占领能源点)**: `260.0 px` (Provides vision to the owning team)
- **`▲ Triangle` (侦察/刺客)**: `420.0 px` (Fast frontline scout)
- **`■ Square` (重装护卫)**: `280.0 px`
- **`● Circle` (引力控制)**: `350.0 px`
- **`◆ Diamond` (超距折射狙击)**: `300.0 px` (Must rely on allied vision to snipe targets at `400~750px`!)
- **`⬢ Hexagon` (算力雷达核心)**: `500.0 px` (Plus its active resonance/scan pulse reveals enemy units inside `StealthNebula` within `340.0 px` for `4.0s`).

### 1.2 Three-State Enemy Visibility & 5-Second Radar Ghosts
For each team (`TEAM_BLUE = 0`, `TEAM_RED = 1`), maintain visibility states in `CombatContext` (updated every `0.1s`):

1. **`VISIBLE` (实时可视)**:
   - An enemy unit is `VISIBLE` to Team `T` if its distance to at least one living friendly unit/base/owned-node of Team `T` is `<= source.vision_radius` AND (the enemy is NOT inside a `StealthNebula`, OR a friendly unit is inside the same nebula / within `145px` / scanned by Hexagon or EMP).
   - **Visuals (For Player Team 0)**: Enemy unit `visible = true`, rendered normally.
   - **Memory Update**: Update `last_seen_ghosts[enemy.unit_id]` with `{ "unit_id": enemy.unit_id, "unit_type": enemy.unit_type, "pos": enemy.global_position, "vel": enemy.velocity, "hp_ratio": enemy.hp_ratio, "timestamp": current_match_time }`.

2. **`LAST_SEEN_GHOST` (最后目击雷达残影 — Lasts `5.0` Seconds)**:
   - When a previously `VISIBLE` enemy moves out of Team `T`'s vision (or enters stealth), hide the real enemy node (`visible = false` for Team 0), but retain its entry in `last_seen_ghosts` for **`5.0` seconds**!
   - **Visuals (For Player Team 0)**: Render a fading crimson wireframe silhouette + `[?]` radar blip at the ghost's last known `pos` with an arrow showing its last velocity vector (`alpha` fading from `0.65` to `0.0` over `5.0s`).

3. **`HIDDEN_IN_FOG` (迷雾未知态)**:
   - Never seen, or unseen for `> 5.0` seconds.
   - Completely invisible (`visible = false`), removed from `last_seen_ghosts`, and strictly inaccessible to unit target evaluation, Battlefield Terminal, and AI Co-Pilot!

### 1.3 Vision Boundary Visualization & No-Contact Recon Behavior
- **Visual Fog Overlay on Battlefield**:
  - Terrain obstacles, energy nodes, crystals, and rails remain visible on the tactical map, but render a subtle dark-blue fog overlay (or draw crisp dashed cyan **Vision Perimeter Arcs** around friendly vision sources) so the player clearly sees which areas are inside live radar coverage vs in the Fog of War.
- **Mandatory Recon / Exploration Behavior When Zero Enemies Are Visible**:
  - In `BaseGeoUnit`, when no `VISIBLE` enemies exist in `CombatContext`:
    - Units must **NOT** stand still at spawn or cheat by walking straight to hidden enemies!
    - Instead, units automatically follow **Recon Sweep Behavior**: move toward uncaptured Energy Nodes, last-seen ghost positions (`last_seen_ghosts`), Drawn/Waypoint coordinates, or advance along the North/Center/South lanes toward the enemy `CoreMatrixBase` (whose fixed structural coordinates `(2160, 675)` / `(240, 675)` are known map landmarks) until enemy contact is made!

---

## 2. LIVE BATTLEFIELD TELEMETRY TERMINAL (`scripts/ui/battlefield_terminal.gd`)

Build an interactive, collapsible **Battlefield Situation Terminal (`[ 📡 战场态势终端 ]`)** on the HUD (toggleable via button or hotkey, docked cleanly so it doesn't block center combat).

### 2.1 Real-Time Telemetry Text Generator (`build_terminal_report(team: int) -> String`)
Every `1.0s` (and immediately before any LLM Co-Pilot query), generate a structured, human-and-LLM-readable tactical report containing **ONLY information known to `team` under Fog of War rules**:

```text
=== [GEO-COMMANDER TACTICAL TERMINAL // TIME: 01:45] ===
[MAP & MECHANICS] Map: 折光阵列 | Center Splitter: (1200,675) | Reactor: Normal (Overload in 35s)
[ECONOMY & NODES] Flux: 215 (+18/s) | North Node(1200,260): BLUE | South Node(1200,1090): NEUTRAL | Visible Flux Crystals: [(1140, 580)]
[BLUE BASE] Pos:(240,675) HP:2500/2500 | [RED BASE] Pos:(2160,675) HP:2320/2500

[FRIENDLY FORCES (ALL KNOWN - 6 UNITS)]
- ID:B1 [⬢hexagon]  Pos:(410,675)  HP:100% SkillCD:0.0s Auth:AUTO  State:guard_rear
- ID:B2 [■square]   Pos:(920,660)  HP:72%  SkillCD:1.8s Auth:AUTO  State:shield_active
- ID:B3 [◆diamond]  Pos:(750,670)  HP:100% SkillCD:0.0s Auth:AUTO  State:aiming_splitter
- ID:B4 [▲triangle] Pos:(1050,240) HP:90%  SkillCD:0.0s Auth:SQUAD State:recon_north

[KNOWN ENEMY INTEL (VISION + 5s RADAR GHOSTS ONLY)]
- [VISIBLE] ID:R2 [■square]  Pos:(1180,665) HP:80% Threat:barrier_deployed
- [VISIBLE] ID:R5 [◆diamond] Pos:(1390,675) HP:100% Threat:CHARGING_LASER_WEST!
- [GHOST 2.8s ago] ID:R1 [▲triangle] LastPos:(1320,1020) LastDir:(-0.8, 0.2) (Heading South-West!)
- [FOG NOTE] Enemy units outside friendly vision radii are unknown.
```

### 2.2 Terminal UI Features
- Displays the live scrolling/updating telemetry text in a clean monospace-styled `RichTextLabel` / `TextEdit` (read-only view).
- **LLM Connection Status Header**:
  Shows live LLM pipeline state:
  - `LLM 状态: 已就绪 (Model: deepseek-ai/DeepSeek-V4.1-Flash)`
  - `请求耗时: 740ms | 上次分析: 01:42` (or explicit error reason if API key is missing/network failed—never fail silently!).
- **Action Bar inside Terminal**:
  - **`[ ⚡ 立即发送终端态势至 LLM 研判 ]`**: Immediately triggers an asynchronous LLM Co-Pilot request using the current terminal report!
  - **`[ 复制态势文本 ]`**: Copies the terminal report to clipboard.
  - **`[ 查看 LLM 原始响应 ]`**: Toggles view between the Battlefield Telemetry Input and the raw JSON + reasoning returned by the LLM.

---

## 3. DIRECT TERMINAL-TO-LLM PIPELINE & HIGH-FREEDOM AI CONTROL (`ai_copilot_analyst.gd` & `llm_service.gd`)

### 3.1 Fix Why AI Co-Pilot Was Only Using Local Analysis
Audit and fix the connection between `AICopilotAnalyst` and `LLMService`:
1. **Direct Wiring**: Whenever `LLMService` has a configured provider/endpoint (e.g., SiliconFlow / OpenAI-compatible / local Ollama), `AICopilotAnalyst.request_analysis()` **MUST** call `LLMService` asynchronously with the exact text produced by `build_terminal_report(0)` plus `TacticalBrain.copilot_system_directive`!
2. **Lenient JSON Extraction (Prevent False Fallback to Local)**:
   - Models like `DeepSeek-V4.1-Flash` often wrap JSON in ` ```json ... ``` ` markdown blocks or include a brief `<think>` / preamble.
   - Before calling `JSON.parse_string()`, strip markdown code fences and extract the substring from the first `{` to the last `}`!
   - If a minor field is missing in one proposal, fill sensible defaults for that field instead of discarding the entire LLM response and falling back to local heuristics!

### 3.2 High-Freedom Tactical Directive Schema (Coordinate & Unit-Specific Control!)
To give the LLM genuine tactical freedom beyond generic stances, allow each proposal's `profile_patch` returned by the LLM to include **both** class-level rules (`unit_rules`) AND **`tactical_directives` (coordinate waypoints, scout-spotter pairing, and specific unit/class target assignments)**:

```json
{
  "diagnosis": "中路敌方#R5菱形正在蓄力激光，南路2.8秒前发现敌方#R1三角形残影疑似偷袭！同时(1140,580)有算力晶簇。",
  "proposals": [
    {
      "slot": 0,
      "recommend_score": 95,
      "title": "闪避中路激光 + 抢晶簇 + 拦截南路刺客",
      "reason": "令中路部队横向规避#R5激光，派北路#B4三角形顺路拾取(1140,580)晶簇，调回南路兵力去(900,1020)拦截敌方残影#R1。",
      "profile_patch": {
        "stance": "adaptive_counter",
        "unit_rules": {
          "triangle": {
            "movement": "flank_sides",
            "priority": "ranged_or_commander",
            "terrain_policy": "collect_crystals",
            "reflexes": {"evade_laser_and_refraction": true},
            "locomotion": {"never_stationary": true, "approach_trajectory": "zigzag"}
          },
          "diamond": {
            "movement": "align_with_square",
            "priority": "highest_threat",
            "terrain_policy": "center_prism",
            "reflexes": {"evade_laser_and_refraction": true}
          }
        },
        "tactical_directives": [
          {
            "target_selector": "ID:B4",
            "action": "move_and_collect",
            "target_pos": [1140, 580],
            "then_action": "flank_pursue"
          },
          {
            "target_selector": "class:square",
            "action": "hold_and_shield_direction",
            "target_pos": [950, 665],
            "face_pos": [1390, 675]
          },
          {
            "target_selector": "class:circle",
            "action": "intercept_area",
            "target_pos": [920, 980]
          }
        ]
      }
    }
  ]
}
```

### 3.3 Executing `tactical_directives` on `AUTO_AGENT` Units (`base_geo_unit.gd`)
When a proposal is adopted (via `I / O / P`, mouse click, or `U` Auto-Delegate):
1. Apply `unit_rules` to all `AUTO_AGENT` units of each class.
2. Iterate through `tactical_directives`:
   - Match units that are currently in `ControlAuthority.AUTO_AGENT` by `target_selector` (supports specific unit ID like `"ID:B4"`, or class like `"class:triangle"`, or `"nearest_to_target"`).
   - Inject the directive's `target_pos` into the unit's AI navigation target (`ai_directive_pos`, `ai_directive_action`, `ai_face_pos`) while keeping the unit in `AUTO_AGENT` authority (so it never locks out player manual box-selection!).
   - Supported `action` types in `BaseGeoUnit`:
     - `"move_and_collect"`: Steers to `target_pos` to pick up crystals/capture node, then resumes `then_action`.
     - `"recon_area"` / `"intercept_area"`: Sweeps to `target_pos` to reveal Fog of War or intercept a Last-Seen Ghost!
     - `"hold_and_shield_direction"`: Moves to `target_pos` and orients `PrismBarrier` toward `face_pos`!
     - `"snipe_via_prism"`: Moves within range of `target_pos` (prism/crystal) and fires `Refracting Beam` into it once allied vision spots enemies on the far side!

---

## 4. VERIFICATION CHECKLIST FOR THE AGENT

1. **Fog of War & Vision**:
   - At match start (`00:00`), verify enemy units at the far base are **invisible (`visible = false`)** and do NOT appear in the Battlefield Terminal.
   - Verify units advance and scout along lanes/nodes when no enemies are visible.
   - Verify that when an enemy enters a friendly unit's `vision_radius`, it becomes visible and appears under `[KNOWN ENEMY INTEL]` in the terminal.
   - Verify that when an enemy leaves vision, its real body hides and a **5-second Last-Seen Ghost (`[?]`)** remains on screen and in the terminal.
2. **Battlefield Telemetry Terminal**:
   - Open `[ 📡 战场态势终端 ]` on the HUD. Verify it displays live coordinates, HP, skill cooldowns, friendly unit IDs (`#B1`, `#B2`...), visible enemies, and 5s ghosts accurately.
3. **Real LLM Co-Pilot Execution & High-Freedom Directives**:
   - Click `[ ⚡ 立即发送终端态势至 LLM 研判 ]` (and test the 8s auto-cycle) with the configured LLM (`deepseek-ai/DeepSeek-V4.1-Flash`).
   - Verify the terminal sends its live text report to `LLMService`, strips any markdown wrappers from the response, displays `"来源: LLM 实时推演"`, and populates the `I / O / P` cards with coordinate-specific strategies referencing actual unit IDs and ghost coordinates from the terminal!
   - Press `I` (or enable Auto-Delegate `U`) and verify `AUTO_AGENT` units execute both the `unit_rules` and the coordinate-level `tactical_directives`.