# Master Specification: Holographic Map Visual Overhaul & Interactive Tactical Terrain System
> **Target Project**: GeoCommander (Godot 4.3+ Procedural Geometry RTS)  
> **Core Objectives**:  
> 1. **Visual & Architectural Overhaul**: Eliminate all ugly, overlapping L-shaped wall blocks and flat 1-layer primitives in both the **Map Selection Preview (`选择战场`)** and the **In-Game Battlefield (`main_arena`)**. Replace them with multi-layered sci-fi holographic architecture, topographic circuit underlays, automated anti-overlap validation, and styled icon-badge legends.  
> 2. **6 Interactive Tactical Terrain Mechanics**: Upgrade the 6 maps (`均衡前线`, `双翼迂回`, `折光阵列`, `盘旋堡垒`, `交叉火线`, `晶脉迷城`) so each map features unique interactive gameplay mechanics: **Central Tri-Splitter Prism**, **Vector Boost Rails**, **Quantum Stealth Nebulae**, **Paired Phase Wormholes**, **Dynamic Phase Gates**, and **Overload Reactor + Collectible Flux Crystals**.  
> 3. **AI Terrain Intelligence & Whisker Avoidance**: Equip `BaseGeoUnit` and `TacticalBrain` with 3-ray whisker obstacle avoidance and terrain-exploiting behavior driven by Chinese natural language prompts.  
> **Asset Policy**: 100% Procedural Geometry (`Polygon2D`, `Line2D`, `Area2D`, `StaticBody2D`, `_draw()`). Zero external image files.

---

## 1. VISUAL OVERHAUL: BAN "L-BLOCKS" & MULTI-LAYER HOLOGRAPHIC RENDERING

### 1.1 Replace Ugly L-Shaped Walls with 4 Convex Sci-Fi Wall Archetypes
**STRICT RULE**: Delete all L-shaped wall vertex arrays (`灰色：掩体`). Every obstacle wall must use one of these 4 sleek geometric monolith shapes (local coordinates centered at `(0,0)`):

1. **`CHAMFER_BASTION(w, h)` (倒角重装堡垒 - Octagonal Pillbox)**:
   `c = min(w, h) * 0.28`
   ```gdscript
   PackedVector2Array([
       Vector2(-w*0.5 + c, -h*0.5), Vector2(w*0.5 - c, -h*0.5),
       Vector2(w*0.5, -h*0.5 + c),  Vector2(w*0.5, h*0.5 - c),
       Vector2(w*0.5 - c, h*0.5),   Vector2(-w*0.5 + c, h*0.5),
       Vector2(-w*0.5, h*0.5 - c),  Vector2(-w*0.5, -h*0.5 + c)
   ])
   ```
2. **`CHEVRON_WALL` (流线型V字破浪掩体 - Sleek Angled Wing, `170x34`)**:
   ```gdscript
   PackedVector2Array([
       Vector2(-28, -85), Vector2(18, 0), Vector2(-28, 85),
       Vector2(6, 85),    Vector2(50, 0), Vector2(6, -85)
   ])
   ```
3. **`TRAPEZOID_BUNKER(long_w, short_w, thick)` (楔形装甲胸墙 - Sloped Monolith)**:
   ```gdscript
   PackedVector2Array([
       Vector2(-long_w*0.5, -thick*0.5), Vector2(long_w*0.5, -thick*0.5),
       Vector2(short_w*0.5, thick*0.5),  Vector2(-short_w*0.5, thick*0.5)
   ])
   ```
4. **`HEX_PILLAR(radius)` (六棱战术立柱 - Regular 6-Sided Pillar)**:
   Regular hexagon with `radius` (default `46px`).

### 1.2 Mandatory 4-Layer Rendering for Every Wall (Preview & In-Game)
Never draw a wall as a single flat gray polygon. Render every wall in **4 layers**:
1. **Layer 1 (Outer Glow Shadow)**: Polygon scaled `1.14x`, filled with `Color(0.10, 0.30, 0.52, 0.16)`.
2. **Layer 2 (Armor Hull Fill)**: Polygon filled with deep slate-blue `Color(0.08, 0.13, 0.21, 0.96)`.
3. **Layer 3 (Inner Core & Structural Ribs)**: Inner polygon scaled `0.58x` filled with `Color(0.04, 0.07, 0.12, 0.96)`, outlined with `1.0px` `Color(0.22, 0.45, 0.68, 0.55)`, plus thin rib lines connecting each outer vertex to its corresponding inner vertex!
4. **Layer 4 (Beveled Neon Rim & Vertex Rivets)**: Closed outer `Line2D` / polyline (`width = 2.2px`, `Color(0.38, 0.70, 0.95, 0.95)`) + bright `2.5px` cyan dots drawn at every vertex.

### 1.3 Tactical Topographic Underlay (Draw Beneath All Map Objects!)
In both the **Map Selection Preview Box** and the **In-Game Arena Floor**, render a holographic tactical underlay before drawing obstacles:
1. **Base Sector Halos**: Around Blue Base `(240, 675)` and Red Base `(2160, 675)`, draw 2 concentric territory rings (`radius = 240px` dashed, `radius = 360px` faint arc) in team colors (`alpha = 0.14`).
2. **Center Axis & Nexus Compass**: Draw a vertical dashed line at `X = 1200` (`Color(0.2, 0.45, 0.7, 0.18)`) and a large faint 8-sided tactical compass ring (`radius = 270px`) centered at `(1200, 675)`.
3. **Three-Lane Circuit Conduits (兵线导流轨迹)**: Draw subtle `1.5px` dark-cyan circuit lines (`Color(0.14, 0.48, 0.72, 0.20)`) tracing the North (`Y = 240`), Center (`Y = 675`), and South (`Y = 1110`) flow paths between bases.
4. **Preview Frame Tech Brackets**: On the Map Selection screen, frame the preview viewport with 4 glowing cyan corner brackets (`┏ ┓ ┗ ┛`), a subtle scanline overlay, and top-right telemetry text: `TACTICAL HOLOTABLE // 2400x1350 // ZERO-OVERLAP VERIFIED`.

### 1.4 Multi-Layer Icon Graphics for All Terrain Nodes (Preview & In-Game)
- **蓝/红核心基地 (Core Matrix Base)**: Outer dashed octagon shield ring (`r = 76px`) + Main Hexagon (`r = 54px`, fill `alpha = 0.45`, rim `width = 3.0px`) + Inner solid Hexagon (`r = 26px`) + 6 vertex dots + center crosshair.
- **金色能源点 (Golden Energy Node)**: Outer dashed capture circle (`r = 86px`, `alpha = 0.35`) + Main golden ring (`r = 62px`, `width = 2.5px`) with 4 cardinal ticks + Inner glowing diamond core (`r = 18px`).
- **青白折射晶簇 (Refracting Crystal)**: Outer containment diamond (`r = 38px`, `alpha = 0.3`) + 8-pointed overlapping star crystal (`2 rotated diamonds`, `r = 26px`, fill `Color(0.55, 0.95, 1.0, 0.85)`, HDR rim `Color(1.8, 2.4, 2.8, 1.0)`).
- **琥珀减速区 (Entropy Slow Field)**: Outer Hexagon (`r = 110px`, fill `Color(0.65, 0.35, 0.06, 0.22)`, rim `Color(1.2, 0.65, 0.15, 0.85)`) + Inner Hexagon (`r = 64px`) + 6 radial web struts.
- **Upgrade Bottom Legend UI**: Replace the plain text legend at the bottom of the Map Selection screen with a horizontal row (`HBoxContainer`) of **styled holographic pill badges**, each rendering a custom `18x18` procedural mini-icon next to its label.

---

## 2. SIX INTERACTIVE TACTICAL TERRAIN MECHANICS (`arena_obstacles.gd`)

Implement these 6 interactive mechanics in `arena_obstacles.gd` / `main_arena.gd` and render their distinct visual signatures in both the Map Preview and the live battle:

### 2.1 Central Rotating Tri-Splitter Prism (`分光巨型棱镜` - `StaticBody2D`)
- **Layers**: Layer 3 (`PRISM_BARRIER = 4`) + Layer 5 (`ARENA_BOUNDS = 16`), Group `"tri_splitter_prism"`.
- **Visual**: Radius `48px` dual-layer 12-pointed rotating star prism at map center `(1200, 675)` with bright white-cyan HDR border `Color(2.2, 2.8, 3.2, 1.0)` and 3 outward-pointing laser vector arrows. Rotates continuously at `0.25 rad/s`.
- **Gameplay Interaction (`unit_diamond.gd`)**: When a ◆ Diamond's `Refracting Beam` hits a node in `"tri_splitter_prism"`, the beam splits into **3 simultaneous high-energy laser beams**:
  1. **Center Beam**: Aimed toward the nearest enemy (or along the reflection normal), dealing `85%` damage.
  2. **Left & Right Split Beams**: Rotated `-26°` and `+26°` from Center Beam, length `650px`, each dealing `75%` damage!

### 2.2 Directional Vector Boost Rails (`单向矢量加速轨` - `Area2D`)
- **Visual**: Rectangular speed track (`size = Vector2(680, 86)`) with translucent gold-cyan floor fill, glowing side guide rails, and animated scrolling chevron arrows (`>>>` or `<<<`).
- **Gameplay Interaction**: Checks unit movement dot product `unit.velocity.normalized().dot(rail_dir)`:
  - Moving with the rail (`dot >= 0.1`): **+75% Move Speed (`1.75x`)** + golden trail particles.
  - Moving against the rail (`dot < -0.2`): **-35% Move Speed (`0.65x`)**.

### 2.3 Quantum Stealth Nebulae (`量子隐匿星云` - `Area2D`)
- **Visual**: Hexagonal cloud (`radius = 115px`) with deep violet fill `Color(0.38, 0.12, 0.70, 0.28)`, rotating dashed neon purple rim `Color(1.7, 0.4, 2.5, 0.8)`, and inner star-dust dots.
- **Gameplay Interaction**: Units inside gain `is_stealthed = true` (`modulate.a = 0.45`). Enemies farther than `145px` outside the nebula cannot target stealthed units unless revealed by an enemy stepping into the same nebula or by an `EMP_STRIKE` / Hexagon scan pulse.

### 2.4 Paired Phase Wormholes (`成对相位折跃虫洞` - `Area2D`)
- **Visual**: Swirling dual-ring portal (`radius = 40px`, Magenta-Cyan HDR `Color(2.2, 0.5, 2.6, 1.0)`). Linked wormhole pairs draw a faint curved/dashed quantum tether line connecting entry and exit on the tactical map.
- **Gameplay Interaction**: Teleports entering units (`teleport_cooldown <= 0`) instantaneously to the linked exit wormhole, sets `unit.teleport_cooldown = 8.0s`, and grants a `1.35x` speed buff for `2.0s`. Each wormhole pair holds **5 charges** before entering a `14.0s` cooldown recharge.

### 2.5 Dynamic Phase Shifting Gates (`动态相位升降闸门` - `StaticBody2D`)
- **Visual & Cycle**: Toggles every `35.0s` (**20s Closed Solid Barrier** on Layer 5 -> **15s Open Passage** with collision disabled).
- Drawn as an orange-cyan energy barrier (`150x18 px`) between two terminal pylons, with an on-map progress bar showing time until gate toggle.

### 2.6 Periodic Overload Reactor & Flux Crystals (`脉冲过载反应堆` - `Area2D`)
- **Visual & Cycle (Every `55.0s` at `(1200, 675)`)**:
  - **Normal (`0s~49s`)**: Radius `210px` crimson-gold hexagonal reactor core with rotating gauge ticks.
  - **Warning (`49s~55s`)**: Flashes bright crimson warning rings and emits `reactor_overload_warning`. AI units with `avoid_hazards == true` automatically evacuate the `210px` circle!
  - **Detonation (`55.0s`)**: Deals `160` AoE damage inside the ring and spawns **3 Collectible `FluxCrystal` pickups (`+50 Flux` each)** around the perimeter.

---

## 3. REDESIGNED 6-MAP POOL: EXACT NON-OVERLAPPING COORDINATES (`2400 x 1350`)

Use these exact, mathematically verified coordinates for all 6 existing map slots (`Blue Base = (240, 675)`, `Red Base = (2160, 675)`). **Every wall, zone, and crystal has `>= 170px` clearance so ZERO overlap ever occurs!**

### Map 1: `均衡前线` (Balanced Frontline — 3-Lane Standard + Phase Gates & Stealth Pockets)
- **Description**: `"标准三路对称防线，中路两侧设量子隐匿星云与动态升降闸门，攻守兼备。"`
- **Energy Nodes**: `(1200, 230)`, `(1200, 1120)`
- **Slow Zones**: `(840, 675)`, `(1560, 675)`
- **Stealth Nebulae**: `(1200, 460)`, `(1200, 890)`
- **Dynamic Phase Gates**: `(960, 410)` (rot `-25°`), `(1440, 940)` (rot `-25°`)
- **Refracting Crystals**: `(680, 260)`, `(1720, 1090)`, `(960, 940)`, `(1440, 410)`
- **Walls**:
  - `CHAMFER_BASTION(68, 150)` at `(540, 675)` (rot `0°`) and `(1860, 675)` (rot `0°`)
  - `TRAPEZOID_BUNKER(155, 100, 36)` at `(760, 350)` (rot `-20°`), `(760, 1000)` (rot `20°`), `(1640, 350)` (rot `20°`), `(1640, 1000)` (rot `-20°`)

### Map 2: `双翼迂回` (Dual-Wing Flank — Clockwise Vector Speed Rails & Stealth Ambush)
- **Description**: `"南北外侧铺设顺时针单向矢量加速轨(+75%移速)，配合侧翼隐匿星云实现闪电包抄。"`
- **Vector Boost Rails**: North Rail at `(1200, 130)` pointing `RIGHT (>>>)`; South Rail at `(1200, 1220)` pointing `LEFT (<<<)`
- **Energy Nodes**: `(880, 310)`, `(1520, 1040)`
- **Stealth Nebulae**: `(1520, 310)`, `(880, 1040)`
- **Slow Zones**: `(1200, 675)`
- **Refracting Crystals**: `(1200, 380)`, `(1200, 970)`
- **Walls**:
  - `CHAMFER_BASTION(170, 52)` at `(980, 520)` (rot `18°`) and `(1420, 830)` (rot `18°`)
  - `CHEVRON_WALL` at `(580, 380)` (rot `28°`), `(580, 970)` (rot `-28°`), `(1820, 380)` (rot `152°`), `(1820, 970)` (rot `-152°`)

### Map 3: `折光阵列` (Refraction Array — Central Tri-Splitter Prism & 6-Crystal Lattice)
- **Description**: `"中央矗立旋转三向分光巨型棱镜，配合六颗折光晶簇构成全屏折跃激光火力网。"`
- **Central Tri-Splitter Prism**: `(1200, 675)` (`radius = 48px`)
- **Energy Nodes**: `(1200, 260)`, `(1200, 1090)`
- **Slow Zones**: `(740, 675)`, `(1660, 675)`
- **Refracting Crystals (6x)**: `(920, 410)`, `(920, 940)`, `(1480, 410)`, `(1480, 940)`, `(1200, 450)`, `(1200, 900)`
- **Walls**:
  - `HEX_PILLAR(48)` at `(580, 450)`, `(580, 900)`, `(1820, 450)`, `(1820, 900)`
  - `TRAPEZOID_BUNKER(145, 95, 34)` at `(960, 200)` (rot `0°`), `(1440, 200)` (rot `0°`), `(960, 1150)` (rot `180°`), `(1440, 1150)` (rot `180°`)

### Map 4: `盘旋堡垒` (Spiral Bastion — Clean S-Curve Ramparts & Corner Phase Wormholes)
- **Description**: `"流线型斜向装甲胸墙构成 S 型盘旋走廊，四角部署成对相位虫洞实现跨地形奇袭。"`
- **Paired Phase Wormholes**: Entry `(480, 200)` <-> Exit `(1920, 1150)`
- **Energy Nodes**: `(1380, 280)`, `(1020, 1070)`
- **Slow Zones**: `(940, 290)`, `(1460, 1060)` (Well clear of all walls!)
- **Refracting Crystals**: `(1200, 675)`, `(780, 675)`, `(1620, 675)`
- **Walls (100% Non-Overlapping S-Curve)**:
  - Outer Wing Chevrons: `CHEVRON_WALL` at `(560, 460)` (rot `22°`) and `(1840, 890)` (rot `-158°`)
  - Inner Diagonal Ramparts: `TRAPEZOID_BUNKER(165, 110, 38)` at `(740, 900)` (rot `-32°`), `(1040, 560)` (rot `-32°`), `(1360, 790)` (rot `148°`), `(1660, 450)` (rot `148°`)

### Map 5: `交叉火线` (Crossfire — X-Corridor Chokepoints, Dual Wormholes & Phase Gates)
- **Description**: `"X 型交叉装甲走廊配双链路折跃虫洞与动态闸门，战线瞬息万变。"`
- **Paired Phase Wormholes**: Pair A `(520, 210)` <-> `(1880, 1140)` | Pair B `(520, 1140)` <-> `(1880, 210)`
- **Dynamic Phase Gates**: `(1200, 420)` (rot `0°`), `(1200, 930)` (rot `0°`)
- **Energy Nodes**: `(840, 280)`, `(1560, 1070)`
- **Stealth Nebulae**: `(1560, 280)`, `(840, 1070)`
- **Refracting Crystals**: `(1200, 675)`, `(640, 675)`, `(1760, 675)`
- **Walls**:
  - 4 X-Corridor Bastions: `CHAMFER_BASTION(160, 44)` at `(950, 490)` (rot `34°`), `(950, 860)` (rot `-34°`), `(1450, 490)` (rot `-34°`), `(1450, 860)` (rot `34°`)

### Map 6: `晶脉迷城` (Crystal Maze — Central Overload Reactor, Flux Crystals & Crystal Pockets)
- **Description**: `"中心设周期性电磁过载反应堆（每55秒爆出高能算力晶簇），四周环绕高密度折光晶簇与隐匿星云。"`
- **Central Overload Reactor**: `(1200, 675)` (`radius = 210px`, detonates every `55s` and spawns 3 `+50 Flux` crystals)
- **Energy Nodes**: `(1200, 200)`, `(1200, 1150)`
- **Stealth Nebulae**: `(740, 675)`, `(1660, 675)`
- **Refracting Crystals (6x)**: `(1000, 390)`, `(1400, 390)`, `(1000, 960)`, `(1400, 960)`, `(660, 340)`, `(1740, 1010)`
- **Walls**:
  - Reactor Shield Walls: `TRAPEZOID_BUNKER(150, 96, 36)` at `(1200, 410)` (rot `0°`) and `(1200, 940)` (rot `180°`)
  - Outer Pocket Bastions: `CHAMFER_BASTION(145, 44)` at `(700, 980)` (rot `25°`), `(1700, 370)` (rot `-25°`)
  - Mid Hex Pillars: `HEX_PILLAR(46)` at `(540, 520)`, `(540, 830)`, `(1860, 520)`, `(1860, 830)`

---

## 4. AI WHISKER AVOIDANCE & TERRAIN PROMPT INTEGRATION (`base_geo_unit.gd` & `tactical_brain.gd`)

1. **Three-Ray Whisker Obstacle Avoidance (`base_geo_unit.gd`)**:
   Cast 3 feeler rays (`0°`, `-38°`, `+38°`, length `unit_radius + 60px`) against Layer 5 (`ARENA_BOUNDS`). When a ray hits a wall or closed `PhaseGate`, blend `hit.normal + hit.normal.orthogonal() * steer_sign` into `desired_dir` so all 50 units glide smoothly around angled bastions without getting stuck.
2. **Terrain-Aware Prompt Keywords (`tactical_brain.gd`)**:
   - `"加速轨" / "加速带" / "高速包抄"` -> Biases flanking units onto `VectorBoostRail` corridors.
   - `"虫洞" / "折跃" / "奇袭后排"` -> Routes units through active `PhaseWormhole` portals.
   - `"星云" / "隐匿" / "埋伏"` -> Positions Diamonds and standby Triangles inside `StealthNebula` zones.
   - `"分光" / "中央棱镜" / "三向激光"` -> Directs Diamonds to fire `Refracting Beam` into the `TriSplitterPrism`.
   - `"躲避过载" / "撤出红圈" / "抢晶簇"` -> Forces units to evacuate the `OverloadReactor` during its 6s warning phase and rush collectible `FluxCrystal` pickups afterward.