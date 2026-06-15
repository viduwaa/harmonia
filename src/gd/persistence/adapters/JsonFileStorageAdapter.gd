extends "res://src/gd/persistence/adapters/StorageAdapter.gd"


func get_adapter_id() -> String:
	return "json_file"


func is_available() -> bool:
	return true


func get_unavailable_reason() -> String:
	return ""


func write_json_document(file_path: String, payload: Dictionary, indent: String = "\t") -> bool:
	if payload.is_empty():
		return false
	if not _ensure_parent_dir(file_path):
		return false
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(payload, indent))
	file.flush()
	return true


func read_json_document(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {
			"ok": false,
			"data": {},
			"error": "File does not exist."
		}
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {
			"ok": false,
			"data": {},
			"error": "Failed to open file."
		}
	var raw_text: String = file.get_as_text()
	var json: JSON = JSON.new()
	if json.parse(raw_text) != OK:
		return {
			"ok": false,
			"data": {},
			"error": "JSON parse failed."
		}
	if typeof(json.data) != TYPE_DICTIONARY:
		return {
			"ok": false,
			"data": {},
			"error": "JSON root is not a Dictionary."
		}
	return {
		"ok": true,
		"data": json.data as Dictionary,
		"error": ""
	}


func append_json_line(file_path: String, payload: Dictionary) -> bool:
	if payload.is_empty():
		return false
	if not _ensure_parent_dir(file_path):
		return false

	var file: FileAccess = null
	if FileAccess.file_exists(file_path):
		file = FileAccess.open(file_path, FileAccess.READ_WRITE)
		if file != null:
			file.seek_end()
	else:
		file = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false

	file.store_line(JSON.stringify(payload))
	file.flush()
	return true


func read_json_lines(file_path: String, limit: int = 0) -> Array:
	if not FileAccess.file_exists(file_path):
		return []
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return []

	var records: Array = []
	while not file.eof_reached():
		var line: String = file.get_line().strip_edges()
		if line.is_empty():
			continue
		var json: JSON = JSON.new()
		if json.parse(line) != OK:
			continue
		if typeof(json.data) != TYPE_DICTIONARY:
			continue
		records.append(json.data as Dictionary)

	if limit > 0 and records.size() > limit:
		return records.slice(records.size() - limit, records.size())
	return records


func rewrite_json_lines(file_path: String, records: Array) -> bool:
	if not _ensure_parent_dir(file_path):
		return false
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	for record_variant: Variant in records:
		if record_variant is Dictionary:
			file.store_line(JSON.stringify(record_variant))
	file.flush()
	return true


func truncate_file(file_path: String) -> bool:
	if not _ensure_parent_dir(file_path):
		return false
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		return false
	file.flush()
	return true


func get_file_size_bytes(file_path: String) -> int:
	if not FileAccess.file_exists(file_path):
		return 0
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return 0
	return file.get_length()


func file_exists(file_path: String) -> bool:
	return FileAccess.file_exists(file_path)


func _ensure_parent_dir(file_path: String) -> bool:
	var parent_dir: String = file_path.get_base_dir()
	if parent_dir.is_empty():
		return false
	var error: Error = DirAccess.make_dir_recursive_absolute(parent_dir)
	return error == OK or error == ERR_ALREADY_EXISTS
