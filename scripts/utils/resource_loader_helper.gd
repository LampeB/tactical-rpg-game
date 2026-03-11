extends RefCounted
## Shared helper for loading .tres resources from directories.
## Used by all database autoloads to eliminate boilerplate.


## Loads all .tres files from a directory into a dictionary keyed by resource.id.
## Auto-fills id from filename if empty. Logs warnings for duplicates and failures.
static func load_dir(
	dir_path: String,
	logger_name: String = "ResourceLoader",
	cache_mode: ResourceLoader.CacheMode = ResourceLoader.CACHE_MODE_IGNORE
) -> Dictionary:
	var result: Dictionary = {}
	var dir := DirAccess.open(dir_path)
	if not dir:
		push_warning("[%s] Directory not found: %s" % [logger_name, dir_path])
		return result

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := dir_path + file_name
			var res: Resource = ResourceLoader.load(full_path, "", cache_mode)
			if res and "id" in res:
				if res.id.is_empty():
					res.id = file_name.get_basename()
				if result.has(res.id):
					push_warning("[%s] Duplicate ID: %s in %s" % [logger_name, res.id, full_path])
				result[res.id] = res
			elif not res:
				push_warning("[%s] Failed to load: %s" % [logger_name, full_path])
		file_name = dir.get_next()
	dir.list_dir_end()
	return result


## Loads .tres files from multiple directories and merges them.
static func load_dirs(
	dir_paths: Array[String],
	logger_name: String = "ResourceLoader",
	cache_mode: ResourceLoader.CacheMode = ResourceLoader.CACHE_MODE_IGNORE
) -> Dictionary:
	var result: Dictionary = {}
	for dir_path in dir_paths:
		result.merge(load_dir(dir_path, logger_name, cache_mode))
	return result
