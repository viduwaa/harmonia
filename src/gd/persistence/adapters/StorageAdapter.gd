extends RefCounted


func get_adapter_id() -> String:
	return "base"


func is_available() -> bool:
	return false


func get_unavailable_reason() -> String:
	return "Storage adapter is abstract."


func write_json_document(_file_path: String, _payload: Dictionary, _indent: String = "\t") -> bool:
	return false


func read_json_document(_file_path: String) -> Dictionary:
	return {
		"ok": false,
		"data": {},
		"error": "Storage adapter is abstract."
	}


func append_json_line(_file_path: String, _payload: Dictionary) -> bool:
	return false


func read_json_lines(_file_path: String, _limit: int = 0) -> Array:
	return []


func rewrite_json_lines(_file_path: String, _records: Array) -> bool:
	return false


func truncate_file(_file_path: String) -> bool:
	return false


func get_file_size_bytes(_file_path: String) -> int:
	return 0
