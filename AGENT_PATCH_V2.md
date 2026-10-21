# Incremental Patch Specification: Interactive Main Menu & Tactical Arena Obstacles (V2)
> **Target Project**: GeoCommander (Godot 4.3+ Procedural Geometry RTS)  
> **Patch Objective**:  
> 1. Build an interactive **Start Screen / Unit Codex (`main_menu.tscn`)** featuring individual geometric unit lore, stat bars, and a **Live Physics Showcase Stage** that continuously demonstrates each unit's normal attack and signature skill VFX against target dummies.  
> 2. Upgrade the battlefield (`main_arena.gd`) from an empty plane into a **Tactical Geometric Arena** with 3 interactive obstacle types (Obsidian Monoliths, Neutral Refracting Crystals, and Phase Slow Zones) and upgrade Unit Steering AI with **Whisker Raycast Obstacle Avoidance**.  
> **Asset Policy**: Maintain **100% Procedural Geometry & Shaders** (Zero external `.png`/`.svg` files).

---

## 1. UPDATED SCENE FLOW & ARCHITECTURE

### 1.1 Updated Entry Point (`project.godot`)
- Change `run/main_scene` in `project.godot` to `"res://scenes/main_menu.tscn"`.
- Clicking `[ 启动战术推演 / LAUNCH BATTLE ]` in `main_menu.tscn` transitions smoothly to `"res://scenes/main_arena.tscn"`.
- Add a `[ 返回主菜单 / EXIT TO MENU ]` button in `commander_hud.gd` (top-right corner or `Esc` pause overlay) to return to `"res://scenes/main_menu.tscn"`.

### 1.2 New & Modified Files
```text
res://
├── scenes/
│   ├── main_menu.tscn                # [NEW] Root Node2D/Control attaching main_menu.gd
│   └── main_arena.tscn               # [EXISTING] Battlefield scene
├── scripts/
│   ├── ui/
│   │   ├── main_menu.gd              # [NEW] Start Screen UI + Unit Codex + Live Combat Showcase
│   │   └── unit_showcase_stage.gd    # [NEW] Self-contained live 2D sandbox demonstrating unit skills
│   ├── core/
│   │   ├── arena_obstacles.gd        # [NEW] Procedural obstacle builder (Walls, Refractors, Slow Zones)
│   │   └── main_arena.gd             # [MODIFIED] Spawns symmetric tactical obstacles & navigation flow
│   └── units/
│       └── base_geo_unit.gd          # [MODIFIED] Adds 3-ray whisker obstacle avoidance & slow-zone multiplier
```

---

## 2. FEATURE 1: START SCREEN & LIVE UNIT SHOWCASE (`main_menu.gd` & `unit_showcase_stage.gd`)

### 2.1 Visual Layout (`1920x1080` Holographic Command Deck)
Construct the Main Menu programmatically in `main_menu.gd` with the same `WorldEnvironment` (HDR Additive Glow enabled) and `tactical_grid.gdshader` background so particle effects bloom identically to the main battle.

Divide the screen into **3 Holographic Panels**:

1. **Top Header Bar**:
   - Game Title: `GEO COMMANDER // 几何最高指挥官` (Large neon cyan/gold typography with subtle procedural geometric emblem).
   - Subtitle: `AUTONOMOUS AI TACTICAL WARFARE SYSTEM v2.0`
   - Right Action Button: Large glowing button `[ 启动战役推演 // LAUNCH BATTLE ]` (Loads `res://scenes/main_arena.tscn`).

2. **Left Column: 5 Geometric Unit Roster Cards (`Width: 380px`)**:
   - Vertically stacked interactive selection cards for the 5 classes:
     1. `▲ 正三角形 [STRIKER]` — *突击刺客 / 背刺暴击*
     2. `■ 正方形 [BULWARK]` — *重装矩阵 / 棱镜折光*
     3. `● 圆形 [SINGULARITY]` — *引力奇点 / 聚怪坍缩*
     4. `◆ 菱形 [PRISM SNIPER]` — *超距狙击 / 折跃激光*
     5. `⬢ 正六边形 [COMMANDER]` — *算力中枢 / 全域超频*
   - Each card draws a live rotating procedural geometric icon (`_draw()`) in its HDR signature color. Clicking a card selects that unit, updates the Center Info Panel, and immediately spawns that unit's live combat scenario in the Right Showcase Stage.

3. **Bottom-Center Panel: Unit Tactical Dossier & Stat Bars (`Width: 620px`)**:
   - Displays for the currently selected unit:
     - **Unit Name, Role Badge & Cost** (e.g., `COST: 60 FLUX | COOLDOWN: 5.5s`).
     - **4 Animated Progress/Stat Bars**:
       - `结构强度 (HP)`
       - `机动速度 (MOBILITY)`
       - `攻击射程 (RANGE)`
       - `战术操作难度 (AI SYNERGY)`
     - **Detailed Lore & Mechanics Box**:
       - **普攻机制 (Normal Attack)**: Clear Chinese description of attack range, damage, and projectile behavior.
       - **核心技能 (Signature Skill)**: Detailed breakdown of skill mechanics and particle visual cues.
       - **AI 提示词推荐写法 (Recommended Prompt)**: Example prompt string (e.g., `"菱形瞄准己方正方形护盾进行折射狙击，敌方靠近时后撤风筝"`), with a button `[ 应用为默认开局指令 ]` that saves directly to `TacticalBrain`.

4. **Right Main Panel: Live Interactive Combat Showcase Stage (`unit_showcase_stage.gd`, `820x680 px`)**:
   - A dedicated framed 2D holographic arena box on the right side of the screen (`Node2D` clipped or bounded inside a glowing tactical border) with interactive control buttons at its bottom:
     - `[ 自动循环演示: ON/OFF ]` (Default: `ON`, triggers attack every `1.5s` and signature skill every `3.5s`).
     - `[ 立即演示普攻 (FIRE ATTACK) ]`
     - `[ 立即演示技能 (CAST SKILL) ]`
     - `[ 重置靶场假人 (RESET DUMMIES) ]`

### 2.2 Choreographed Live Showcase Scenarios (Must Execute Real Game VFX!)
When the user selects each unit in the Main Menu, `unit_showcase_stage.gd` clears the stage and spawns the selected Blue unit on the left of the showcase box and Red target dummy geometries on the right (with infinite/auto-refilling HP and hit-flash/shatter feedback):

- **When `▲ Triangle` is selected**:
  - Spawns 1 Blue Triangle vs 2 Red Dummy Diamonds facing away.
  - **Normal Attack Demo**: Triangle dashes into melee range and slashes with yellow spark bursts.
  - **Skill Demo (`Apex Dash`)**: Triangle winds up (`0.25s`), leaves a bright yellow neon `Line2D` trail slicing *through* both dummies from behind, triggering **2x Backstab Critical (`110 DMG`)** floating text and explosive yellow triangle shatter particles!
- **When `■ Square` is selected**:
  - Spawns 1 Blue Square protecting 1 Blue Hexagon, facing 1 Red Dummy Circle and 1 Red Dummy Diamond.
  - **Normal Attack Demo**: Heavy melee kinetic slam with cyan shockwave ring.
  - **Skill Demo (`Prism Barrier`)**: Square deploys its glowing cyan hexagonal forcefield barrier (`PrismBarrier`). The Red Dummy fires projectiles that get blocked and shattered against the shield, AND an allied laser hits the shield and **reflects at an angle** into the Red Dummy!
- **When `● Circle` is selected**:
  - Spawns 1 Blue Circle vs 4 scattered Red Dummy Triangles.
  - **Normal Attack Demo**: Fires magenta energy pulse orbs at mid-range.
  - **Skill Demo (`Orbital Collapse`)**: Fires a singularity core into the center of the 4 dummies. For `0.9s`, inward-spiraling magenta rings physically drag all 4 dummies tightly together into a single point, followed by an outward shockwave explosion knocking them back!
- **When `◆ Diamond` is selected**:
  - Spawns 1 Blue Diamond + 1 angled Blue `PrismBarrier` + 3 Red Dummies arranged around a corner obstacle.
  - **Normal Attack Demo**: Fires high-velocity white light darts while kiting backward.
  - **Skill Demo (`Refracting Beam`)**: Shows the `0.5s` crimson targeting laser sight line, then fires a blinding white HDR beam (`width = 9.0`) that hits the angled `PrismBarrier`, **bounces 90 degrees around the obstacle**, amplifies to `1.35x` width/damage, and pierces all 3 Red Dummies simultaneously!
- **When `⬢ Hexagon` is selected**:
  - Spawns 1 Blue Hexagon surrounded by 3 damaged Blue allies (half inner-fill scale).
  - **Skill Demo (`Command Resonance`)**: Emits an expanding golden hexagonal pulse wave, connects to all 3 allies with glowing golden fiber `Line2D` tethers, visibly restoring their inner polygon HP fill and displaying a live `COMMAND TERMINAL COOLDOWN: -40%` HUD indicator!

---

## 3. FEATURE 2: TACTICAL ARENA OBSTACLES (`arena_obstacles.gd`)

Stop the battlefield (`2400 x 1350`) from looking empty. Create `scripts/core/arena_obstacles.gd` (`class_name ArenaObstacles`) and call it from `main_arena.gd` during arena setup to build a **symmetrical, high-strategy geometric battlefield**.

### 3.1 Three Interactive Geometric Obstacle Types

1. **Type A: Obsidian Monolith Walls (黑曜石战术掩体 - `StaticBody2D` on Layer 5 `ARENA_BOUNDS`)**
   - **Visual**: Deep obsidian polygon fill (`Color(0.04, 0.06, 0.10, 0.95)`) with an inner architectural wireframe and a crisp neon indigo outer border (`Line2D`, `width = 3.0`, `Color(0.35, 0.55, 1.4, 1.0)`).
   - **Gameplay Function**: Physically blocks unit movement, dashes, and normal projectiles. Stops lasers without reflecting them. Creates 3 distinct tactical lanes (North, Center, South) and flanking corridors.
   - **Placement (Symmetric Pairs)**:
     - **Center Choke Pillars (x2)**: Angled chevron/trapezoid monoliths at `Vector2(1020, 520)` and `Vector2(1380, 830)` (`size ~ 140x45 px`, rotated `25°`).
     - **Base Forward Bunkers (x4)**: Protective L-shaped geometric walls shielding the approaches to Blue Base (`Vector2(560, 380)` and `Vector2(560, 970)`) and Red Base (`Vector2(1840, 380)` and `Vector2(1840, 970)`).

2. **Type B: Neutral Crystalline Refractors (中立折光晶簇 - `StaticBody2D` on BOTH Layer 3 `PRISM_BARRIER` & Layer 5 `ARENA_BOUNDS`)**
   - **Visual**: Rotating or fixed octagram/diamond crystal structures (`radius = 38px`) with a bright prismatic cyan-white HDR outline (`Color(1.8, 2.4, 2.8, 1.0)`) and internal refraction lines.
   - **Gameplay Function**:
     - Impassable physical terrain for units.
     - **Interactive Laser Bounce**: Because it is also on Layer 3 (`PRISM_BARRIER`), any **◆ Diamond laser** (Blue or Red) hitting a Neutral Crystalline Refractor **automatically bounces off its surface normal and gains `+25%` damage amplification**, allowing clever commanders to snipe enemies hiding behind monolith walls!
   - **Placement**:
     - Placed at strategic bank-shot angles near mid-lane and the Energy Prisms: `Vector2(1200, 140)`, `Vector2(1200, 1210)`, `Vector2(880, 675)`, `Vector2(1520, 675)`.

3. **Type C: Entropy Slow Fields (几何熵减虚线区 - `Area2D`)**
   - **Visual**: Large hexagonal floor hazard zones (`radius = 130px`) drawn with rotating dashed amber/orange warning lines (`Color(1.8, 0.9, 0.1, 0.45)`) and subtle rising slow particles.
   - **Gameplay Function**:
     - Does not block movement or projectiles, but any unit inside the `Area2D` has its `speed_multiplier` reduced by **`35%`** (`0.65x` speed) and displays an amber slow tint.
     - Creates tactical kill-zones where ● Circle's Gravity Well and ◆ Diamond's lasers are extra lethal.
   - **Placement**:
     - Positioned at `Vector2(920, 320)` and `Vector2(1480, 1030)` (flanking the North and South Energy Prisms).

---

## 4. AI OBSTACLE AVOIDANCE & TERRAIN AWARENESS (`base_geo_unit.gd` & `tactical_brain.gd`)

### 4.1 Three-Ray Whisker Steering Avoidance (`base_geo_unit.gd`)
To ensure 50 units smoothly navigate around the new Obsidian Monoliths and Crystalline Refractors without getting stuck on corners:
- In `BaseGeoUnit._physics_process(delta)`, before finalizing `velocity`, cast 3 short procedural feeler rays using `get_world_2d().direct_space_state.intersect_ray()`:
  - **Center Ray**: Along `desired_dir`, length `unit_radius + 65.0`, collision mask = `16` (Layer 5 `ARENA_BOUNDS`).
  - **Left Whisker**: Rotated `-38°` from `desired_dir`, length `unit_radius + 50.0`, mask = `16`.
  - **Right Whisker**: Rotated `+38°` from `desired_dir`, length `unit_radius + 50.0`, mask = `16`.
- **Avoidance Steering Math**:
  - If a ray hits an obstacle, compute an avoidance vector pushing along the hit surface normal plus a strong tangential slide vector (`hit.normal.orthogonal()`) away from the blocked whisker side:
    ```gdscript
    var avoid_dir: Vector2 = hit.normal + hit.normal.orthogonal() * steer_sign
    desired_dir = (desired_dir * 0.35 + avoid_dir.normalized() * 0.95).normalized()
    ```
  - This guarantees units glide organically around angled monolith walls and choke points.

### 4.2 Terrain-Aware Prompt Keywords (`tactical_brain.gd`)
Add terrain-aware keywords to `TacticalBrain.compile_prompt_to_profile()`:
- `"中路推进" / "走中路" / "mid lane"` -> Sets waypoint/lane bias toward `Y = 675` center corridor.
- `"分推" / "南北包抄" / "split push"` -> Splits units between North (`Y = 260`) and South (`Y = 1090`) lanes around the center monoliths.
- `"利用地形折射" / "晶簇折射" / "crystal bounce"` -> Sets `diamond.skill_cond = "refract_or_snipe"` and moves Diamonds within range of Neutral Crystalline Refractors (`Layer 3`).

---

## 5. VERIFICATION CHECKLIST FOR THE AGENT

1. Run `res://scenes/main_menu.tscn`: Verify all 5 unit cards can be clicked, stats/descriptions update cleanly in Chinese, and the right-hand **Live Showcase Stage** physically spawns the selected unit + target dummies and demonstrates both Normal Attack and Signature Skill particle VFX with HDR glow.
2. Click `[ 启动战役推演 // LAUNCH BATTLE ]` to transition to `main_arena.tscn`.
3. Verify the battlefield renders the **Obsidian Monoliths**, **Neutral Crystalline Refractors**, and **Entropy Slow Fields** symmetrically.
4. Verify units steer smoothly around monolith walls without getting stuck, slow down by 35% inside Entropy Fields, and Diamond lasers bounce off Neutral Crystalline Refractors.