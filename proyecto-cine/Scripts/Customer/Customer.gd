extends CharacterBody3D

signal arrived(customer: Node)

@export var speed: float = 2.0

# Bob mientras camina
@export var bob_speed: float = 12.0
@export var bob_amount: float = 0.08

# Pop + giro (solo mostrador)
@export var pop_height: float = 0.18
@export var pop_up_time: float = 0.08
@export var pop_down_time: float = 0.10
@export var turn_duration: float = 0.22

@export var arrive_distance: float = 0.15

enum State { IDLE, MOVING_TO_TARGET, WAITING }
var state: State = State.IDLE
var target_position: Vector3 = Vector3.ZERO
var look_at_camera_on_arrive: bool = false

var bob_time: float = 0.0

@onready var visual: Node3D = $Visual
var visual_base_y: float = 0.0

func _ready() -> void:
	visual_base_y = visual.position.y

func go_to(pos: Vector3, look_at_cam: bool) -> void:
	target_position = pos
	look_at_camera_on_arrive = look_at_cam
	state = State.MOVING_TO_TARGET

func _physics_process(delta: float) -> void:
	if state != State.MOVING_TO_TARGET:
		velocity = Vector3.ZERO
		_reset_bob()
		return

	var to_target := target_position - global_position
	to_target.y = 0.0

	if to_target.length() < arrive_distance:
		_arrive()
		return

	velocity = to_target.normalized() * speed
	move_and_slide()
	_apply_bob(delta)

func _arrive() -> void:
	if state == State.WAITING:
		return

	state = State.WAITING
	velocity = Vector3.ZERO
	_reset_bob()

	# SOLO mostrador: pop + giro
	if look_at_camera_on_arrive:
		var pop := create_tween()
		pop.tween_property(visual, "position:y", visual_base_y + pop_height, pop_up_time)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pop.tween_property(visual, "position:y", visual_base_y, pop_down_time)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

		var cam := get_viewport().get_camera_3d()
		if cam:
			var dir := cam.global_position - global_position
			dir.y = 0.0
			if dir.length() > 0.001:
				dir = dir.normalized()
				# nariz = -Z
				var target_yaw := atan2(-dir.x, -dir.z)
				var turn := create_tween()
				turn.tween_property(self, "rotation:y", target_yaw, turn_duration)\
					.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	emit_signal("arrived", self)

func _apply_bob(delta: float) -> void:
	bob_time += delta * bob_speed
	visual.position.y = visual_base_y + sin(bob_time) * bob_amount

func _reset_bob() -> void:
	bob_time = 0.0
	visual.position.y = visual_base_y
