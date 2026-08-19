extends Node3D

const PLAYER_SCENE := preload("res://player.tscn")

@onready var players: Node3D = $Players
@onready var spawnpoints: Node3D = $Spawnpoints
@onready var spawner: MultiplayerSpawner = $MultiplayerSpawner

var players_spawned := false
var ready_peers: Array[int] = []


func _ready() -> void:
	multiplayer.server_disconnected.connect(_on_host_disconnected)
	
	spawner.spawn_function = _spawn_player

	if multiplayer.is_server():
		spawner.add_spawnable_scene("res://player.tscn")

		# Хост уже загрузил сцену
		ready_peers.append(multiplayer.get_unique_id())

		multiplayer.peer_connected.connect(_on_peer_connected)

	else:
		# Клиент сообщает хосту, что Test.tscn загружена
		scene_ready.rpc_id(1)


func _spawn_player(data: Variant) -> Node:
	var player := PLAYER_SCENE.instantiate()

	var peer_id: int = int(data)

	player.name = str(peer_id)
	player.set_multiplayer_authority(peer_id)

	return player


func _on_peer_connected(peer_id: int) -> void:
	print("Peer connected: ", peer_id)


@rpc("any_peer", "reliable")
func scene_ready() -> void:
	if not multiplayer.is_server():
		return

	var peer_id := multiplayer.get_remote_sender_id()

	if not ready_peers.has(peer_id):
		ready_peers.append(peer_id)

	var required_players := multiplayer.get_peers().size() + 1

	print(
		"Peer ",
		peer_id,
		" is ready. ",
		ready_peers.size(),
		"/",
		required_players
	)

	if ready_peers.size() >= required_players:
		spawn_all_players()


func spawn_all_players() -> void:
	if not multiplayer.is_server():
		return

	if players_spawned:
		return

	players_spawned = true

	var peer_ids: Array[int] = [1]

	for peer_id in multiplayer.get_peers():
		peer_ids.append(peer_id)

	print("Spawning players: ", peer_ids)

	for i in range(min(peer_ids.size(), 4)):
		var peer_id := peer_ids[i]

		var player := spawner.spawn(peer_id)

		if player == null:
			print("Spawn failed for peer ", peer_id)
			continue

		player.global_position = spawnpoints.get_child(i).global_position + Vector3.UP * 1.0

		print(
			"Player ",
			peer_id,
			" spawned at ",
			spawnpoints.get_child(i).name
		)

func _on_host_disconnected() -> void:
	print("Host left the game!")

	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()

	GameState.disconnect_message = "ERROR: Host left the game"

	get_tree().change_scene_to_file("res://main_menu.tscn")
