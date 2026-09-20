class_name BallistaArena
extends Node3D

const MOUNT: Vector3 = Vector3(0, 2.2, -19.0)
const FINISH_Z: float = -16.0


func build(visuals: bool) -> void:
	Blockout.box(self, Vector3(0, -0.25, 0), Vector3(12, 0.5, 40), Blockout.STONE, true, visuals)
	for x: float in [-6.2, 6.2]:
		Blockout.box(self, Vector3(x, 1.3, 0), Vector3(0.4, 2.6, 40), Blockout.WOOD, true, visuals)
	for z: float in [-20.2, 18.2]:
		Blockout.box(self, Vector3(0, 1.3, z), Vector3(12, 2.6, 0.4), Blockout.WOOD, true, visuals)
	for at: Vector3 in [Vector3(-2.5, 1.3, 8), Vector3(2.5, 1.3, 0), Vector3(-2.5, 1.3, -8)]:
		Blockout.box(self, at, Vector3(3.8, 2.6, 1.0), Blockout.WOOD, true, visuals)
		if visuals:
			Blockout.box(self, at + Vector3(0, 1.4, 0), Vector3(4.0, 0.15, 1.2), Blockout.GOLD)
	if visuals:
		Blockout.box(self, Vector3(0, 0.025, FINISH_Z), Vector3(12, 0.05, 0.6), Blockout.GOLD)
		Blockout.box(self, MOUNT + Vector3(0, -1.2, 0), Vector3(2, 2, 1.2), Blockout.WOOD)
		Blockout.box(self, MOUNT, Vector3(3.3, 0.2, 0.3), Blockout.GOLD)
		Blockout.box(self, MOUNT + Vector3(0, 0, 0.5), Vector3(0.3, 0.25, 2.0), Blockout.WOOD)
		var sign: Label3D = Label3D.new()
		add_child(sign)
		sign.position = Vector3(0, 3.8, -18)
		sign.text = "FINISH"
		sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sign.font_size = 64
		sign.modulate = Blockout.GOLD
