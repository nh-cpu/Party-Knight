extends SceneTree


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	for index: int in 6:
		var person: PeasantView = PeasantView.new()
		root.add_child(person)
		person.build(index, "Peasant", index)
		print("ASSET peasant=%d scale=%s position=%s" % [index + 1, person.model.scale, person.model.position])
		for node: Node in person.model.find_children("*", "Skeleton3D", true, false):
			var skeleton: Skeleton3D = node as Skeleton3D
			var names: Array[String] = []
			for bone: int in skeleton.get_bone_count():
				names.append(skeleton.get_bone_name(bone))
			print("BONES " + ",".join(names))
		person.free()
	quit()
