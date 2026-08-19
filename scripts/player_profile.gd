extends Node

const SAVE_PATH := "user://player_profile.cfg"

var nickname: String = ""


func _ready() -> void:
	load_profile()


func load_profile() -> void:
	var config := ConfigFile.new()

	if config.load(SAVE_PATH) == OK:
		nickname = config.get_value("player", "nickname", "")


func save_profile() -> void:
	var config := ConfigFile.new()

	config.set_value("player", "nickname", nickname)
	config.save(SAVE_PATH)


func set_nickname(new_nickname: String) -> void:
	nickname = new_nickname.strip_edges()
	save_profile()
