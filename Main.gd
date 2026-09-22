extends Node2D

## Willowmere is a small playable RPG scene. Replace this placeholder with your
## Google AI Studio key, or paste one into the in-game Settings panel.
const GEMINI_API_KEY: String = "GEMINI_API_HERE"
const GEMINI_MODEL: String = "gemini-3.6-flash"
const GEMINI_ENDPOINT: String = "https://generativelanguage.googleapis.com/v1beta/models/%s:generateContent?key=" % GEMINI_MODEL

const WORLD_SIZE := Vector2(1152, 720)
const PLAYER_SPEED := 145.0
const NPC_INTERACT_DISTANCE := 68.0
const ACTOR_FRAME_SIZE := 32

const COLOR_GRASS := Color("#72B85C")
const COLOR_GRASS_DARK := Color("#57974E")
const COLOR_PATH := Color("#C69A6B")
const COLOR_PATH_EDGE := Color("#A67858")
const COLOR_WATER := Color("#4C9EAF")
const COLOR_PANEL := Color("#172538")
const COLOR_PANEL_DARK := Color("#0D1828")
const COLOR_BORDER := Color("#35506B")
const COLOR_TEXT := Color("#F6F0DB")
const COLOR_MUTED := Color("#A5B3B1")
const COLOR_FAINT := Color("#71838B")
const COLOR_ACCENT := Color("#F2B35F")
const COLOR_MINT := Color("#77D3B0")
const COLOR_RED := Color("#F58D78")

const TILESET_TEXTURE: Texture2D = preload("res://asset_pack/Tileset/Tileset Grass Spring.png")
const HOUSE_TEXTURE: Texture2D = preload("res://asset_pack/Objects/House.png")
const TREE_TEXTURE: Texture2D = preload("res://asset_pack/Objects/Maple Tree.png")
const ROAD_TEXTURE: Texture2D = preload("res://asset_pack/Objects/Road copiar.png")
const FENCE_TEXTURE: Texture2D = preload("res://asset_pack/Objects/Fence's copiar.png")
const CROPS_TEXTURE: Texture2D = preload("res://asset_pack/Objects/Spring Crops.png")
const CHEST_TEXTURE: Texture2D = preload("res://asset_pack/Objects/chest.png")
const COW_TEXTURE: Texture2D = preload("res://asset_pack/Farm Animals/Female Cow Brown.png")
const CHICKEN_TEXTURE: Texture2D = preload("res://asset_pack/Farm Animals/Chicken Red.png")
const BABY_CHICKEN_TEXTURE: Texture2D = preload("res://asset_pack/Farm Animals/Baby Chicken Yellow.png")
const PLAYER_IDLE_TEXTURE: Texture2D = preload("res://asset_pack/Character/Idle.png")
const PLAYER_WALK_TEXTURE: Texture2D = preload("res://asset_pack/Character/Walk.png")

var world: Node2D
var player: CharacterBody2D
var player_sprite: AnimatedSprite2D
var actor_frames: SpriteFrames
var player_facing := "down"
var player_last_direction := Vector2.DOWN
var npcs: Array = []

var hud: Control
var interaction_panel: PanelContainer
var interaction_label: Label
var dialogue_panel: PanelContainer
var dialogue_list: VBoxContainer
var dialogue_scroll: ScrollContainer
var dialogue_input: LineEdit
var dialogue_send_button: Button
var dialogue_npc_name: Label
var dialogue_npc_role: Label
var dialogue_api_status: Label
var dialogue_typing_row: Control
var api_status_label: Label
var settings_overlay: Control

var dialogue_open := false
var active_npc: Dictionary = {}
var dialogue_history: Array[Dictionary] = []
var request_in_flight := false
var pending_user_text := ""
var api_key: String = GEMINI_API_KEY


func _ready() -> void:
	world = Node2D.new()
	world.name = "Willowmere"
	add_child(world)
	_build_world()
	_build_player()
	_build_hud()
	_update_api_status()
	_update_interaction_prompt()
	queue_redraw()


# -----------------------------------------------------------------------------
# World and scenery
# -----------------------------------------------------------------------------

func _draw() -> void:
	# The base meadow and hand-painted town paths.
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), COLOR_GRASS)
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#3E714B"), false, 8.0)

	# Large grass tiles add the texture from the supplied tileset without making
	# the playable paths noisy.
	for patch_position in [Vector2(30, 68), Vector2(860, 70), Vector2(42, 590), Vector2(840, 590)]:
		draw_texture_rect(TILESET_TEXTURE, Rect2(patch_position, Vector2(192, 64)), false, Color(1, 1, 1, 0.7))

	# Main east-west lane, north lane, and the town square.
	draw_rect(Rect2(0, 332, WORLD_SIZE.x, 100), COLOR_PATH_EDGE)
	draw_rect(Rect2(0, 340, WORLD_SIZE.x, 84), COLOR_PATH)
	draw_rect(Rect2(530, 0, 92, WORLD_SIZE.y), COLOR_PATH_EDGE)
	draw_rect(Rect2(538, 0, 76, WORLD_SIZE.y), COLOR_PATH)
	draw_rect(Rect2(454, 292, 244, 176), COLOR_PATH_EDGE)
	draw_rect(Rect2(462, 300, 228, 160), Color("#D1A676"))
	# Subtle path seams make the town readable while keeping the pixel-art style.
	for x in range(16, 1152, 64):
		draw_line(Vector2(x, 340), Vector2(x + 26, 340), Color("#DDBB8B"), 2.0)
	for y in range(20, 720, 64):
		draw_line(Vector2(538, y), Vector2(538, y + 24), Color("#DDBB8B"), 2.0)

	# A little pond makes the south-east corner feel like a destination.
	draw_circle(Vector2(934, 489), 62, Color("#397C86"))
	draw_circle(Vector2(934, 483), 56, COLOR_WATER)
	draw_arc(Vector2(934, 483), 42, 0.25, 2.2, 18, Color("#7CC3C0"), 2.0)
	draw_arc(Vector2(934, 483), 28, 3.2, 5.5, 18, Color("#3B8998"), 2.0)

	# Soil beds for the crop patch.
	draw_rect(Rect2(125, 454, 270, 120), Color("#79543E"))
	for y in range(468, 568, 25):
		draw_line(Vector2(137, y), Vector2(383, y), Color("#9A6A4A"), 2.0)


func _build_world() -> void:
	_add_world_boundaries()
	_add_circle_collision(Vector2(934, 483), 57.0)

	# Two cozy houses are extracted from the supplied house sprite sheet.
	_add_atlas_sprite(HOUSE_TEXTURE, Rect2(0, 0, 80, 112), Vector2(265, 174), 1.4, 175)
	_add_atlas_sprite(HOUSE_TEXTURE, Rect2(144, 0, 80, 112), Vector2(865, 174), 1.4, 175)
	_add_static_collision(Vector2(265, 232), Vector2(94, 22))
	_add_static_collision(Vector2(865, 232), Vector2(94, 22))
	_add_world_label("MEADOW HOUSE", Vector2(213, 247), COLOR_TEXT, 11)
	_add_world_label("SUNLIT INN", Vector2(823, 247), COLOR_TEXT, 11)

	# Maple trees frame the village and use several variations from the sheet.
	var tree_locations := [
		[Vector2(92, 150), 0], [Vector2(1100, 145), 2], [Vector2(94, 596), 3],
		[Vector2(1060, 620), 1], [Vector2(420, 112), 4], [Vector2(746, 112), 2],
		[Vector2(405, 650), 1], [Vector2(770, 646), 3]
	]
	for tree_info in tree_locations:
		var tree_position: Vector2 = tree_info[0]
		var tree_variant: int = tree_info[1]
		_add_atlas_sprite(TREE_TEXTURE, Rect2(tree_variant * 32, 0, 32, 48), tree_position, 1.5, int(tree_position.y))
		_add_static_collision(tree_position + Vector2(0, 18), Vector2(18, 12))

	# Cobble flecks from the road sheet help sell the main route.
	var stone_index := 0
	for x in range(26, 1130, 67):
		_add_atlas_sprite(ROAD_TEXTURE, Rect2((stone_index % 5) * 16, int(stone_index / 5) % 4 * 16, 16, 16), Vector2(x, 380 + (stone_index % 3) * 18), 1.0, 2)
		stone_index += 1
	for y in range(40, 690, 66):
		_add_atlas_sprite(ROAD_TEXTURE, Rect2((stone_index % 5) * 16, int(stone_index / 5) % 4 * 16, 16, 16), Vector2(572 + (stone_index % 3) * 17, y), 1.0, 2)
		stone_index += 1

	# A fenced spring garden in the lower-left corner.
	_add_atlas_sprite(FENCE_TEXTURE, Rect2(0, 32, 48, 16), Vector2(254, 448), 1.5, 450)
	_add_atlas_sprite(FENCE_TEXTURE, Rect2(0, 32, 48, 16), Vector2(254, 580), 1.5, 580)
	_add_atlas_sprite(FENCE_TEXTURE, Rect2(0, 0, 16, 48), Vector2(122, 514), 1.5, 515)
	_add_atlas_sprite(FENCE_TEXTURE, Rect2(32, 0, 16, 48), Vector2(388, 514), 1.5, 515)
	_add_static_collision(Vector2(254, 445), Vector2(260, 10))
	_add_static_collision(Vector2(254, 584), Vector2(260, 10))
	for row in range(2):
		for crop_column in range(7):
			var crop_position := Vector2(157 + crop_column * 31, 478 + row * 39)
			var crop_cell := (crop_column + row * 2) % 7
			_add_atlas_sprite(CROPS_TEXTURE, Rect2(crop_cell * 16, row * 32, 16, 32), crop_position, 1.25, int(crop_position.y))

	# Town props and farm animals.
	_add_sheet_sprite(CHEST_TEXTURE, Vector2(747, 474), 1, 2, 0, 1.5, 475)
	_add_sheet_sprite(COW_TEXTURE, Vector2(352, 517), 4, 3, 0, 1.35, 517)
	_add_sheet_sprite(COW_TEXTURE, Vector2(1000, 558), 4, 3, 4, 1.35, 558)
	_add_sheet_sprite(CHICKEN_TEXTURE, Vector2(420, 548), 4, 2, 1, 1.5, 548)
	_add_sheet_sprite(CHICKEN_TEXTURE, Vector2(890, 553), 4, 2, 3, 1.5, 553)
	_add_sheet_sprite(BABY_CHICKEN_TEXTURE, Vector2(925, 580), 4, 3, 2, 1.5, 580)
	_add_world_label("WILLOWMERE", Vector2(507, 278), Color("#FFF0C8"), 13)

	actor_frames = _create_actor_frames()
	_build_npc({
		"id": "mira",
		"name": "Mira",
		"role": "Village gardener",
		"color": Color("#F0B6C7"),
		"greeting": "Morning, traveler! The seedlings are finally enjoying the spring sun.",
		"persona": "You are Mira, an optimistic village gardener. You know the crops, seasons, birds, and quiet paths around Willowmere. You are curious about the player and offer practical, kind advice."
	}, Vector2(475, 350), 1)
	_build_npc({
		"id": "bram",
		"name": "Bram",
		"role": "Innkeeper & storyteller",
		"color": Color("#B7D5EF"),
		"greeting": "Welcome to Willowmere. If you have a tale to trade, you've found the right innkeeper.",
		"persona": "You are Bram, the warm and theatrical innkeeper of Willowmere. You collect local rumors and love telling short stories, but you never reveal secrets that would harm villagers."
	}, Vector2(692, 351), 2)
	_build_npc({
		"id": "juno",
		"name": "Juno",
		"role": "Wandering cartographer",
		"color": Color("#D6B8F0"),
		"greeting": "Oh! A new face. Every good map starts with a conversation—where are you headed?",
		"persona": "You are Juno, a thoughtful wandering cartographer resting in Willowmere. You speak about exploration, landmarks, and the wider world with poetic but useful detail."
	}, Vector2(572, 474), 3)


func _add_world_boundaries() -> void:
	_add_static_collision(Vector2(-10, WORLD_SIZE.y / 2.0), Vector2(20, WORLD_SIZE.y))
	_add_static_collision(Vector2(WORLD_SIZE.x + 10, WORLD_SIZE.y / 2.0), Vector2(20, WORLD_SIZE.y))
	_add_static_collision(Vector2(WORLD_SIZE.x / 2.0, -10), Vector2(WORLD_SIZE.x, 20))
	_add_static_collision(Vector2(WORLD_SIZE.x / 2.0, WORLD_SIZE.y + 10), Vector2(WORLD_SIZE.x, 20))


func _add_static_collision(position: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 1
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	world.add_child(body)
	return body


func _add_circle_collision(position: Vector2, radius: float) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 1
	var shape_node := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	shape_node.shape = shape
	body.add_child(shape_node)
	world.add_child(body)
	return body


func _add_atlas_sprite(texture: Texture2D, region: Rect2, position: Vector2, scale_value: float, draw_z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = region
	sprite.position = position
	sprite.scale = Vector2.ONE * scale_value
	sprite.z_index = draw_z
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(sprite)
	return sprite


func _add_sheet_sprite(texture: Texture2D, position: Vector2, columns: int, rows: int, frame: int, scale_value: float, draw_z: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.hframes = columns
	sprite.vframes = rows
	sprite.frame = frame
	sprite.position = position
	sprite.scale = Vector2.ONE * scale_value
	sprite.z_index = draw_z
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	world.add_child(sprite)
	return sprite


func _add_world_label(text: String, position: Vector2, color: Color, font_size: int) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = Vector2(130, 22)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("#29433C"))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.z_index = 900
	world.add_child(label)


func _build_npc(npc_data: Dictionary, position: Vector2, idle_frame: int) -> void:
	var body := StaticBody2D.new()
	body.name = "NPC_" + str(npc_data.get("id", "villager"))
	body.position = position
	body.z_index = int(position.y)
	body.collision_layer = 1
	body.collision_mask = 1
	body.set_meta("npc_id", str(npc_data.get("id", "")))

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(17, 13)
	collision.shape = shape
	body.add_child(collision)

	var sprite := AnimatedSprite2D.new()
	sprite.sprite_frames = actor_frames
	sprite.animation = "idle_down"
	sprite.frame = idle_frame
	sprite.position = Vector2(0, -15)
	sprite.scale = Vector2(1.35, 1.35)
	sprite.modulate = npc_data.get("color", Color.WHITE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.play()
	body.add_child(sprite)

	var name_label := Label.new()
	name_label.text = str(npc_data.get("name", "Villager")).to_upper()
	name_label.position = Vector2(-50, -59)
	name_label.size = Vector2(100, 18)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 10)
	name_label.add_theme_color_override("font_color", npc_data.get("color", COLOR_TEXT))
	name_label.add_theme_color_override("font_outline_color", Color("#263B3B"))
	name_label.add_theme_constant_override("outline_size", 4)
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(name_label)
	world.add_child(body)

	npc_data["node"] = body
	npcs.append(npc_data)


func _create_actor_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")
	_add_direction_animations(frames, "idle", PLAYER_IDLE_TEXTURE, 4, 5.0)
	_add_direction_animations(frames, "walk", PLAYER_WALK_TEXTURE, 6, 9.0)
	return frames


func _add_direction_animations(frames: SpriteFrames, prefix: String, texture: Texture2D, column_count: int, speed: float) -> void:
	var directions := ["down", "up", "side"]
	for direction_index in range(directions.size()):
		var animation_name: String = prefix + "_" + directions[direction_index]
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, speed)
		frames.set_animation_loop(animation_name, true)
		for column in range(column_count):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(column * ACTOR_FRAME_SIZE, direction_index * ACTOR_FRAME_SIZE, ACTOR_FRAME_SIZE, ACTOR_FRAME_SIZE)
			frames.add_frame(animation_name, atlas)


# -----------------------------------------------------------------------------
# Player movement and interaction
# -----------------------------------------------------------------------------

func _build_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Player"
	player.position = Vector2(575, 430)
	player.collision_layer = 1
	player.collision_mask = 1
	player.z_index = int(player.position.y)
	world.add_child(player)

	var collision := CollisionShape2D.new()
	var capsule := CapsuleShape2D.new()
	capsule.radius = 8.0
	capsule.height = 18.0
	collision.shape = capsule
	player.add_child(collision)

	player_sprite = AnimatedSprite2D.new()
	player_sprite.sprite_frames = actor_frames
	player_sprite.animation = "idle_down"
	player_sprite.position = Vector2(0, -15)
	player_sprite.scale = Vector2(1.4, 1.4)
	player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	player_sprite.play()
	player.add_child(player_sprite)

	var camera := Camera2D.new()
	camera.name = "TownCamera"
	camera.position = Vector2(0, -85)
	camera.zoom = Vector2(1.45, 1.45)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	camera.drag_horizontal_enabled = false
	camera.drag_vertical_enabled = false
	player.add_child(camera)
	camera.enabled = true


func _physics_process(_delta: float) -> void:
	if not is_instance_valid(player):
		return
	if dialogue_open or is_instance_valid(settings_overlay):
		player.velocity = Vector2.ZERO
		_update_player_animation(Vector2.ZERO)
		return

	var move_input := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		move_input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		move_input.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		move_input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		move_input.y += 1.0
	if move_input.length_squared() > 1.0:
		move_input = move_input.normalized()
	player.velocity = move_input * PLAYER_SPEED
	player.move_and_slide()
	player.position.x = clamp(player.position.x, 18.0, WORLD_SIZE.x - 18.0)
	player.position.y = clamp(player.position.y, 18.0, WORLD_SIZE.y - 18.0)
	player.z_index = int(player.position.y)
	_update_player_animation(move_input)


func _update_player_animation(move_input: Vector2) -> void:
	if move_input.length_squared() > 0.01:
		if abs(move_input.x) > abs(move_input.y):
			player_facing = "side"
			player_last_direction = Vector2(sign(move_input.x), 0)
			player_sprite.flip_h = move_input.x < 0
		elif move_input.y < 0:
			player_facing = "up"
			player_last_direction = Vector2.UP
			player_sprite.flip_h = false
		else:
			player_facing = "down"
			player_last_direction = Vector2.DOWN
			player_sprite.flip_h = false
		var walking_animation := "walk_" + player_facing
		if player_sprite.animation != walking_animation:
			player_sprite.play(walking_animation)
	else:
		var idle_animation := "idle_" + player_facing
		if player_sprite.animation != idle_animation:
			player_sprite.play(idle_animation)


func _process(_delta: float) -> void:
	if not dialogue_open and not is_instance_valid(settings_overlay):
		_update_interaction_prompt()
	if is_instance_valid(player):
		player.z_index = int(player.position.y)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			if is_instance_valid(settings_overlay):
				_close_settings()
			elif dialogue_open:
				_close_dialogue()
			return
		if not dialogue_open and not is_instance_valid(settings_overlay) and event.keycode == KEY_E:
			var nearby := _nearest_npc()
			if not nearby.is_empty():
				_open_dialogue(nearby)


func _nearest_npc() -> Dictionary:
	var closest: Dictionary = {}
	var closest_distance := NPC_INTERACT_DISTANCE
	if not is_instance_valid(player):
		return closest
	for npc in npcs:
		var npc_node: Node2D = npc.get("node")
		if not is_instance_valid(npc_node):
			continue
		var distance := player.position.distance_to(npc_node.position)
		if distance <= closest_distance:
			closest_distance = distance
			closest = npc
	return closest


func _update_interaction_prompt() -> void:
	if not is_instance_valid(interaction_panel):
		return
	var nearby := _nearest_npc()
	if nearby.is_empty():
		interaction_panel.visible = false
	else:
		interaction_panel.visible = true
		interaction_label.text = "E   TALK TO " + str(nearby.get("name", "VILLAGER")).to_upper()


# -----------------------------------------------------------------------------
# HUD and dialogue window
# -----------------------------------------------------------------------------

func _build_hud() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.name = "HUD"
	add_child(hud_layer)
	hud = Control.new()
	_full_rect(hud)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_layer.add_child(hud)

	var top_card := PanelContainer.new()
	top_card.position = Vector2(20, 18)
	top_card.size = Vector2(390, 80)
	top_card.add_theme_stylebox_override("panel", _panel_style(Color("#142336"), 13, COLOR_BORDER, 1))
	hud.add_child(top_card)
	var top_margin := _margin(16, 16, 11, 11)
	top_card.add_child(top_margin)
	var top_copy := VBoxContainer.new()
	top_copy.add_theme_constant_override("separation", 2)
	top_margin.add_child(top_copy)
	var location := Label.new()
	location.text = "WILLOWMERE"
	location.add_theme_font_size_override("font_size", 20)
	location.add_theme_color_override("font_color", COLOR_TEXT)
	top_copy.add_child(location)
	var location_subtitle := Label.new()
	location_subtitle.text = "SPRINGFALL  /  TOWN SQUARE"
	location_subtitle.add_theme_font_size_override("font_size", 10)
	location_subtitle.add_theme_color_override("font_color", COLOR_ACCENT)
	top_copy.add_child(location_subtitle)
	var controls := Label.new()
	controls.text = "WASD / ARROWS  MOVE     E  TALK"
	controls.add_theme_font_size_override("font_size", 9)
	controls.add_theme_color_override("font_color", COLOR_FAINT)
	top_copy.add_child(controls)

	var status_card := PanelContainer.new()
	status_card.anchor_left = 1.0
	status_card.anchor_right = 1.0
	status_card.offset_left = -318
	status_card.offset_top = 18
	status_card.offset_right = -20
	status_card.offset_bottom = 98
	status_card.add_theme_stylebox_override("panel", _panel_style(Color("#142336"), 13, COLOR_BORDER, 1))
	hud.add_child(status_card)
	var status_margin := _margin(14, 12, 11, 11)
	status_card.add_child(status_margin)
	var status_row := HBoxContainer.new()
	status_row.add_theme_constant_override("separation", 9)
	status_margin.add_child(status_row)
	var status_copy := VBoxContainer.new()
	status_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_copy.add_theme_constant_override("separation", 1)
	status_row.add_child(status_copy)
	api_status_label = Label.new()
	api_status_label.text = "GEMINI  /  DEMO MODE"
	api_status_label.add_theme_font_size_override("font_size", 11)
	api_status_label.add_theme_color_override("font_color", COLOR_ACCENT)
	status_copy.add_child(api_status_label)
	var model_label := Label.new()
	model_label.text = GEMINI_MODEL + "  ·  ONLINE CHAT"
	model_label.add_theme_font_size_override("font_size", 9)
	model_label.add_theme_color_override("font_color", COLOR_FAINT)
	status_copy.add_child(model_label)
	var settings_button := _ghost_button("Settings")
	settings_button.custom_minimum_size = Vector2(73, 32)
	settings_button.pressed.connect(_show_settings)
	status_row.add_child(settings_button)

	interaction_panel = PanelContainer.new()
	interaction_panel.anchor_left = 0.5
	interaction_panel.anchor_right = 0.5
	interaction_panel.anchor_top = 1.0
	interaction_panel.anchor_bottom = 1.0
	interaction_panel.offset_left = -174
	interaction_panel.offset_top = -92
	interaction_panel.offset_right = 174
	interaction_panel.offset_bottom = -48
	interaction_panel.add_theme_stylebox_override("panel", _panel_style(Color("#172A38"), 12, Color("#5B9A87"), 1))
	interaction_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(interaction_panel)
	interaction_label = Label.new()
	interaction_label.text = "E   TALK"
	interaction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interaction_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	interaction_label.add_theme_font_size_override("font_size", 12)
	interaction_label.add_theme_color_override("font_color", COLOR_MINT)
	interaction_panel.add_child(interaction_label)
	interaction_panel.visible = false

	_build_dialogue_panel()


func _build_dialogue_panel() -> void:
	dialogue_panel = PanelContainer.new()
	dialogue_panel.anchor_left = 0.5
	dialogue_panel.anchor_right = 0.5
	dialogue_panel.anchor_top = 1.0
	dialogue_panel.anchor_bottom = 1.0
	dialogue_panel.offset_left = -475
	dialogue_panel.offset_top = -292
	dialogue_panel.offset_right = 475
	dialogue_panel.offset_bottom = -18
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_panel.add_theme_stylebox_override("panel", _panel_style(Color("#101C2B"), 15, Color("#496477"), 1))
	hud.add_child(dialogue_panel)
	var margin := _margin(17, 17, 14, 14)
	dialogue_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)

	var header := HBoxContainer.new()
	header.custom_minimum_size = Vector2(0, 42)
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	var npc_avatar := PanelContainer.new()
	npc_avatar.custom_minimum_size = Vector2(39, 39)
	npc_avatar.add_theme_stylebox_override("panel", _panel_style(Color("#3E5A5B"), 11, COLOR_MINT, 1))
	var avatar_symbol := Label.new()
	avatar_symbol.text = "✦"
	avatar_symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	avatar_symbol.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	avatar_symbol.add_theme_font_size_override("font_size", 20)
	avatar_symbol.add_theme_color_override("font_color", COLOR_MINT)
	npc_avatar.add_child(avatar_symbol)
	header.add_child(npc_avatar)
	var name_copy := VBoxContainer.new()
	name_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_copy.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_copy.add_theme_constant_override("separation", 1)
	header.add_child(name_copy)
	dialogue_npc_name = Label.new()
	dialogue_npc_name.text = "VILLAGER"
	dialogue_npc_name.add_theme_font_size_override("font_size", 15)
	dialogue_npc_name.add_theme_color_override("font_color", COLOR_TEXT)
	name_copy.add_child(dialogue_npc_name)
	dialogue_npc_role = Label.new()
	dialogue_npc_role.text = ""
	dialogue_npc_role.add_theme_font_size_override("font_size", 10)
	dialogue_npc_role.add_theme_color_override("font_color", COLOR_ACCENT)
	name_copy.add_child(dialogue_npc_role)
	dialogue_api_status = Label.new()
	dialogue_api_status.text = "GEMINI LINK"
	dialogue_api_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dialogue_api_status.add_theme_font_size_override("font_size", 10)
	dialogue_api_status.add_theme_color_override("font_color", COLOR_MINT)
	header.add_child(dialogue_api_status)
	var close_button := _ghost_button("Esc  ×")
	close_button.custom_minimum_size = Vector2(67, 31)
	close_button.pressed.connect(_close_dialogue)
	header.add_child(close_button)

	var divider := ColorRect.new()
	divider.custom_minimum_size = Vector2(0, 1)
	divider.color = COLOR_BORDER
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(divider)

	dialogue_scroll = ScrollContainer.new()
	dialogue_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialogue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	dialogue_scroll.custom_minimum_size = Vector2(0, 102)
	content.add_child(dialogue_scroll)
	dialogue_list = VBoxContainer.new()
	dialogue_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_list.add_theme_constant_override("separation", 7)
	dialogue_scroll.add_child(dialogue_list)

	var input_row := HBoxContainer.new()
	input_row.custom_minimum_size = Vector2(0, 40)
	input_row.add_theme_constant_override("separation", 8)
	content.add_child(input_row)
	dialogue_input = LineEdit.new()
	dialogue_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_input.placeholder_text = "Say something to this villager..."
	dialogue_input.add_theme_font_size_override("font_size", 12)
	dialogue_input.add_theme_color_override("font_color", COLOR_TEXT)
	dialogue_input.add_theme_color_override("font_placeholder_color", COLOR_FAINT)
	dialogue_input.add_theme_stylebox_override("normal", _panel_style(Color("#0A1523"), 9, COLOR_BORDER, 1))
	dialogue_input.add_theme_stylebox_override("focus", _panel_style(Color("#0A1523"), 9, COLOR_MINT, 1))
	dialogue_input.text_submitted.connect(_on_dialogue_text_submitted)
	input_row.add_child(dialogue_input)
	dialogue_send_button = Button.new()
	dialogue_send_button.text = "Send  ↗"
	dialogue_send_button.custom_minimum_size = Vector2(93, 38)
	dialogue_send_button.add_theme_font_size_override("font_size", 11)
	_apply_button_style(dialogue_send_button, Color("#337C75"), Color("#4D9E91"), Color("#28655F"))
	dialogue_send_button.add_theme_color_override("font_color", Color.WHITE)
	dialogue_send_button.pressed.connect(_send_dialogue_message)
	input_row.add_child(dialogue_send_button)
	dialogue_panel.visible = false


func _open_dialogue(npc: Dictionary) -> void:
	if dialogue_open:
		return
	active_npc = npc
	dialogue_open = true
	interaction_panel.visible = false
	dialogue_panel.visible = true
	dialogue_npc_name.text = str(npc.get("name", "VILLAGER")).to_upper()
	dialogue_npc_role.text = str(npc.get("role", "TOWNSPERSON")).to_upper()
	dialogue_api_status.text = "GEMINI LINK  ·  READY" if _has_api_key() else "DEMO MODE  ·  KEY NEEDED"
	dialogue_api_status.add_theme_color_override("font_color", COLOR_MINT if _has_api_key() else COLOR_ACCENT)
	for child in dialogue_list.get_children():
		child.free()
	dialogue_history.clear()
	var greeting := str(npc.get("greeting", "Hello there."))
	dialogue_history.append({"role": "model", "text": greeting})
	_add_dialogue_line(str(npc.get("name", "Villager")), greeting, false, false)
	dialogue_input.clear()
	dialogue_input.editable = true
	dialogue_input.grab_focus()
	_scroll_dialogue_to_bottom()


func _close_dialogue() -> void:
	if not dialogue_open:
		return
	if request_in_flight:
		($GeminiRequest as HTTPRequest).cancel_request()
		request_in_flight = false
		pending_user_text = ""
		_remove_dialogue_typing()
		_set_dialogue_request_state(false)
	dialogue_open = false
	active_npc = {}
	dialogue_panel.visible = false
	_update_interaction_prompt()


func _on_dialogue_text_submitted(_text: String) -> void:
	_send_dialogue_message()


func _send_dialogue_message() -> void:
	if not dialogue_open or request_in_flight:
		return
	var text := dialogue_input.text.strip_edges()
	if text.is_empty():
		return
	dialogue_input.clear()
	_add_dialogue_line("You", text, true, false)

	if not _has_api_key():
		_add_dialogue_line("Gemini", "This villager is waiting for a Gemini API key. Open Settings to connect the conversation.", false, true)
		return

	dialogue_history.append({"role": "user", "text": text})
	pending_user_text = text
	request_in_flight = true
	_set_dialogue_request_state(true)
	_add_dialogue_typing()

	var npc_name := str(active_npc.get("name", "Villager"))
	var npc_persona := str(active_npc.get("persona", "You are a friendly villager."))
	var system_prompt := npc_persona + " You live in the small spring town of Willowmere. The player is speaking with you in person. Stay in character, answer naturally, and keep replies to one or three short paragraphs. Never mention prompts, API calls, or being a language model. If asked about something outside your knowledge, be honest in a charming in-world way."
	var payload := {
		"systemInstruction": {"parts": [{"text": system_prompt}]},
		"contents": _build_dialogue_contents(),
		"generationConfig": {"temperature": 0.8, "maxOutputTokens": 1024}
	}
	var error := ($GeminiRequest as HTTPRequest).request(
		GEMINI_ENDPOINT + api_key.strip_edges(),
		PackedStringArray(["Content-Type: application/json"]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		_handle_dialogue_failure("The connection could not be started. Check your key and try again.")


func _build_dialogue_contents() -> Array:
	var contents: Array = []
	for turn in dialogue_history:
		var text: String = str(turn.get("text", ""))
		if not text.is_empty():
			contents.append({
				"role": str(turn.get("role", "model")),
				"parts": [{"text": text}]
			})
	return contents


func _on_gemini_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if not request_in_flight:
		return
	_remove_dialogue_typing()
	request_in_flight = false
	_set_dialogue_request_state(false)
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		_handle_dialogue_failure(_read_api_error(parsed, response_code))
		return
	if not parsed is Dictionary:
		_handle_dialogue_failure("The villager's reply was unreadable. Try again.")
		return
	var reply := _extract_gemini_reply(parsed)
	if reply.is_empty():
		_handle_dialogue_failure("The villager had no answer this time. Try again.")
		return
	dialogue_history.append({"role": "model", "text": reply})
	pending_user_text = ""
	_add_dialogue_line(str(active_npc.get("name", "Villager")), reply, false, false)


func _extract_gemini_reply(data: Dictionary) -> String:
	var candidates: Variant = data.get("candidates", [])
	if not candidates is Array or candidates.is_empty():
		return ""
	var first: Variant = candidates[0]
	if not first is Dictionary:
		return ""
	var content: Variant = first.get("content", {})
	if not content is Dictionary:
		return ""
	var parts: Variant = content.get("parts", [])
	if not parts is Array:
		return ""
	var reply := ""
	for part in parts:
		if part is Dictionary and part.has("text"):
			reply += str(part.get("text", ""))
	return reply.strip_edges()


func _read_api_error(data: Variant, response_code: int) -> String:
	if data is Dictionary:
		var api_error: Variant = data.get("error", {})
		if api_error is Dictionary:
			var message := str(api_error.get("message", ""))
			if not message.is_empty():
				return "Gemini: " + message
	return "Gemini returned HTTP %d. Check your API key and try again." % response_code


func _handle_dialogue_failure(message: String) -> void:
	_remove_dialogue_typing()
	if request_in_flight:
		request_in_flight = false
		_set_dialogue_request_state(false)
	if not dialogue_history.is_empty() and str(dialogue_history.back().get("text", "")) == pending_user_text:
		dialogue_history.pop_back()
	pending_user_text = ""
	if dialogue_open:
		_add_dialogue_line("Gemini", message, false, true)


func _set_dialogue_request_state(busy: bool) -> void:
	if is_instance_valid(dialogue_send_button):
		dialogue_send_button.disabled = busy
		dialogue_send_button.text = "Thinking..." if busy else "Send  ↗"
	if is_instance_valid(dialogue_input):
		dialogue_input.editable = not busy
	if is_instance_valid(dialogue_api_status):
		dialogue_api_status.text = "GEMINI LINK  ·  THINKING..." if busy else ("GEMINI LINK  ·  READY" if _has_api_key() else "DEMO MODE  ·  KEY NEEDED")


func _add_dialogue_line(speaker: String, text: String, from_player: bool, is_error: bool) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	if from_player:
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
	var bubble := PanelContainer.new()
	bubble.custom_minimum_size = Vector2(320 if from_player else 390, 0)
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END if from_player else Control.SIZE_SHRINK_BEGIN
	var fill_color := Color("#23424A") if from_player else Color("#1A2B3A")
	var border_color := Color("#467D78") if from_player else Color("#365368")
	if is_error:
		fill_color = Color("#382731")
		border_color = Color("#875060")
	bubble.add_theme_stylebox_override("panel", _panel_style(fill_color, 9, border_color, 1))
	var margin := _margin(11, 11, 7, 7)
	bubble.add_child(margin)
	var copy := VBoxContainer.new()
	copy.add_theme_constant_override("separation", 3)
	margin.add_child(copy)
	var speaker_label := Label.new()
	speaker_label.text = speaker.to_upper()
	speaker_label.add_theme_font_size_override("font_size", 9)
	speaker_label.add_theme_color_override("font_color", COLOR_RED if is_error else (COLOR_ACCENT if from_player else COLOR_MINT))
	copy.add_child(speaker_label)
	var body := Label.new()
	body.text = text
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_font_size_override("font_size", 12)
	body.add_theme_color_override("font_color", Color("#FFD8D3") if is_error else COLOR_TEXT)
	copy.add_child(body)
	row.add_child(bubble)
	if not from_player:
		var end_space := Control.new()
		end_space.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(end_space)
	dialogue_list.add_child(row)
	_scroll_dialogue_to_bottom()


func _add_dialogue_typing() -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_typing_row = row
	var bubble := PanelContainer.new()
	bubble.custom_minimum_size = Vector2(170, 31)
	bubble.add_theme_stylebox_override("panel", _panel_style(Color("#1A2B3A"), 9, COLOR_BORDER, 1))
	var margin := _margin(10, 10, 5, 5)
	bubble.add_child(margin)
	var label := Label.new()
	label.text = "Thinking with Gemini..."
	label.add_theme_font_size_override("font_size", 10)
	label.add_theme_color_override("font_color", COLOR_MUTED)
	margin.add_child(label)
	row.add_child(bubble)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	dialogue_list.add_child(row)
	_scroll_dialogue_to_bottom()


func _remove_dialogue_typing() -> void:
	if is_instance_valid(dialogue_typing_row):
		dialogue_typing_row.free()
	dialogue_typing_row = null


func _scroll_dialogue_to_bottom() -> void:
	if not is_instance_valid(dialogue_scroll):
		return
	await get_tree().process_frame
	if is_instance_valid(dialogue_scroll):
		dialogue_scroll.scroll_vertical = int(dialogue_scroll.get_v_scroll_bar().max_value)


# -----------------------------------------------------------------------------
# API settings
# -----------------------------------------------------------------------------

func _has_api_key() -> bool:
	var candidate := api_key.strip_edges()
	if candidate.is_empty():
		return false
	if candidate.begins_with("PASTE_YOUR_") or candidate.begins_with("YOUR_"):
		return false
	return true


func _update_api_status() -> void:
	if not is_instance_valid(api_status_label):
		return
	if _has_api_key():
		api_status_label.text = "GEMINI  /  CONNECTED"
		api_status_label.add_theme_color_override("font_color", COLOR_MINT)
	else:
		api_status_label.text = "GEMINI  /  DEMO MODE"
		api_status_label.add_theme_color_override("font_color", COLOR_ACCENT)


func _show_settings() -> void:
	if is_instance_valid(settings_overlay):
		return
	settings_overlay = Control.new()
	_full_rect(settings_overlay)
	settings_overlay.z_index = 50
	settings_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	hud.add_child(settings_overlay)

	var shade := ColorRect.new()
	_full_rect(shade)
	shade.color = Color(0.02, 0.05, 0.08, 0.78)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.gui_input.connect(_on_settings_shade_input)
	settings_overlay.add_child(shade)

	var dialog := PanelContainer.new()
	dialog.anchor_left = 0.5
	dialog.anchor_top = 0.5
	dialog.anchor_right = 0.5
	dialog.anchor_bottom = 0.5
	dialog.offset_left = -255
	dialog.offset_top = -165
	dialog.offset_right = 255
	dialog.offset_bottom = 165
	dialog.add_theme_stylebox_override("panel", _panel_style(Color("#142336"), 15, Color("#55717D"), 1))
	settings_overlay.add_child(dialog)
	var margin := _margin(22, 22, 20, 20)
	dialog.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 11)
	margin.add_child(content)

	var title_row := HBoxContainer.new()
	title_row.custom_minimum_size = Vector2(0, 33)
	content.add_child(title_row)
	var title_copy := VBoxContainer.new()
	title_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_copy.add_theme_constant_override("separation", 1)
	title_row.add_child(title_copy)
	var title := Label.new()
	title.text = "Connect Gemini"
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title_copy.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "NPC CONVERSATIONS  /  API KEY"
	subtitle.add_theme_font_size_override("font_size", 9)
	subtitle.add_theme_color_override("font_color", COLOR_ACCENT)
	title_copy.add_child(subtitle)
	var close := _ghost_button("Close")
	close.custom_minimum_size = Vector2(64, 30)
	close.pressed.connect(_close_settings)
	title_row.add_child(close)

	var intro := Label.new()
	intro.text = "Add a Google AI Studio key to let the villagers answer in character. It stays in memory for this session."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.custom_minimum_size = Vector2(0, 39)
	intro.add_theme_font_size_override("font_size", 12)
	intro.add_theme_color_override("font_color", COLOR_MUTED)
	content.add_child(intro)

	var key_input := LineEdit.new()
	key_input.custom_minimum_size = Vector2(0, 43)
	key_input.placeholder_text = "Paste your Gemini API key"
	key_input.secret = true
	key_input.text = api_key if _has_api_key() else ""
	key_input.add_theme_font_size_override("font_size", 12)
	key_input.add_theme_color_override("font_color", COLOR_TEXT)
	key_input.add_theme_color_override("font_placeholder_color", COLOR_FAINT)
	key_input.add_theme_stylebox_override("normal", _panel_style(Color("#0A1523"), 9, COLOR_BORDER, 1))
	key_input.add_theme_stylebox_override("focus", _panel_style(Color("#0A1523"), 9, COLOR_MINT, 1))
	content.add_child(key_input)
	var hint := Label.new()
	hint.text = "Get a key at aistudio.google.com  ·  Model: " + GEMINI_MODEL
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", COLOR_FAINT)
	content.add_child(hint)
	var fill := Control.new()
	fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(fill)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)
	var action_spacer := Control.new()
	action_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(action_spacer)
	var cancel := _ghost_button("Cancel")
	cancel.custom_minimum_size = Vector2(80, 36)
	cancel.pressed.connect(_close_settings)
	actions.add_child(cancel)
	var save := Button.new()
	save.text = "Save & connect"
	save.custom_minimum_size = Vector2(132, 36)
	save.add_theme_font_size_override("font_size", 11)
	_apply_button_style(save, Color("#337C75"), Color("#4D9E91"), Color("#28655F"))
	save.add_theme_color_override("font_color", Color.WHITE)
	save.pressed.connect(_save_api_key.bind(key_input))
	actions.add_child(save)
	key_input.grab_focus()


func _on_settings_shade_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_close_settings()


func _save_api_key(key_input: LineEdit) -> void:
	var value := key_input.text.strip_edges()
	api_key = value if not value.is_empty() else GEMINI_API_KEY
	_update_api_status()
	if dialogue_open:
		dialogue_api_status.text = "GEMINI LINK  ·  READY" if _has_api_key() else "DEMO MODE  ·  KEY NEEDED"
		dialogue_api_status.add_theme_color_override("font_color", COLOR_MINT if _has_api_key() else COLOR_ACCENT)
	_close_settings()


func _close_settings() -> void:
	if is_instance_valid(settings_overlay):
		settings_overlay.queue_free()
	settings_overlay = null


# -----------------------------------------------------------------------------
# Shared UI styling
# -----------------------------------------------------------------------------

func _full_rect(control: Control) -> void:
	control.anchor_left = 0.0
	control.anchor_top = 0.0
	control.anchor_right = 1.0
	control.anchor_bottom = 1.0
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0


func _margin(left: int, right: int, top: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _panel_style(color: Color, radius: int = 10, border: Color = Color.TRANSPARENT, border_width: int = 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.border_color = border
	return style


func _apply_button_style(button: Button, normal: Color, hover: Color, pressed: Color) -> void:
	button.add_theme_stylebox_override("normal", _panel_style(normal, 8))
	button.add_theme_stylebox_override("hover", _panel_style(hover, 8))
	button.add_theme_stylebox_override("pressed", _panel_style(pressed, 8))
	button.add_theme_stylebox_override("focus", _panel_style(hover, 8, COLOR_MINT, 1))


func _ghost_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 10)
	button.add_theme_color_override("font_color", COLOR_MUTED)
	button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	button.add_theme_stylebox_override("normal", _panel_style(Color.TRANSPARENT, 8, COLOR_BORDER, 1))
	button.add_theme_stylebox_override("hover", _panel_style(Color("#22384A"), 8, Color("#568080"), 1))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("#2A4C55"), 8, COLOR_MINT, 1))
	button.add_theme_stylebox_override("focus", _panel_style(Color("#22384A"), 8, COLOR_MINT, 1))
	return button
