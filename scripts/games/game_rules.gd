class_name GameRules
extends Resource

@export var title: String = ""
@export var game_id: StringName = &""
@export var view_scene: PackedScene
@export var control_profile: StringName = &"station"
@export var rotating_roles: bool = false
@export var performance_label: String = "performance"
@export var performance_scale: float = 1.0
@export_multiline var instructions: String = ""
@export var scene: PackedScene
@export var round_count: int = 3
@export var instruction_seconds: float = 6.0
@export var countdown_seconds: float = 3.0
@export var results_seconds: float = 3.0
@export var duration: float = 60.0
@export var points: PackedInt32Array = PackedInt32Array([3, 2, 1, 0])
