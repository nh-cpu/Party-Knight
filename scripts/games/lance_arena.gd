class_name LanceArena
extends Node3D

var refuges: Array[Vector3] = []
var doors: Array[StaticBody3D] = []
var signs: Array[Label3D] = []


func build(visuals: bool) -> void:
	Blockout.box(self, Vector3(0, -0.25, 0), Vector3(18.6, 0.5, 8.6), Blockout.STONE, true, visuals)
	for x: float in [-9.25, 9.25]:
		Blockout.box(self, Vector3(x, 1, 0), Vector3(0.5, 2, 8.6), Blockout.WOOD, true, visuals)
	for side: float in [-1.0, 1.0]:
		Blockout.box(self, Vector3(0, 1, side * 4.35), Vector3(18, 2, 0.3), Blockout.WOOD, true, visuals)
		var edge: float = -9.0
		for x: float in [-6.0, -2.0, 2.0, 6.0]:
			var left: float = x - 0.45
			Blockout.box(self, Vector3((edge + left) * 0.5, 0.9, side * 3.15), Vector3(left - edge, 1.8, 0.3), Blockout.WOOD, true, visuals)
			edge = x + 0.45
			var centre: Vector3 = Vector3(x, 0, side * 3.6)
			refuges.append(centre)
			for offset: float in [-0.6, 0.6]:
				Blockout.box(self, centre + Vector3(offset, 0.9, 0), Vector3(0.3, 1.8, 1.2), Blockout.WOOD, true, visuals)
			var door: StaticBody3D = Blockout.box(self, Vector3(x, 1, side * 3.15), Vector3(0.9, 2, 0.25), Blockout.RED, true, visuals) as StaticBody3D
			doors.append(door)
			if visuals:
				Blockout.box(self, centre + Vector3(0, 0.02, 0), Vector3(0.9, 0.04, 1.2), Blockout.GOLD)
				var sign: Label3D = Label3D.new()
				add_child(sign)
				sign.position = centre + Vector3(0, 2.2, 0)
				sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				sign.font_size = 56
				sign.pixel_size = 0.009
				sign.no_depth_test = true
				signs.append(sign)
		Blockout.box(self, Vector3((edge + 9) * 0.5, 0.9, side * 3.15), Vector3(9 - edge, 1.8, 0.3), Blockout.WOOD, true, visuals)
	if visuals:
		# Keep the near-side refuges visible without changing authoritative collision.
		for child: Node in get_children():
			if child is StaticBody3D and child.position.z > 3.0 and not doors.has(child):
				for mesh: Node in child.get_children():
					if mesh is MeshInstance3D:
						mesh.scale.y = 0.4


func apply_state(open: Array, locked: bool) -> void:
	for index: int in doors.size():
		var available: bool = open.has(index)
		doors[index].collision_layer = 1 if locked and not available else 0
		doors[index].position.y = 1.0 if locked and not available else 3.5
		doors[index].visible = locked and not available
		if index < signs.size():
			signs[index].text = "OPEN" if available else "CLOSING"
			signs[index].modulate = Color("97dba5") if available else Blockout.RED


func safe_refuge(at: Vector3, available: Array) -> int:
	for value: Variant in available:
		var index: int = int(value)
		var offset: Vector3 = at - refuges[index]
		if absf(offset.x) <= 0.45 - PartyPawn.RADIUS + 0.025 and absf(offset.z) <= 0.6 - PartyPawn.RADIUS + 0.025:
			return index
	return -1
