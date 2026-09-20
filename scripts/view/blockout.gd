class_name Blockout
extends RefCounted

const STONE: Color = Color("4c5960")
const WOOD: Color = Color("655044")
const GOLD: Color = Color("dca851")
const RED: Color = Color("bd494d")


static func material(color: Color) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.88
	return mat


static func box(parent: Node3D, at: Vector3, size: Vector3, color: Color, solid: bool = false, visible_mesh: bool = true) -> Node3D:
	var root: Node3D = StaticBody3D.new() if solid else Node3D.new()
	parent.add_child(root)
	root.position = at
	if solid:
		var collider: CollisionShape3D = CollisionShape3D.new()
		var shape: BoxShape3D = BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		root.add_child(collider)
	if visible_mesh:
		var mesh: MeshInstance3D = MeshInstance3D.new()
		var geometry: BoxMesh = BoxMesh.new()
		geometry.size = size
		mesh.mesh = geometry
		mesh.material_override = material(color)
		root.add_child(mesh)
	return root


static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, color: Color) -> MeshInstance3D:
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var geometry: CylinderMesh = CylinderMesh.new()
	geometry.top_radius = radius
	geometry.bottom_radius = radius
	geometry.height = height
	geometry.radial_segments = 12
	mesh.mesh = geometry
	mesh.material_override = material(color)
	parent.add_child(mesh)
	mesh.position = at
	return mesh


static func room(parent: Node3D) -> void:
	box(parent, Vector3(0, -0.25, 0), Vector3(20, 0.5, 18), STONE)
	box(parent, Vector3(0, 2.0, -8), Vector3(20, 4, 0.6), STONE.darkened(0.3))
	for x: float in [-9.0, 9.0]:
		box(parent, Vector3(x, 2.0, 0), Vector3(0.6, 4, 16), STONE.darkened(0.15))
	for x: float in [-7.0, -3.5, 3.5, 7.0]:
		box(parent, Vector3(x, 2.5, -7.5), Vector3(0.8, 5, 0.8), STONE.lightened(0.1))
		box(parent, Vector3(x, 3.0, -7.0), Vector3(1.3, 2.5, 0.12), RED.darkened(0.3))
		var torch: OmniLight3D = OmniLight3D.new()
		parent.add_child(torch)
		torch.position = Vector3(x, 2.2, -6.2)
		torch.light_color = Color("ffc482")
		torch.light_energy = 0.5
		torch.omni_range = 7.0
		cylinder(parent, torch.position, 0.13, 0.3, GOLD)
