class_name UnitCatalog
extends RefCounted

const TYPES: Array[String] = ["triangle", "square", "circle", "diamond", "hexagon"]
const DATA: Dictionary = {
 "triangle": {"name": "STRIKER", "zh": "锐角突击", "cost": 30, "hp": 130.0, "speed": 270.0, "radius": 15.0, "range": 36.0, "damage": 24.0, "attack_cd": 0.9, "skill_cd": 4.5},
 "square": {"name": "BULWARK", "zh": "棱镜壁垒", "cost": 50, "hp": 460.0, "speed": 115.0, "radius": 22.0, "range": 45.0, "damage": 18.0, "attack_cd": 1.3, "skill_cd": 7.5},
 "circle": {"name": "SINGULARITY", "zh": "轨道坍缩", "cost": 45, "hp": 210.0, "speed": 205.0, "radius": 17.0, "range": 220.0, "damage": 18.0, "attack_cd": 1.1, "skill_cd": 8.5},
 "diamond": {"name": "PRISM", "zh": "折射狙击", "cost": 60, "hp": 105.0, "speed": 145.0, "radius": 18.0, "range": 400.0, "damage": 26.0, "attack_cd": 1.4, "skill_cd": 5.5},
 "hexagon": {"name": "COMMANDER", "zh": "全域共鸣", "cost": 120, "hp": 380.0, "speed": 120.0, "radius": 26.0, "range": 0.0, "damage": 0.0, "attack_cd": 3.5, "skill_cd": 3.5}
}
const SKILLS: Dictionary = {
 "EMP_STRIKE": {"name": "EMP STRIKE", "zh": "电磁脉冲", "key": "Z", "cost": 40.0, "cd": 22.0, "radius": 200.0},
 "OVERCLOCK": {"name": "OVERCLOCK", "zh": "矩阵超频", "key": "X", "cost": 50.0, "cd": 25.0, "radius": 120.0},
 "TOPOLOGY_SWAP": {"name": "WARP SWAP", "zh": "拓扑转移", "key": "C", "cost": 45.0, "cd": 30.0, "radius": 160.0}
}
