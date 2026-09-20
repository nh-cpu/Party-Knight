class_name PeasantView
extends Node3D

const ASSET_ROOT: String = "res://Free Medieval 3D People Low Poly Pack/"
const COLORS: Array[Color] = [Color("e9b85b"), Color("6dbdce"), Color("d88494"), Color("9dc785")]

var dead: bool = false
var walking: float = 0.0
var reaching: float = 0.0
var drinking: bool = false
var hand_lost: bool = false
var shove_amount: float = 0.0
var model: Node3D
var _skeleton: Skeleton3D
var _rests: Dictionary = {}
var _time: float = 0.0
var _death_amount: float = 0.0
var _label: Label3D
var _wrist_cap: Node3D


func build(character: int, player_name: String, color_index: int, player_number: int = 0) -> void:
	var scene: PackedScene = load(ASSET_ROOT + "fbx/people_unity/peasant_%d.fbx" % (character + 1)) as PackedScene
	model = scene.instantiate() as Node3D
	add_child(model)
	var bounds: AABB = _bounds(model, Transform3D.IDENTITY)
	var height: float = maxf(bounds.size.y, 0.01)
	var factor: float = 1.8 / height
	model.scale *= factor
	model.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * factor
	var texture: Texture2D = load(ASSET_ROOT + "texture/people_texture_map.png") as Texture2D
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh: MeshInstance3D = node as MeshInstance3D
		var mat: StandardMaterial3D = Blockout.material(Color.WHITE)
		mat.albedo_texture = texture
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mesh.material_override = mat
	var skeletons: Array[Node] = model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons[0] as Skeleton3D
		for index: int in _skeleton.get_bone_count():
			_rests[index] = _skeleton.get_bone_pose_rotation(index)
	_label = Label3D.new()
	add_child(_label)
	_label.text = "P%d · %s" % [player_number, player_name] if player_number > 0 else player_name
	_label.position.y = 2.15
	_label.font_size = 40
	_label.pixel_size = 0.008
	_label.modulate = COLORS[color_index % COLORS.size()]
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true


func _process(delta: float) -> void:
	_time += delta
	shove_amount = move_toward(shove_amount, 0, delta * 5)
	if model == null:
		return
	_death_amount = move_toward(_death_amount, 1.0 if dead else 0.0, delta * 2.5)
	model.rotation.z = _death_amount * 1.5
	if _skeleton == null:
		return
	for index: int in _skeleton.get_bone_count():
		var bone: String = _skeleton.get_bone_name(index).to_lower()
		var pose: Vector3 = Vector3.ZERO
		var side: float = -1.0 if "left" in bone or bone.begins_with("l_") or bone.ends_with("_l") else 1.0
		if "upperarm" in bone or "upper_arm" in bone or bone.ends_with("arm"):
			pose.z = -side * 1.15
			pose.x = sin(_time * 10.0 + side) * walking * 0.5 - maxf(reaching, shove_amount) * 1.2
			if drinking:
				pose.x = -1.3
		elif "thigh" in bone or "upleg" in bone:
			pose.x = sin(_time * 10.0 + (PI if side < 0 else 0.0)) * walking * 0.55
		elif "spine" in bone:
			pose.x = sin(_time * 2.0) * 0.015 + reaching * 0.1
		elif ("forearm" in bone or "lowerarm" in bone) and drinking:
			pose.x = -1.0
		if hand_lost and bone == "lowerarm_r":
			pose.x = -0.7
		_skeleton.set_bone_pose_rotation(index, (_rests[index] as Quaternion) * Quaternion.from_euler(pose))
		if bone == "hand_r":
			_skeleton.set_bone_pose_scale(index, Vector3.ONE * (0.001 if hand_lost else 1.0))
	if is_instance_valid(_wrist_cap):
		var hand: int = _skeleton.find_bone("Hand_R")
		_wrist_cap.global_position = _skeleton.to_global(_skeleton.get_bone_global_pose(hand).origin)


func detach_hand(effects: Node3D) -> void:
	if _skeleton == null:
		return
	var index: int = _skeleton.find_bone("Hand_R")
	if index < 0:
		return
	var wrist: Vector3 = _skeleton.to_global(_skeleton.get_bone_global_pose(index).origin)
	var detached: Node3D = Blockout.box(effects, effects.to_local(wrist), Vector3(0.12, 0.08, 0.22), Color("bd9b78"))
	_wrist_cap = Blockout.box(self, to_local(wrist), Vector3(0.09, 0.035, 0.09), Color("634a3a"))
	_wrist_cap.top_level = true
	_wrist_cap.global_position = wrist
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(detached, "position", effects.to_local(Vector3(wrist.x + 0.35, 0.06, wrist.z + 0.3)), 0.45)
	tween.tween_property(detached, "rotation", Vector3(2.0, 0.4, 1.0), 0.45)


func _bounds(root: Node3D, parent_transform: Transform3D) -> AABB:
	var combined: Transform3D = parent_transform * root.transform
	var result: AABB = AABB()
	var has_bounds: bool = false
	if root is MeshInstance3D:
		var mesh: MeshInstance3D = root as MeshInstance3D
		if mesh.mesh != null:
			result = combined * mesh.get_aabb()
			has_bounds = true
	for child: Node in root.get_children():
		if child is Node3D:
			var child_bounds: AABB = _bounds(child as Node3D, combined)
			if child_bounds.size.length_squared() > 0.0:
				result = result.merge(child_bounds) if has_bounds else child_bounds
				has_bounds = true
	return result
