tool
extends EditorInspectorPlugin


# this faux EditorInspectorPlugin is necessary to update the real EditorPlugin at the right time
func can_handle(object):
	if object.is_class("Node"):
		for n0 in object.get_tree().get_root().get_children():
			for n1 in n0.get_children():
				if n1.is_class("EditorPlugin"):
					if "is_metadata_inspector" in n1:
						n1.update_node(object, ["load"], {}, [[], "new"])
	return false
