extends Node3D
## Ponto de entrada: monta mundo, interface, jogador e NPCs.

const World = preload("res://world.gd")
const Player = preload("res://player.gd")
const UI = preload("res://ui.gd")
const NPC = preload("res://npc.gd")

func _ready() -> void:
	Engine.max_fps = 30   # meta de desempenho; aumente para 60 em aparelhos fortes
	var world = World.new()
	world.name = "World"
	add_child(world)
	var ui = UI.new()
	ui.name = "UI"
	add_child(ui)
	var player = Player.new()
	player.name = "Player"
	player.ui = ui
	player.position = Vector3(0, 1.0, 4)
	add_child(player)
	ui.player = player
	NPC.populate(self, world)
