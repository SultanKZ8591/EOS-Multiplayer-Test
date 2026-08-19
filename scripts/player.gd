extends CharacterBody3D

const SPEED := 4.0
const JUMP_VELOCITY := 5.0
const MOUSE_SENSITIVITY := 0.0025
const GRAVITY := 15.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D

var pitch := 0.0

# Получаем последнее отправленное состояние
var network_position := Vector3.ZERO
var network_yaw := 0.0
var network_pitch := 0.0

var send_timer := 0.0
const SEND_INTERVAL := 0.05


func _ready() -> void:
	network_position = global_position
	network_yaw = rotation.y
	network_pitch = pitch

	# Только локальный игрок управляет камерой
	if is_multiplayer_authority():
		camera.current = true
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		camera.current = false


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event is InputEventMouseMotion:
		rotation.y -= event.relative.x * MOUSE_SENSITIVITY

		pitch -= event.relative.y * MOUSE_SENSITIVITY
		pitch = clamp(pitch, deg_to_rad(-89.0), deg_to_rad(89.0))

		head.rotation.x = pitch

	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE and event.pressed:
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			else:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		process_local_movement(delta)
		send_network_state(delta)
	else:
		process_remote_player(delta)


func process_local_movement(delta: float) -> void:
	# Гравитация
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Прыжок
	if Input.is_key_pressed(KEY_SPACE) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# WASD
	var input_dir := Vector2.ZERO

	if Input.is_key_pressed(KEY_W):
		input_dir.y -= 1.0

	if Input.is_key_pressed(KEY_S):
		input_dir.y += 1.0

	if Input.is_key_pressed(KEY_A):
		input_dir.x -= 1.0

	if Input.is_key_pressed(KEY_D):
		input_dir.x += 1.0

	input_dir = input_dir.normalized()

	var direction := Vector3.ZERO

	if input_dir != Vector2.ZERO:
		direction = (
			transform.basis.x * input_dir.x +
			transform.basis.z * input_dir.y
		)

		direction.y = 0.0
		direction = direction.normalized()

	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED

	move_and_slide()


func send_network_state(delta: float) -> void:
	send_timer += delta

	if send_timer < SEND_INTERVAL:
		return

	send_timer = 0.0

	sync_transform.rpc(
		global_position,
		rotation.y,
		pitch
	)


@rpc("authority", "unreliable", "call_remote")
func sync_transform(
	new_position: Vector3,
	new_yaw: float,
	new_pitch: float
) -> void:

	network_position = new_position
	network_yaw = new_yaw
	network_pitch = new_pitch


func process_remote_player(delta: float) -> void:
	# Плавно догоняем полученное состояние
	global_position = global_position.lerp(
		network_position,
		min(delta * 15.0, 1.0)
	)

	rotation.y = lerp_angle(
		rotation.y,
		network_yaw,
		min(delta * 15.0, 1.0)
	)

	pitch = lerp(
		pitch,
		network_pitch,
		min(delta * 15.0, 1.0)
	)

	head.rotation.x = pitch
