extends SceneTree
## Writes the Godot Engine license and third-party notices shipped inside every export (MIT requires them).
## godot --headless --path . --script res://tests/dump_licenses.gd -- <out_dir>

func _init() -> void:
	var out := OS.get_cmdline_user_args()[0] if OS.get_cmdline_user_args().size() > 0 else "builds"
	var f := FileAccess.open(out.path_join("GODOT_LICENSE.txt"), FileAccess.WRITE)
	f.store_string("Godot Engine %s\n\n%s\n" % [Engine.get_version_info().string, Engine.get_license_text()])
	f.close()
	var t := FileAccess.open(out.path_join("GODOT_THIRDPARTY.txt"), FileAccess.WRITE)
	for c in Engine.get_copyright_info():
		t.store_string("== %s\n" % c.name)
		for p in c.parts:
			t.store_string("   files: %s\n   copyright: %s\n   license: %s\n" % [", ".join(p.files), "; ".join(p.copyright), p.license])
	var lic := Engine.get_license_info()
	for k in lic:
		t.store_string("\n---- %s ----\n%s\n" % [k, lic[k]])
	t.close()
	print("wrote ", out)
	quit()
