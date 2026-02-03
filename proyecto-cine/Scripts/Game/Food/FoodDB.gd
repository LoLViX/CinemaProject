extends Node
class_name FoodDB

const POPCORN_SCENE := "res://Scenes/Props/PopcornUsed.tscn"
const HOTDOG_SCENE := "res://Scenes/Props/Hotdog.tscn"
const CHOCOLATE_SCENE := "res://Scenes/Props/Chocolate.tscn"

# Toppings (escenas)  ✅ carpeta correcta
const KETCHUP_HOTDOG_SCENE := "res://Scenes/Props/Toppings/Ketchup_Hotdog.tscn"
const MUSTARD_HOTDOG_SCENE := "res://Scenes/Props/Toppings/Mustard_Hotdog.tscn"
const BUTTER_POPCORN_SCENE := "res://Scenes/Props/Toppings/Butter_Popcorn.tscn"
const CARAMEL_POPCORN_SCENE := "res://Scenes/Props/Toppings/Caramel_Popcorn.tscn"

static func load_scene(path: String) -> PackedScene:
	var ps := load(path) as PackedScene
	if ps == null:
		push_error("FoodDB: no se pudo cargar " + path)
	return ps
