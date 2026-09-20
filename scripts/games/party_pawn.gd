class_name PartyPawn
extends CharacterBody3D

const SPEED: float = 6.0
const RADIUS: float = 0.35
const HEIGHT: float = 1.65

var impulse: Vector3 = Vector3.ZERO
var facing: Vector3 = Vector3.FORWARD
var jump_allowed: bool = false
var last_jump: bool = false
var grounded: bool = false


func _init() -> void:
	collision_layer = 2
	collision_mask = 3
	var collider: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = RADIUS
	capsule.height = HEIGHT
	collider.shape = capsule
	collider.position.y = HEIGHT * 0.5
	add_child(collider)


func simulate(frame: Dictionary, delta: float) -> void:
	var direction: Vector2 = Vector2(float(frame.get("x", 0.0)), float(frame.get("z", 0.0)))
	if not direction.is_finite():
		direction = Vector2.ZERO
	direction = direction.limit_length(1.0)
	if direction.length_squared() > 0.01:
		facing = Vector3(direction.x, 0, direction.y).normalized()
	var acceleration: float = 40.0 if direction.length_squared() > 0.0 else 50.0
	velocity.x = move_toward(velocity.x, direction.x * SPEED, acceleration * delta)
	velocity.z = move_toward(velocity.z, direction.y * SPEED, acceleration * delta)
	# Cached floor contact is stale after restoring a prediction snapshot.
	grounded = test_move(global_transform, Vector3.DOWN * 0.06)
	var jumping: bool = bool(frame.get("jump", false)) and jump_allowed
	velocity.y = (8.0 if jumping and not last_jump else -0.1) if grounded else velocity.y - 22.0 * delta
	last_jump = jumping
	var movement_velocity: Vector3 = velocity
	velocity += impulse
	move_and_slide()
	velocity = movement_velocity
	impulse = impulse.move_toward(Vector3.ZERO, 18.0 * delta)


func state(ack: int = -1) -> Dictionary:
	return {"position": position, "velocity": velocity, "impulse": impulse, "facing": facing, "grounded": grounded, "jump": last_jump, "ack": ack}


func restore(data: Dictionary) -> void:
	position = data["position"]
	velocity = data["velocity"]
	impulse = data.get("impulse", Vector3.ZERO)
	facing = data.get("facing", Vector3.FORWARD)
	grounded = bool(data.get("grounded", false))
	last_jump = bool(data.get("jump", false))
