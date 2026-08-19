extends Control

const EOSCredentials = preload("res://scripts/EOSCredentials.gd")

@onready var status_label: Label = $StatusLabel
@onready var user_label: Label = $UserLabel
@onready var nickname_edit: LineEdit = $NicknameEdit
@onready var continue_button: Button = $ContinueButton


@onready var host_button: Button = $HostButton
@onready var join_button: Button = $JoinButton

var current_lobby: HLobby = null
var multiplayer_peer: MultiplayerPeer

const LOBBY_BUCKET := "project_core_test"
const SOCKET_NAME := "ProjectCoreTest"

func _ready() -> void:
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)

	host_button.disabled = true
	join_button.disabled = true


	# Загружаем сохранённый ник
	if PlayerProfile.nickname != "":
		nickname_edit.text = PlayerProfile.nickname

	continue_button.pressed.connect(_on_continue_pressed)

	status_label.text = "Starting EOS..."

	HLog.log_level = HLog.LogLevel.INFO

	HAuth.logged_in.connect(_on_logged_in)

	# EOS credentials
	var credentials := HCredentials.new()

	credentials.product_name = EOSCredentials.PRODUCT_NAME
	credentials.product_version = EOSCredentials.PRODUCT_VERSION
	credentials.product_id = EOSCredentials.PRODUCT_ID
	credentials.sandbox_id = EOSCredentials.SANDBOX_ID
	credentials.deployment_id = EOSCredentials.DEPLOYMENT_ID
	credentials.client_id = EOSCredentials.CLIENT_ID
	credentials.client_secret = EOSCredentials.CLIENT_SECRET

	# EOS initialization
	var setup_success := await HPlatform.setup_eos_async(credentials)

	if not setup_success:
		status_label.text = "EOS initialization FAILED!"
		print("EOS initialization FAILED!")
		return

	status_label.text = "EOS initialized!"
	print("EOS initialized successfully!")

	# Если ник уже сохранён — можем сразу логиниться
	if PlayerProfile.nickname != "":
		nickname_edit.text = PlayerProfile.nickname


func _on_continue_pressed() -> void:
	var nickname := nickname_edit.text.strip_edges()

	if nickname.is_empty():
		status_label.text = "Enter a nickname!"
		return

	if nickname.length() < 2:
		status_label.text = "Nickname is too short!"
		return

	if nickname.length() > 16:
		status_label.text = "Nickname is too long!"
		return

	# Сохраняем ник
	PlayerProfile.set_nickname(nickname)

	await login_player()


func login_player() -> void:
	status_label.text = "Logging in..."
	continue_button.disabled = true
	nickname_edit.editable = false

	print("Trying to login anonymously as: ", PlayerProfile.nickname)

	await HAuth.login_anonymous_async(PlayerProfile.nickname)


func _on_logged_in() -> void:
	print("Logged in successfully!")
	print("Player nickname: ", PlayerProfile.nickname)
	print("Product User ID: ", HAuth.product_user_id)

	status_label.text = "Logged in!"

	user_label.text = (
		"Player: " + PlayerProfile.nickname +
		"\nPUID: " + HAuth.product_user_id
	)

	host_button.disabled = false
	join_button.disabled = false

func _on_host_pressed() -> void:
	status_label.text = "Creating lobby..."
	
	host_button.disabled = true
	join_button.disabled = true

	var options := EOS.Lobby.CreateLobbyOptions.new()

	options.bucket_id = LOBBY_BUCKET
	options.max_lobby_members = 4
	options.permission_level = EOS.Lobby.LobbyPermissionLevel.PublicAdvertised

	current_lobby = await HLobbies.create_lobby_async(options)

	if current_lobby == null:
		status_label.text = "Failed to create lobby!"

		host_button.disabled = false
		join_button.disabled = false

		print("Lobby creation FAILED!")
		return

	print("Lobby created!")
	print("Lobby ID: ", current_lobby.lobby_id)
	print("Owner: ", current_lobby.owner_product_user_id)

	status_label.text = "Lobby created!\nWaiting for players..."

	await start_host()

func start_host() -> void:
	multiplayer_peer = EOSGMultiplayerPeer.new()

	var result: int = multiplayer_peer.create_server(SOCKET_NAME)

	if result != OK:
		print("Failed to create EOS server: ", result)
		status_label.text = "Failed to start server!"
		return

	multiplayer.multiplayer_peer = multiplayer_peer

	print("EOS multiplayer server started!")
	status_label.text = "HOSTING!\nWaiting for player..."

func _on_join_pressed() -> void:
	status_label.text = "Searching for lobbies..."

	host_button.disabled = true
	join_button.disabled = true

	var lobbies = await HLobbies.search_by_bucket_id_async(LOBBY_BUCKET)

	if lobbies == null or lobbies.is_empty():
		status_label.text = "No lobbies found!"

		print("No lobbies found.")

		host_button.disabled = false
		join_button.disabled = false
		return

	print("Found lobbies: ", lobbies.size())

	var lobby: HLobby = lobbies[0]

	print("Joining lobby: ", lobby.lobby_id)

	current_lobby = await HLobbies.join_async(lobby)

	if current_lobby == null:
		status_label.text = "Failed to join lobby!"

		print("Failed to join lobby.")

		host_button.disabled = false
		join_button.disabled = false
		return

	print("Joined lobby!")
	print("Lobby ID: ", current_lobby.lobby_id)
	print("Host PUID: ", current_lobby.owner_product_user_id)

	status_label.text = "Joined lobby!\nConnecting..."

	await start_client(current_lobby)

func start_client(lobby: HLobby) -> void:
	multiplayer_peer = EOSGMultiplayerPeer.new()

	var result: int = multiplayer_peer.create_client(
		SOCKET_NAME,
		lobby.owner_product_user_id
	)

	if result != OK:
		print("Failed to create EOS client: ", result)
		status_label.text = "Failed to connect!"
		return

	multiplayer.multiplayer_peer = multiplayer_peer

	print("EOS multiplayer client connected!")
	status_label.text = "CONNECTED!"
