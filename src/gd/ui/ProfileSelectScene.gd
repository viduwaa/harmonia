extends Control

## Profile selection / creation / deletion.
## Shown after the first-run mic calibration and on every subsequent launch
## (when a calibration already exists). Routes to MainMenu after a profile is
## selected. Enforces max 3 profiles and unique non-empty names.
##
## Layout (see ProfileSelectScene.tscn):
##   Title row -- ♪ Profile Selection ♪
##   Profile row -- up to 3 horizontal cards (filled or EMPTY SLOT variants)
##   Bottom -- "CREATE NEW PROFILE" gold button + recalibrate/quit secondary
##
## Card structure (filled):
##   Header  ── PROFILE N (+ decorative flourishes TextureRect slots)
##   Body    ── Avatar (TextureRect slot) | Name / Level / Pitch / Accuracy
##   Footer  ── Last Played: <relative> ─ Delete button on hover/active
##
## Card structure (empty):
##   Header  ── EMPTY SLOT
##   Body    ── shadow avatar + "EMPTY" / "SLOT" labels
##   Footer  ── (blank, kept for height symmetry)
##
## All image-carrying nodes (avatar, flourishes, background, music notes) are
## named TextureRect slots; assign the real pixel-art assets in the .tscn.

const LOCAL_DATA_MANAGER_PATH: String = "/root/LocalDataManager"
const GAME_STATE_MANAGER_PATH: String = "/root/GameStateManager"
const MAIN_MENU_SCENE_PATH: String = "res://src/gd/scenes/menu/MainMenuScene.tscn"
const MICROPHONE_CALIBRATION_SCENE_PATH: String = "res://src/gd/scenes/audio/MicrophoneCalibrationScene.tscn"
const MAX_PROFILES: int = 3
const MAX_NAME_LENGTH: int = 24
const DIALOG_PANEL_MIN_SIZE: Vector2i = Vector2i(420, 190)
const DIALOG_PANEL_BG: Color = Color(0.078, 0.071, 0.141, 0.98)
const DIALOG_LINE_BG: Color = Color(0.137, 0.094, 0.267, 0.96)
const DIALOG_LINE_BORDER: Color = Color(0.847, 0.616, 0.239, 0.85)
const DIALOG_TEXT_DARK: Color = Color(0.149, 0.106, 0.204, 1.0)

# Card sizing -- spec: aspect ratio ~1.35 : 1 (W : H).
const CARD_MIN_WIDTH: int = 240
const CARD_MIN_HEIGHT: int = 208
const CARD_AVATAR_COLUMN_MIN_WIDTH: int = 68
const HEADER_HEIGHT_FRACTION: float = 0.135
const FOOTER_HEIGHT_FRACTION: float = 0.18

# Palette (mirrors MainMenuScene / spec).
const COLOR_CARD_BG: Color = Color(0.137, 0.094, 0.267, 1.0)
const COLOR_CARD_EMPTY_BG: Color = Color(0.094, 0.078, 0.180, 1.0)
const COLOR_CARD_SECTION_DARK: Color = Color(0.075, 0.059, 0.149, 1.0)
const COLOR_GOLD: Color = Color(0.847, 0.616, 0.239, 1.0)
const COLOR_GOLD_BRIGHT: Color = Color(1.0, 0.827, 0.392, 1.0)
const COLOR_GOLD_DIM: Color = Color(0.55, 0.40, 0.18, 1.0)
const COLOR_CREAM: Color = Color(0.95, 0.94, 0.86, 1.0)
const COLOR_NAME_TEXT: Color = Color(1.0, 0.96, 0.78, 1.0)
const COLOR_STAT_TEXT: Color = Color(0.83, 0.88, 1.0, 1.0)
const COLOR_MUTED: Color = Color(0.50, 0.46, 0.62, 1.0)
const COLOR_EMPTY_ACCENT: Color = Color(0.62, 0.55, 0.78, 0.65)
const COLOR_SEPARATOR: Color = Color(0.847, 0.616, 0.239, 0.85)
const COLOR_DELETE_BG: Color = Color(0.30, 0.13, 0.13, 0.85)
const COLOR_DELETE_BORDER: Color = Color(0.55, 0.22, 0.22, 0.85)

@onready var _profiles_container: GridContainer = %ProfilesContainer
@onready var _new_profile_button: Button = %CreateProfileButton
@onready var _calibrate_button: Button = %CalibrateButton
@onready var _back_button: Button = %BackButton
@onready var _create_dialog: AcceptDialog = %CreateDialog
@onready var _name_edit: LineEdit = %NameEdit
@onready var _delete_dialog: ConfirmationDialog = %DeleteDialog
@onready var _status_label: Label = %StatusLabel

var _local_data_manager: Node
var _game_state_manager: Node
var _pending_delete_name: String = ""


func _ready() -> void:
	_local_data_manager = get_node_or_null(LOCAL_DATA_MANAGER_PATH)
	_game_state_manager = get_node_or_null(GAME_STATE_MANAGER_PATH)
	_theme_dialogs()

	_new_profile_button.pressed.connect(_on_new_profile_pressed)
	_calibrate_button.pressed.connect(_on_calibrate_pressed)
	_back_button.pressed.connect(_on_back_pressed)

	_create_dialog.confirmed.connect(_on_create_confirmed)
	_create_dialog.canceled.connect(_on_create_canceled)
	var create_confirm: Button = _create_dialog.get_ok_button()
	if create_confirm:
		create_confirm.text = "Create"
		create_confirm.disabled = true
	_name_edit.text_changed.connect(_on_name_text_changed)
	_name_edit.text_submitted.connect(_on_name_submitted)

	_delete_dialog.confirmed.connect(_on_delete_confirmed)
	_delete_dialog.canceled.connect(_on_delete_canceled)

	_refresh_profiles()


func _theme_dialogs() -> void:
	_apply_dialog_panel_theme(_create_dialog)
	_apply_dialog_panel_theme(_delete_dialog)
	_apply_dialog_action_theme(_create_dialog.get_ok_button(), false)
	_theme_dialog_secondary_buttons(_create_dialog, _create_dialog.get_ok_button())
	_apply_dialog_action_theme(_delete_dialog.get_ok_button(), true)
	_theme_dialog_secondary_buttons(_delete_dialog, _delete_dialog.get_ok_button())
	_apply_dialog_line_edit_theme(_name_edit)

	_create_dialog.title = "Create Profile"
	_delete_dialog.title = "Delete Profile"
	_create_dialog.size = DIALOG_PANEL_MIN_SIZE
	_delete_dialog.size = DIALOG_PANEL_MIN_SIZE
	_delete_dialog.dialog_text = "Delete this profile? This cannot be undone."


func _apply_dialog_panel_theme(dialog: Window) -> void:
	dialog.add_theme_stylebox_override("panel", _make_dialog_panel_style())
	dialog.add_theme_color_override("title_color", COLOR_GOLD_BRIGHT)
	dialog.add_theme_color_override("title_outline_modulate", Color(0.05, 0.03, 0.10, 1.0))
	dialog.add_theme_font_size_override("title_font_size", 20)


func _apply_dialog_action_theme(button: Button, destructive: bool) -> void:
	if button == null:
		return
	button.custom_minimum_size = Vector2(120, 34)
	button.add_theme_font_override("font", _body_font())
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("focus", _make_dialog_focus_style())
	if destructive:
		button.add_theme_color_override("font_color", Color(1.0, 0.90, 0.90, 1.0))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.96, 1.0))
		button.add_theme_stylebox_override("normal", _make_delete_style())
		button.add_theme_stylebox_override("hover", _make_delete_style())
		button.add_theme_stylebox_override("pressed", _make_delete_style())
		button.add_theme_stylebox_override("disabled", _make_delete_style())
		return
	button.add_theme_color_override("font_color", DIALOG_TEXT_DARK)
	button.add_theme_color_override("font_hover_color", DIALOG_TEXT_DARK)
	button.add_theme_color_override("font_pressed_color", Color(0.086, 0.055, 0.118, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.725, 0.627, 0.494, 0.85))
	button.add_theme_stylebox_override("normal", _make_dialog_primary_button_style("normal"))
	button.add_theme_stylebox_override("hover", _make_dialog_primary_button_style("hover"))
	button.add_theme_stylebox_override("pressed", _make_dialog_primary_button_style("pressed"))
	button.add_theme_stylebox_override("disabled", _make_dialog_primary_button_style("disabled"))


func _theme_dialog_secondary_buttons(dialog: Window, primary_button: Button) -> void:
	var button_nodes: Array[Node] = dialog.find_children("*", "Button", true, false)
	for button_node: Node in button_nodes:
		if button_node == primary_button:
			continue
		var button: Button = button_node as Button
		if button == null:
			continue
		_apply_dialog_action_theme(button, false)


func _apply_dialog_line_edit_theme(line_edit: LineEdit) -> void:
	line_edit.add_theme_font_override("font", _body_font())
	line_edit.add_theme_font_size_override("font_size", 16)
	line_edit.add_theme_color_override("font_color", COLOR_CREAM)
	line_edit.add_theme_color_override("font_placeholder_color", Color(0.70, 0.70, 0.78, 0.85))
	line_edit.add_theme_color_override("caret_color", COLOR_GOLD_BRIGHT)
	line_edit.add_theme_stylebox_override("normal", _make_dialog_line_edit_style(false))
	line_edit.add_theme_stylebox_override("focus", _make_dialog_line_edit_style(true))
	line_edit.add_theme_stylebox_override("read_only", _make_dialog_line_edit_style(false))


# ---------------------------------------------------------------------------
# Refresh / build cards
# ---------------------------------------------------------------------------

func _refresh_profiles() -> void:
	for child: Node in _profiles_container.get_children():
		child.queue_free()

	if _local_data_manager == null or not _local_data_manager.has_method("list_profiles"):
		_status_label.text = "Save system unavailable. Cannot load profiles."
		_new_profile_button.disabled = true
		_build_empty_slots(MAX_PROFILES)
		return

	var profiles: Array = _local_data_manager.call("list_profiles") as Array
	var active_name: String = ""
	if _local_data_manager.has_method("get_active_profile_name"):
		active_name = String(_local_data_manager.call("get_active_profile_name"))

	if profiles.is_empty():
		_status_label.text = "Create your first profile to begin."
	else:
		_status_label.text = "Select a profile to continue."

	var slot_index: int = 0
	var filled_count: int = 0
	for profile_variant: Variant in profiles:
		if not (profile_variant is Dictionary):
			continue
		var profile: Dictionary = profile_variant as Dictionary
		var name: String = String(profile.get("name", ""))
		if name.is_empty():
			continue
		slot_index += 1
		filled_count += 1
		var card: PanelContainer = _build_filled_card(profile, slot_index, name == active_name)
		_profiles_container.add_child(card)

	# Pad up to MAX_PROFILES with empty-slot cards so the row stays stable.
	while filled_count < MAX_PROFILES:
		filled_count += 1
		var empty_card: PanelContainer = _build_empty_card()
		_profiles_container.add_child(empty_card)

	_new_profile_button.disabled = profiles.size() >= MAX_PROFILES


# ---------------------------------------------------------------------------
# Filled profile card: Header / Body (Avatar | Stats) / Footer
# ---------------------------------------------------------------------------

func _build_filled_card(profile: Dictionary, slot_index: int, is_active: bool) -> PanelContainer:
	var name: String = String(profile.get("name", ""))
	var level: int = 1
	var lp_variant: Variant = profile.get("level_progress", {})
	if typeof(lp_variant) == TYPE_DICTIONARY:
		level = int((lp_variant as Dictionary).get("current_level_index", 1))
	var accuracy: float = float(profile.get("avg_accuracy", 0.0))
	var last_updated_unix: int = int(profile.get("last_updated_unix_sec", 0))

	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_MIN_WIDTH, CARD_MIN_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_card_style(is_active))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.focus_mode = Control.FOCUS_ALL
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	card.gui_input.connect(_on_profile_card_gui_input.bind(name))

	var stack: VBoxContainer = _make_vbox(0)
	card.add_child(stack)

	# --- Header ---------------------------------------------------------
	var header_height: int = int(float(CARD_MIN_HEIGHT) * HEADER_HEIGHT_FRACTION)
	var header: PanelContainer = _make_section(COLOR_CARD_SECTION_DARK, header_height, true, false)
	stack.add_child(header)
	_populate_filled_header(header, slot_index)

	# --- Body ----------------------------------------------------------=
	var body_row: HBoxContainer = HBoxContainer.new()
	body_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_row.add_theme_constant_override("separation", 12)
	stack.add_child(body_row)

	# Avatar column (~28%)
	var avatar_col: VBoxContainer = VBoxContainer.new()
	avatar_col.custom_minimum_size = Vector2(CARD_AVATAR_COLUMN_MIN_WIDTH, 0)
	avatar_col.alignment = 1  # center vertically
	avatar_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_row.add_child(avatar_col)
	avatar_col.add_child(_make_avatar_slot())

	# Info column (~72%)
	var info_col: VBoxContainer = _make_vbox(4)
	info_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info_col.add_theme_constant_override("separation", 5)
	body_row.add_child(info_col)
	_populate_filled_info(info_col, name, level, accuracy)

	# --- Footer --------------------------------------------------------=
	var footer_height: int = int(float(CARD_MIN_HEIGHT) * FOOTER_HEIGHT_FRACTION)
	var footer: PanelContainer = _make_section(COLOR_CARD_SECTION_DARK, footer_height, false, true)
	stack.add_child(footer)
	_populate_filled_footer(footer, name, is_active, last_updated_unix)

	return card


func _populate_filled_header(header: PanelContainer, slot_index: int) -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 4)
	header.add_child(margin)

	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = 1
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 8)
	margin.add_child(row)

	# Left decorative flourish slot (TextureRect -- assign asset in .tscn)
	var left_flourish: TextureRect = _make_flourish_slot(false)
	row.add_child(left_flourish)

	var title_label: Label = Label.new()
	title_label.text = "PROFILE %d" % slot_index
	title_label.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
	title_label.add_theme_font_override("font", _title_font())
	title_label.add_theme_font_size_override("font_size", 18)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_label)

	# Right decorative flourish slot (mirrored)
	var right_flourish: TextureRect = _make_flourish_slot(true)
	row.add_child(right_flourish)


func _populate_filled_info(info_col: VBoxContainer, name: String, level: int, accuracy: float) -> void:
	# Character name -- largest, bold, uppercase.
	var name_label: Label = Label.new()
	name_label.text = name.to_upper()
	name_label.add_theme_color_override("font_color", COLOR_NAME_TEXT)
	name_label.add_theme_font_override("font", _title_font())
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.clip_text = true
	info_col.add_child(name_label)

	# Stats -- small font, one per line, left aligned.
	info_col.add_child(_make_stat_line("Level %d" % level))
	# Pitch line: per-profile pitch tracking not persisted yet (global mic
	# calibration lives in LocalDataManager.load_audio_calibration). Wire this
	# to a profile-scoped pitch stat when one lands. Placeholder for now.
	info_col.add_child(_make_stat_line("Pitch  --"))
	info_col.add_child(_make_stat_line("Accu. %.0f%%" % accuracy))


func _populate_filled_footer(footer: PanelContainer, name: String, is_active: bool, last_updated_unix: int) -> void:
	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 4)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 4)
	footer.add_child(margin)
	var body: VBoxContainer = _make_vbox(2)
	margin.add_child(body)

	# Thin separator above footer text (per spec).
	var separator: ColorRect = ColorRect.new()
	separator.custom_minimum_size = Vector2(0, 1)
	separator.color = COLOR_SEPARATOR
	body.add_child(separator)

	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = 1
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 10)
	body.add_child(row)

	var last_played_label: Label = Label.new()
	last_played_label.text = "Last Played:  %s" % _format_relative_time(last_updated_unix)
	last_played_label.add_theme_color_override("font_color", COLOR_STAT_TEXT)
	last_played_label.add_theme_font_override("font", _body_font())
	last_played_label.add_theme_font_size_override("font_size", 14)
	last_played_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	last_played_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	last_played_label.clip_text = true
	row.add_child(last_played_label)

	# Delete affordance on the filled card footer (small trash button).
	var delete_button: Button = Button.new()
	delete_button.text = "Delete"
	delete_button.custom_minimum_size = Vector2(72, 26)
	delete_button.add_theme_color_override("font_color", Color(1.0, 0.82, 0.82, 1.0))
	delete_button.add_theme_font_override("font", _body_font())
	delete_button.add_theme_font_size_override("font_size", 13)
	delete_button.add_theme_stylebox_override("normal", _make_delete_style())
	delete_button.add_theme_stylebox_override("hover", _make_delete_style())
	delete_button.add_theme_stylebox_override("pressed", _make_delete_style())
	delete_button.pressed.connect(_on_delete_profile_pressed.bind(name))
	row.add_child(delete_button)


# ---------------------------------------------------------------------------
# Empty slot card
# ---------------------------------------------------------------------------

func _build_empty_card() -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.custom_minimum_size = Vector2(CARD_MIN_WIDTH, CARD_MIN_HEIGHT)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_empty_card_style())

	var stack: VBoxContainer = _make_vbox(0)
	card.add_child(stack)

	# Header (EMPTY SLOT)
	var header_height: int = int(float(CARD_MIN_HEIGHT) * HEADER_HEIGHT_FRACTION)
	var header: PanelContainer = _make_section(COLOR_CARD_SECTION_DARK, header_height, true, false)
	stack.add_child(header)
	var header_margin: MarginContainer = MarginContainer.new()
	header_margin.add_theme_constant_override("margin_top", 4)
	header_margin.add_theme_constant_override("margin_bottom", 4)
	header.add_child(header_margin)
	var header_label: Label = Label.new()
	header_label.text = "EMPTY SLOT"
	header_label.add_theme_color_override("font_color", COLOR_EMPTY_ACCENT)
	header_label.add_theme_font_override("font", _title_font())
	header_label.add_theme_font_size_override("font_size", 18)
	header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_margin.add_child(header_label)

	# Body -- shadow avatar + EMPTY / SLOT labels
	var body: VBoxContainer = VBoxContainer.new()
	body.alignment = 1
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	stack.add_child(body)

	var avatar: TextureRect = _make_avatar_slot()
	avatar.modulate = Color(0.45, 0.42, 0.55, 0.55)
	body.add_child(avatar)

	var empty_label: Label = Label.new()
	empty_label.text = "EMPTY"
	empty_label.add_theme_color_override("font_color", COLOR_EMPTY_ACCENT)
	empty_label.add_theme_font_override("font", _body_font())
	empty_label.add_theme_font_size_override("font_size", 18)
	empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	empty_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(empty_label)

	var slot_label: Label = Label.new()
	slot_label.text = "SLOT"
	slot_label.add_theme_color_override("font_color", COLOR_MUTED)
	slot_label.add_theme_font_override("font", _body_font())
	slot_label.add_theme_font_size_override("font_size", 14)
	slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(slot_label)

	# Footer -- kept for height symmetry, blank.
	var footer_height: int = int(float(CARD_MIN_HEIGHT) * FOOTER_HEIGHT_FRACTION)
	var footer: PanelContainer = _make_section(COLOR_CARD_SECTION_DARK, footer_height, false, true)
	stack.add_child(footer)

	return card


func _build_empty_slots(count: int) -> void:
	for i in range(count):
		_profiles_container.add_child(_build_empty_card())


# ---------------------------------------------------------------------------
# StyleBox / TextureRect helpers
# ---------------------------------------------------------------------------

func _make_card_style(is_active: bool) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COLOR_CARD_BG
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_right = 14
	sb.corner_radius_bottom_left = 14
	sb.border_width_left = 4
	sb.border_width_top = 4
	sb.border_width_right = 4
	sb.border_width_bottom = 4
	if is_active:
		sb.border_color = COLOR_GOLD_BRIGHT
		sb.shadow_color = Color(0, 0, 0, 0.55)
		sb.shadow_size = 18
	else:
		sb.border_color = COLOR_GOLD
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 12
	return sb


func _make_empty_card_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COLOR_CARD_EMPTY_BG
	sb.corner_radius_top_left = 14
	sb.corner_radius_top_right = 14
	sb.corner_radius_bottom_right = 14
	sb.corner_radius_bottom_left = 14
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(0.35, 0.30, 0.50, 0.55)
	sb.shadow_color = Color(0, 0, 0, 0.40)
	sb.shadow_size = 8
	return sb


func _make_section(bg_color: Color, min_height: int, round_top: bool, round_bottom: bool) -> PanelContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, min_height)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = bg_color
	if round_top:
		sb.corner_radius_top_left = 11
		sb.corner_radius_top_right = 11
	if round_bottom:
		sb.corner_radius_bottom_left = 11
		sb.corner_radius_bottom_right = 11
	panel.add_theme_stylebox_override("panel", sb)
	return panel


func _make_dialog_panel_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = DIALOG_PANEL_BG
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.border_color = COLOR_GOLD
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
	sb.shadow_size = 10
	return sb


func _make_dialog_primary_button_style(state: String) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	match state:
		"hover":
			sb.bg_color = Color(0.976, 0.765, 0.306, 1.0)
			sb.border_color = Color(1.0, 0.922, 0.537, 1.0)
		"pressed":
			sb.bg_color = Color(0.659, 0.408, 0.145, 1.0)
			sb.border_color = Color(0.933, 0.690, 0.271, 1.0)
		"disabled":
			sb.bg_color = Color(0.388, 0.318, 0.271, 0.86)
			sb.border_color = Color(0.553, 0.447, 0.329, 0.8)
		_:
			sb.bg_color = Color(0.847, 0.596, 0.188, 1.0)
			sb.border_color = Color(1.0, 0.827, 0.392, 1.0)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 5
	sb.corner_radius_top_right = 5
	sb.corner_radius_bottom_left = 5
	sb.corner_radius_bottom_right = 5
	return sb


func _make_dialog_focus_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.933, 0.596, 0.24)
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = Color(1.0, 0.933, 0.596, 1.0)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	return sb


func _make_dialog_line_edit_style(focused: bool) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = DIALOG_LINE_BG
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.border_color = COLOR_GOLD_BRIGHT if focused else DIALOG_LINE_BORDER
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 10.0
	sb.content_margin_top = 8.0
	sb.content_margin_right = 10.0
	sb.content_margin_bottom = 8.0
	return sb


func _make_delete_style() -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = COLOR_DELETE_BG
	sb.border_width_left = 1
	sb.border_width_top = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	sb.border_color = COLOR_DELETE_BORDER
	sb.corner_radius_top_left = 4
	sb.corner_radius_top_right = 4
	sb.corner_radius_bottom_right = 4
	sb.corner_radius_bottom_left = 4
	return sb


func _make_avatar_slot() -> TextureRect:
	# Replace this slot's texture in the .tscn or by assigning an avatar asset.
	# ~52x52 per spec, inside a decorative frame you can layer separately.
	var rect: TextureRect = TextureRect.new()
	rect.custom_minimum_size = Vector2(52, 52)
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	return rect


func _make_flourish_slot(flip_h: bool) -> TextureRect:
	# Decorative golden flourish in card header corners. Assign a real flourish
	# texture here or in the .tscn; for now uses a border slice so it renders.
	var rect: TextureRect = TextureRect.new()
	rect.custom_minimum_size = Vector2(20, 20)
	rect.expand_mode = TextureRect.EXPAND_KEEP_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.flip_h = flip_h
	rect.modulate = COLOR_GOLD_BRIGHT
	return rect


func _make_vbox(separation: int) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.add_theme_constant_override("separation", separation)
	return v


func _make_stat_line(text: String) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color", COLOR_STAT_TEXT)
	label.add_theme_font_override("font", _body_font())
	label.add_theme_font_size_override("font_size", 15)
	return label


# ---------------------------------------------------------------------------
# Misc helpers
# ---------------------------------------------------------------------------

func _title_font() -> FontFile:
	return load("res://src/gd/assets/ui/fonts/menu_button.ttf") as FontFile


func _body_font() -> FontFile:
	return load("res://src/gd/assets/ui/fonts/PixeloidSans.ttf") as FontFile


func _format_relative_time(unix_sec: int) -> String:
	if unix_sec <= 0:
		return "never"
	var now: int = int(Time.get_unix_time_from_system())
	var delta: int = now - unix_sec
	if delta < 0:
		delta = 0
	if delta < 60:
		return "just now"
	if delta < 3600:
		return "%d min ago" % int(delta / 60)
	if delta < 86400:
		return "%d hr ago" % int(delta / 3600)
	if delta < 604800:
		return "%d d ago" % int(delta / 86400)
	return "%d d ago" % int(delta / 604800)


# ---------------------------------------------------------------------------
# Event handlers (unchanged behavior; only button references renamed)
# ---------------------------------------------------------------------------

func _on_new_profile_pressed() -> void:
	if _local_data_manager == null or not _local_data_manager.has_method("get_profile_count"):
		return
	if int(_local_data_manager.call("get_profile_count")) >= MAX_PROFILES:
		_status_label.text = "Profile limit reached (%d)." % MAX_PROFILES
		return
	_name_edit.text = ""
	_on_name_text_changed(_name_edit.text)
	_create_dialog.popup_centered()
	_name_edit.grab_focus()


func _on_create_confirmed() -> void:
	var name: String = _name_edit.text.strip_edges()
	if name.is_empty():
		_status_label.text = "Profile name cannot be empty."
		return
	if name.length() > MAX_NAME_LENGTH:
		name = name.substr(0, MAX_NAME_LENGTH)

	if _local_data_manager == null or not _local_data_manager.has_method("create_profile"):
		_status_label.text = "Save system unavailable."
		return
	var created: Dictionary = _local_data_manager.call("create_profile", name) as Dictionary
	if created.is_empty():
		_status_label.text = "Could not create profile '%s'." % name
		return
	_status_label.text = "Profile '%s' created." % name
	_activate_profile(name)


func _on_create_canceled() -> void:
	_name_edit.text = ""


func _on_name_text_changed(new_text: String) -> void:
	var ok_button: Button = _create_dialog.get_ok_button()
	if ok_button == null:
		return
	ok_button.disabled = new_text.strip_edges().is_empty()


func _on_name_submitted(_text: String) -> void:
	var ok_button: Button = _create_dialog.get_ok_button()
	if ok_button != null and not ok_button.disabled:
		_create_dialog.hide()
		_on_create_confirmed()


func _on_select_profile(name: String) -> void:
	_activate_profile(name)
	# Selecting the whole card is handled in _on_card_activated; this entry is
	# kept for explicit "Play" buttons if a future variant adds one.


func _on_card_activated(name: String) -> void:
	_activate_profile(name)


func _on_profile_card_gui_input(event: InputEvent, name: String) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			_on_card_activated(name)
	elif event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER or key_event.keycode == KEY_SPACE:
				_on_card_activated(name)


func _activate_profile(name: String) -> void:
	if _game_state_manager != null and _game_state_manager.has_method("set_active_profile"):
		if not bool(_game_state_manager.call("set_active_profile", name)):
			_status_label.text = "Failed to activate '%s'." % name
			return
	elif _local_data_manager != null and _local_data_manager.has_method("set_active_profile_name"):
		_local_data_manager.call("set_active_profile_name", name)
	else:
		_status_label.text = "Save system unavailable."
		return
	_change_scene(MAIN_MENU_SCENE_PATH, "main menu")


func _on_delete_profile_pressed(name: String) -> void:
	_pending_delete_name = name
	_delete_dialog.dialog_text = "Delete profile '%s'? This cannot be undone." % name
	_delete_dialog.popup_centered()


func _on_delete_confirmed() -> void:
	var name: String = _pending_delete_name
	_pending_delete_name = ""
	if name.is_empty():
		return
	if _local_data_manager == null or not _local_data_manager.has_method("delete_profile"):
		return
	if bool(_local_data_manager.call("delete_profile", name)):
		_status_label.text = "Profile '%s' deleted." % name
		_refresh_profiles()
	else:
		_status_label.text = "Could not delete '%s'." % name


func _on_delete_canceled() -> void:
	_pending_delete_name = ""


func _on_calibrate_pressed() -> void:
	_change_scene(MICROPHONE_CALIBRATION_SCENE_PATH, "microphone calibration")


func _on_back_pressed() -> void:
	# Boot scene normally routes here directly; back exits the game.
	get_tree().quit()


func _change_scene(scene_path: String, scene_label: String) -> void:
	var result: Error = get_tree().change_scene_to_file(scene_path)
	if result != OK:
		push_warning("ProfileSelectScene: Failed to open %s scene." % scene_label)
