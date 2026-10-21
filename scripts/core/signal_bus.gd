extends Node

signal unit_spawned(unit: CharacterBody2D)
signal unit_died(unit: CharacterBody2D, team: int, position: Vector2)
signal gravity_collapsed(team: int, center_pos: Vector2, radius: float)
signal hexagon_count_changed(team: int, alive_count: int)
signal communication_jammed(is_jammed: bool)
signal tactical_profile_updated(team: int, profile: Dictionary, raw_prompt: String)
signal commander_skill_requested(skill_id: String)
signal flux_updated(blue_flux: float, blue_rate: float)
signal base_hp_updated(blue_hp: float, blue_max: float, red_hp: float, red_max: float)
signal match_ended(winner_team: int, reason: String)
