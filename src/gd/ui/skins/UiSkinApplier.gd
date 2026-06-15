extends Node
class_name UiSkinApplier

const DEFAULT_SKIN_PATH: String = "res://src/gd/ui/skins/ui_skin_placeholder.tres"


static func load_default_skin() -> UiSkin:
	return load(DEFAULT_SKIN_PATH) as UiSkin


static func apply_to_scene(root: Node, skin: UiSkin) -> void:
	if root == null or skin == null:
		return

	_apply_texture(root, "CenterContainer/MenuPanel/MenuMargin/MenuVBox/Logo", skin.menu_logo_icon)
	_apply_texture(root, "CenterContainer/MenuPanel/MenuMargin/MenuVBox/StartTestLevelButton", skin.menu_start_icon)
	_apply_texture(root, "CenterContainer/MenuPanel/MenuMargin/MenuVBox/PracticeFlowButton", skin.menu_practice_icon)
	_apply_texture(root, "CenterContainer/MenuPanel/MenuMargin/MenuVBox/QuitButton", skin.menu_quit_icon)

	_apply_texture(root, "HeaderPanel/HeaderMargin/HeaderContent/HeaderIconSlot", skin.flow_header_icon)
	_apply_texture(root, "ActionStripPanel/MarginContainer/ActionStripRow/ActionStripIconSlot", skin.flow_action_strip_icon)

	_apply_texture(root, "CenterContainer/HudCard/CardMargin/VBoxContainer/LiveSectionIconSlot", skin.hud_live_input_icon)
	_apply_texture(root, "CenterContainer/HudCard/CardMargin/VBoxContainer/BattleSectionIconSlot", skin.hud_battle_state_icon)
	_apply_texture(root, "CenterContainer/HudCard/CardMargin/VBoxContainer/SessionSectionIconSlot", skin.hud_session_summary_icon)

	_apply_texture(root, "CenterContainer/WorldPanel/WorldRect/BossGateZone/BossGateIcon", skin.boss_gate_icon)


static func _apply_texture(root: Node, path: NodePath, texture: Texture2D) -> void:
	if texture == null:
		return
	var node: Node = root.get_node_or_null(path)
	if node == null:
		return
	if node is TextureRect:
		(node as TextureRect).texture = texture
		return
	if node is Button:
		(node as Button).icon = texture
