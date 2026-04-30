extends GutTest
## Resource integrity test — load every .tres under data/ and verify it
## resolves into a valid Resource. Catches: renamed scripts, broken
## ext_resource paths, missing referenced files, typos in script_class.
##
## Would have caught: the sword_iron.tres → sword_common.tres rename bug
## (loot_example_drops referenced a non-existent file).

const DATA_DIR := "res://data/"


func test_all_data_tres_files_load() -> void:
	var failures: Array = []
	_collect_failures(DATA_DIR, failures)
	var msg: String = ""
	if not failures.is_empty():
		msg = "Resource integrity failures:\n  - " + "\n  - ".join(failures)
	assert_eq(failures.size(), 0, msg)


func _collect_failures(dir_path: String, failures: Array) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		failures.append("Cannot open dir: %s" % dir_path)
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var full: String = dir_path + entry
		if dir.current_is_dir() and entry != "." and entry != "..":
			_collect_failures(full + "/", failures)
		elif entry.ends_with(".tres"):
			var resource: Resource = load(full)
			if not resource:
				failures.append("Failed to load: %s" % full)
		entry = dir.get_next()
	dir.list_dir_end()
