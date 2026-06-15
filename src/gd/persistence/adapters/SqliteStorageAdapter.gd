extends "res://src/gd/persistence/adapters/StorageAdapter.gd"

const SQLITE_DB_FILE_PATH: String = "user://save/harmonia.db"
const JSON_MIRROR_ADAPTER_SCRIPT_PATH: String = "res://src/gd/persistence/adapters/JsonFileStorageAdapter.gd"
const SQLITE_CLASS_NAME: String = "SQLite"
const SQLITE_CSHARP_SCRIPT_PATH: String = "res://src/csharp/Infrastructure/SQLite.cs"
const TABLE_DOCUMENTS: String = "save_documents"
const TABLE_JSON_LINES: String = "save_json_lines"

var _sqlite: Object = null
var _open_attempted: bool = false
var _unavailable_reason: String = ""
var _last_runtime_error: String = ""
var _json_mirror_adapter: RefCounted = null


func _init() -> void:
	_json_mirror_adapter = _create_json_mirror_adapter()


func get_adapter_id() -> String:
	return "sqlite_scaffold"


func is_available() -> bool:
	return _ensure_open()


func get_unavailable_reason() -> String:
	if _ensure_open():
		return ""
	if not _last_runtime_error.is_empty():
		return _last_runtime_error
	if _unavailable_reason.is_empty():
		return "SQLite adapter unavailable."
	return _unavailable_reason


func write_json_document(file_path: String, payload: Dictionary, indent: String = "\t") -> bool:
	if payload.is_empty():
		return false
	if not _ensure_open():
		return false

	var payload_json: String = JSON.stringify(payload)
	var now_unix_sec: int = int(Time.get_unix_time_from_system())
	var sql: String = "INSERT OR REPLACE INTO %s (path, payload_json, updated_unix_sec) VALUES (%s, %s, %d);" % [
		TABLE_DOCUMENTS,
		_sql_quote(file_path),
		_sql_quote(payload_json),
		now_unix_sec
	]
	if not _exec_sql(sql):
		return false
	return _mirror_write_json_document(file_path, payload, indent)


func read_json_document(file_path: String) -> Dictionary:
	if not _ensure_open():
		return {
			"ok": false,
			"data": {},
			"error": get_unavailable_reason()
		}

	var rows: Array = _fetch_rows(
		"SELECT payload_json FROM %s WHERE path = %s LIMIT 1;" % [
			TABLE_DOCUMENTS,
			_sql_quote(file_path)
		]
	)
	if not rows.is_empty():
		var payload_json: String = _extract_row_value(rows[0] as Dictionary, PackedStringArray(["payload_json"]))
		if payload_json.is_empty():
			return {
				"ok": false,
				"data": {},
				"error": "SQLite returned an empty payload_json column."
			}
		var json: JSON = JSON.new()
		if json.parse(payload_json) != OK or typeof(json.data) != TYPE_DICTIONARY:
			return {
				"ok": false,
				"data": {},
				"error": "SQLite payload JSON parse failed."
			}
		return {
			"ok": true,
			"data": json.data as Dictionary,
			"error": ""
		}

	var mirror_result: Dictionary = _mirror_read_json_document(file_path)
	if bool(mirror_result.get("ok", false)):
		var mirror_data: Dictionary = mirror_result.get("data", {}) as Dictionary
		write_json_document(file_path, mirror_data)
		return mirror_result

	return {
		"ok": false,
		"data": {},
		"error": "Document not found in SQLite or JSON mirror."
	}


func append_json_line(file_path: String, payload: Dictionary) -> bool:
	if payload.is_empty():
		return false
	if not _ensure_open():
		return false

	var payload_json: String = JSON.stringify(payload)
	var now_unix_sec: int = int(Time.get_unix_time_from_system())
	var insert_sql: String = "INSERT INTO %s (stream_path, row_order, payload_json, created_unix_sec) SELECT %s, COALESCE(MAX(row_order), 0) + 1, %s, %d FROM %s WHERE stream_path = %s;" % [
		TABLE_JSON_LINES,
		_sql_quote(file_path),
		_sql_quote(payload_json),
		now_unix_sec,
		TABLE_JSON_LINES,
		_sql_quote(file_path)
	]
	if not _exec_sql(insert_sql):
		return false
	return _mirror_append_json_line(file_path, payload)


func read_json_lines(file_path: String, limit: int = 0) -> Array:
	if not _ensure_open():
		return []

	var rows: Array = _fetch_rows(
		"SELECT payload_json FROM %s WHERE stream_path = %s ORDER BY row_order ASC;" % [
			TABLE_JSON_LINES,
			_sql_quote(file_path)
		]
	)
	var records: Array = []
	for row_variant: Variant in rows:
		if not (row_variant is Dictionary):
			continue
		var payload_json: String = _extract_row_value(row_variant as Dictionary, PackedStringArray(["payload_json"]))
		if payload_json.is_empty():
			continue
		var json: JSON = JSON.new()
		if json.parse(payload_json) != OK:
			continue
		if typeof(json.data) != TYPE_DICTIONARY:
			continue
		records.append(json.data as Dictionary)

	if records.is_empty():
		var mirror_records: Array = _mirror_read_json_lines(file_path, 0)
		if not mirror_records.is_empty():
			rewrite_json_lines(file_path, mirror_records)
			records = mirror_records

	if limit > 0 and records.size() > limit:
		return records.slice(records.size() - limit, records.size())
	return records


func rewrite_json_lines(file_path: String, records: Array) -> bool:
	if not _ensure_open():
		return false
	if not _exec_sql("BEGIN TRANSACTION;"):
		return false

	var delete_ok: bool = _exec_sql(
		"DELETE FROM %s WHERE stream_path = %s;" % [
			TABLE_JSON_LINES,
			_sql_quote(file_path)
		]
	)
	if not delete_ok:
		_exec_sql("ROLLBACK;")
		return false

	var row_order: int = 1
	for record_variant: Variant in records:
		if not (record_variant is Dictionary):
			continue
		var payload_json: String = JSON.stringify(record_variant as Dictionary)
		var insert_ok: bool = _exec_sql(
			"INSERT INTO %s (stream_path, row_order, payload_json, created_unix_sec) VALUES (%s, %d, %s, %d);" % [
				TABLE_JSON_LINES,
				_sql_quote(file_path),
				row_order,
				_sql_quote(payload_json),
				int(Time.get_unix_time_from_system())
			]
		)
		if not insert_ok:
			_exec_sql("ROLLBACK;")
			return false
		row_order += 1

	if not _exec_sql("COMMIT;"):
		_exec_sql("ROLLBACK;")
		return false
	return _mirror_rewrite_json_lines(file_path, records)


func truncate_file(file_path: String) -> bool:
	if not _ensure_open():
		return false

	var clear_document_ok: bool = _exec_sql(
		"DELETE FROM %s WHERE path = %s;" % [
			TABLE_DOCUMENTS,
			_sql_quote(file_path)
		]
	)
	var clear_lines_ok: bool = _exec_sql(
		"DELETE FROM %s WHERE stream_path = %s;" % [
			TABLE_JSON_LINES,
			_sql_quote(file_path)
		]
	)
	var mirror_ok: bool = _mirror_truncate_file(file_path)
	return clear_document_ok and clear_lines_ok and mirror_ok


func get_file_size_bytes(file_path: String) -> int:
	if not _ensure_open():
		return _mirror_get_file_size_bytes(file_path)

	if file_path.ends_with(".jsonl"):
		return _get_jsonl_size_bytes(file_path)

	var rows: Array = _fetch_rows(
		"SELECT payload_json FROM %s WHERE path = %s LIMIT 1;" % [
			TABLE_DOCUMENTS,
			_sql_quote(file_path)
		]
	)
	if rows.is_empty():
		return _mirror_get_file_size_bytes(file_path)
	var payload_json: String = _extract_row_value(rows[0] as Dictionary, PackedStringArray(["payload_json"]))
	if payload_json.is_empty():
		return _mirror_get_file_size_bytes(file_path)
	return payload_json.to_utf8_buffer().size()


func file_exists(file_path: String) -> bool:
	if not _ensure_open():
		return _mirror_file_exists(file_path)

	if file_path.ends_with(".jsonl"):
		var stream_rows: Array = _fetch_rows(
			"SELECT 1 AS has_row FROM %s WHERE stream_path = %s LIMIT 1;" % [
				TABLE_JSON_LINES,
				_sql_quote(file_path)
			]
		)
		if not stream_rows.is_empty():
			return true
		return _mirror_file_exists(file_path)

	var document_rows: Array = _fetch_rows(
		"SELECT path FROM %s WHERE path = %s LIMIT 1;" % [
			TABLE_DOCUMENTS,
			_sql_quote(file_path)
		]
	)
	if not document_rows.is_empty():
		return true
	return _mirror_file_exists(file_path)


func _ensure_open() -> bool:
	if _sqlite != null:
		return true
	if _open_attempted:
		return false

	_open_attempted = true
	var sqlite_instance: Object = _create_sqlite_runtime_instance()
	if sqlite_instance == null:
		_unavailable_reason = "Failed to resolve SQLite runtime class. Ensure C# assembly is loaded for %s." % SQLITE_CSHARP_SCRIPT_PATH
		return false

	if not _ensure_db_parent_dir():
		_unavailable_reason = "Failed to create parent directory for SQLite database."
		return false

	_configure_sqlite_path(sqlite_instance)
	if not _open_sqlite_connection(sqlite_instance):
		_unavailable_reason = "Failed to open SQLite database connection."
		return false
	if not _ensure_schema(sqlite_instance):
		_unavailable_reason = "Failed to initialize SQLite schema."
		return false

	_sqlite = sqlite_instance
	_unavailable_reason = ""
	return true


func _create_sqlite_runtime_instance() -> Object:
	if ClassDB.class_exists(SQLITE_CLASS_NAME):
		var classdb_instance: Object = ClassDB.instantiate(SQLITE_CLASS_NAME)
		if classdb_instance != null:
			return classdb_instance

	var sqlite_script: Script = load(SQLITE_CSHARP_SCRIPT_PATH)
	if sqlite_script == null:
		return null
	var script_instance: Variant = sqlite_script.new()
	if script_instance is Object:
		return script_instance as Object
	return null


func _ensure_db_parent_dir() -> bool:
	var parent_dir: String = SQLITE_DB_FILE_PATH.get_base_dir()
	if parent_dir.is_empty():
		return false
	var error: Error = DirAccess.make_dir_recursive_absolute(parent_dir)
	return error == OK or error == ERR_ALREADY_EXISTS


func _configure_sqlite_path(sqlite_instance: Object) -> void:
	if sqlite_instance.has_method("set_path"):
		sqlite_instance.call("set_path", SQLITE_DB_FILE_PATH)
	elif _has_property(sqlite_instance, "path"):
		sqlite_instance.set("path", SQLITE_DB_FILE_PATH)

	if _has_property(sqlite_instance, "read_only"):
		sqlite_instance.set("read_only", false)


func _open_sqlite_connection(sqlite_instance: Object) -> bool:
	if sqlite_instance.has_method("open_db"):
		return _is_success_result(sqlite_instance.call("open_db"), true)

	if sqlite_instance.has_method("open"):
		var open_arg_count: int = _get_method_arg_count(sqlite_instance, "open")
		if open_arg_count <= 0:
			return _is_success_result(sqlite_instance.call("open"), true)
		return _is_success_result(sqlite_instance.call("open", SQLITE_DB_FILE_PATH), true)

	if sqlite_instance.has_method("open_database"):
		return _is_success_result(sqlite_instance.call("open_database", SQLITE_DB_FILE_PATH), true)

	return false


func _ensure_schema(sqlite_instance: Object) -> bool:
	var create_documents_ok: bool = _exec_sql_with_target(sqlite_instance, "CREATE TABLE IF NOT EXISTS %s (path TEXT PRIMARY KEY, payload_json TEXT NOT NULL, updated_unix_sec INTEGER NOT NULL);" % TABLE_DOCUMENTS)
	if not create_documents_ok:
		return false
	var create_lines_ok: bool = _exec_sql_with_target(sqlite_instance, "CREATE TABLE IF NOT EXISTS %s (stream_path TEXT NOT NULL, row_order INTEGER NOT NULL, payload_json TEXT NOT NULL, created_unix_sec INTEGER NOT NULL, PRIMARY KEY(stream_path, row_order));" % TABLE_JSON_LINES)
	if not create_lines_ok:
		return false
	var create_index_ok: bool = _exec_sql_with_target(sqlite_instance, "CREATE INDEX IF NOT EXISTS idx_%s_stream ON %s (stream_path, row_order);" % [TABLE_JSON_LINES, TABLE_JSON_LINES])
	return create_index_ok


func _next_json_line_row_order(file_path: String) -> int:
	var rows: Array = _fetch_rows(
		"SELECT COALESCE(MAX(row_order), 0) + 1 AS next_row_order FROM %s WHERE stream_path = %s;" % [
			TABLE_JSON_LINES,
			_sql_quote(file_path)
		]
	)
	if rows.is_empty():
		return 1
	return max(int(_extract_row_value(rows[0] as Dictionary, PackedStringArray(["next_row_order"]))), 1)


func _get_jsonl_size_bytes(file_path: String) -> int:
	var rows: Array = _fetch_rows(
		"SELECT payload_json FROM %s WHERE stream_path = %s ORDER BY row_order ASC;" % [
			TABLE_JSON_LINES,
			_sql_quote(file_path)
		]
	)
	if rows.is_empty():
		return _mirror_get_file_size_bytes(file_path)

	var total_bytes: int = 0
	for row_variant: Variant in rows:
		if not (row_variant is Dictionary):
			continue
		var payload_json: String = _extract_row_value(row_variant as Dictionary, PackedStringArray(["payload_json"]))
		total_bytes += payload_json.to_utf8_buffer().size()
		total_bytes += 1
	return total_bytes


func _fetch_rows(sql: String) -> Array:
	if not _exec_sql(sql):
		return []
	if _sqlite == null:
		return []

	if _sqlite.has_method("get_query_result"):
		return _normalize_query_rows(_sqlite.call("get_query_result"))
	if _sqlite.has_method("query_result"):
		return _normalize_query_rows(_sqlite.call("query_result"))
	if _has_property(_sqlite, "query_result"):
		return _normalize_query_rows(_sqlite.get("query_result"))
	if _has_property(_sqlite, "last_query_result"):
		return _normalize_query_rows(_sqlite.get("last_query_result"))
	return []


func _normalize_query_rows(raw_rows: Variant) -> Array:
	var rows: Array = []
	if raw_rows is Array:
		for row_variant: Variant in raw_rows:
			if row_variant is Dictionary:
				rows.append(row_variant as Dictionary)
			elif row_variant is Array:
				var row_array: Array = row_variant as Array
				var row_dict: Dictionary = {}
				for index: int in range(row_array.size()):
					row_dict["col_%d" % index] = row_array[index]
				rows.append(row_dict)
		return rows
	if raw_rows is Dictionary:
		rows.append(raw_rows as Dictionary)
	return rows


func _extract_row_value(row: Dictionary, preferred_keys: PackedStringArray) -> String:
	for preferred_key: String in preferred_keys:
		if row.has(preferred_key):
			return str(row.get(preferred_key, ""))

	for row_key_variant: Variant in row.keys():
		var row_key: String = str(row_key_variant)
		for preferred_key: String in preferred_keys:
			if row_key.to_lower() == preferred_key.to_lower():
				return str(row.get(row_key_variant, ""))

	if not row.is_empty():
		return str(row.values()[0])
	return ""


func _exec_sql(sql: String) -> bool:
	if _sqlite == null:
		return false
	return _exec_sql_with_target(_sqlite, sql)


func _exec_sql_with_target(sqlite_target: Object, sql: String) -> bool:
	if sqlite_target == null:
		return false
	_last_runtime_error = ""

	if sqlite_target.has_method("query_with_bindings"):
		var query_with_bindings_result: bool = _is_success_result(sqlite_target.call("query_with_bindings", sql, []), true)
		if not query_with_bindings_result:
			_capture_runtime_error(sqlite_target, sql)
		return query_with_bindings_result

	if sqlite_target.has_method("query"):
		var query_arg_count: int = _get_method_arg_count(sqlite_target, "query")
		if query_arg_count <= 1:
			var query_result_no_args: bool = _is_success_result(sqlite_target.call("query", sql), true)
			if not query_result_no_args:
				_capture_runtime_error(sqlite_target, sql)
			return query_result_no_args
		var query_result_with_args: bool = _is_success_result(sqlite_target.call("query", sql, []), true)
		if not query_result_with_args:
			_capture_runtime_error(sqlite_target, sql)
		return query_result_with_args

	if sqlite_target.has_method("execute"):
		var execute_arg_count: int = _get_method_arg_count(sqlite_target, "execute")
		if execute_arg_count <= 1:
			var execute_result_no_args: bool = _is_success_result(sqlite_target.call("execute", sql), true)
			if not execute_result_no_args:
				_capture_runtime_error(sqlite_target, sql)
			return execute_result_no_args
		var execute_result_with_args: bool = _is_success_result(sqlite_target.call("execute", sql, []), true)
		if not execute_result_with_args:
			_capture_runtime_error(sqlite_target, sql)
		return execute_result_with_args

	return false


func _capture_runtime_error(sqlite_target: Object, sql: String) -> void:
	var bridge_error: String = ""
	if sqlite_target != null and sqlite_target.has_method("get_error_message"):
		bridge_error = str(sqlite_target.call("get_error_message"))
	var token: String = _sql_first_token(sql)
	if bridge_error.is_empty():
		_last_runtime_error = "SQLite runtime error during %s." % token
		return
	_last_runtime_error = "SQLite runtime error during %s: %s" % [token, bridge_error]


func _sql_first_token(sql: String) -> String:
	var trimmed: String = sql.strip_edges()
	if trimmed.is_empty():
		return "SQL"
	var parts: PackedStringArray = trimmed.split(" ", false, 1)
	if parts.is_empty():
		return "SQL"
	return str(parts[0]).to_upper()


func _is_success_result(value: Variant, treat_nil_as_success: bool) -> bool:
	match typeof(value):
		TYPE_NIL:
			return treat_nil_as_success
		TYPE_BOOL:
			return bool(value)
		TYPE_INT:
			var int_value: int = int(value)
			return int_value == OK or int_value == 1
		TYPE_FLOAT:
			return int(round(float(value))) == OK or int(round(float(value))) == 1
		_:
			return value != null


func _get_method_arg_count(target: Object, method_name: String) -> int:
	if target == null:
		return -1
	var methods: Array = target.get_method_list()
	for method_info_variant: Variant in methods:
		if not (method_info_variant is Dictionary):
			continue
		var method_info: Dictionary = method_info_variant as Dictionary
		if str(method_info.get("name", "")) != method_name:
			continue
		var args: Array = method_info.get("args", []) as Array
		return args.size()
	return -1


func _has_property(target: Object, property_name: String) -> bool:
	if target == null:
		return false
	var properties: Array = target.get_property_list()
	for property_info_variant: Variant in properties:
		if not (property_info_variant is Dictionary):
			continue
		var property_info: Dictionary = property_info_variant as Dictionary
		if str(property_info.get("name", "")) == property_name:
			return true
	return false


func _sql_quote(raw_text: String) -> String:
	return "'%s'" % raw_text.replace("'", "''")


func _create_json_mirror_adapter() -> RefCounted:
	var script: Script = load(JSON_MIRROR_ADAPTER_SCRIPT_PATH)
	if script == null:
		return null
	var instance: Variant = script.new()
	if instance is RefCounted:
		return instance as RefCounted
	return null


func _mirror_write_json_document(file_path: String, payload: Dictionary, indent: String) -> bool:
	if _json_mirror_adapter == null:
		return true
	if not _json_mirror_adapter.has_method("write_json_document"):
		return true
	return bool(_json_mirror_adapter.call("write_json_document", file_path, payload, indent))


func _mirror_read_json_document(file_path: String) -> Dictionary:
	if _json_mirror_adapter == null or not _json_mirror_adapter.has_method("read_json_document"):
		return {
			"ok": false,
			"data": {},
			"error": "JSON mirror adapter unavailable."
		}
	return _json_mirror_adapter.call("read_json_document", file_path) as Dictionary


func _mirror_append_json_line(file_path: String, payload: Dictionary) -> bool:
	if _json_mirror_adapter == null:
		return true
	if not _json_mirror_adapter.has_method("append_json_line"):
		return true
	return bool(_json_mirror_adapter.call("append_json_line", file_path, payload))


func _mirror_read_json_lines(file_path: String, limit: int) -> Array:
	if _json_mirror_adapter == null or not _json_mirror_adapter.has_method("read_json_lines"):
		return []
	return _json_mirror_adapter.call("read_json_lines", file_path, limit) as Array


func _mirror_rewrite_json_lines(file_path: String, records: Array) -> bool:
	if _json_mirror_adapter == null:
		return true
	if not _json_mirror_adapter.has_method("rewrite_json_lines"):
		return true
	return bool(_json_mirror_adapter.call("rewrite_json_lines", file_path, records))


func _mirror_truncate_file(file_path: String) -> bool:
	if _json_mirror_adapter == null:
		return true
	if not _json_mirror_adapter.has_method("truncate_file"):
		return true
	return bool(_json_mirror_adapter.call("truncate_file", file_path))


func _mirror_get_file_size_bytes(file_path: String) -> int:
	if _json_mirror_adapter == null or not _json_mirror_adapter.has_method("get_file_size_bytes"):
		return 0
	return int(_json_mirror_adapter.call("get_file_size_bytes", file_path))


func _mirror_file_exists(file_path: String) -> bool:
	if _json_mirror_adapter == null:
		return false
	if _json_mirror_adapter.has_method("file_exists"):
		return bool(_json_mirror_adapter.call("file_exists", file_path))
	return FileAccess.file_exists(file_path)
