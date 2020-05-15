tool
extends EditorPlugin

var IwantConfirmDialogues = true

var metapanel
var nonodelabel
var vbox
var plugin : EditorInspectorPlugin
var realtime_updater : Node

var is_metadata_inspector = false

var metavals = {}
var activenode = null

var l = TypeFormattingLogic.new()


func _enter_tree():
	while(destroy_old()):
		destroy_old()

		# this is a faux EditorInspectorPlugin, that just catches the node change
	plugin = preload("./CustomInspectorPlugin.gd").new()
	add_inspector_plugin(plugin)

	realtime_updater = preload("./RealtimeUpdater.gd").new()
	self.add_child(realtime_updater)
	

	metapanel = ScrollContainer.new()
	metapanel.name = "Meta"
	metapanel.size_flags_horizontal = metapanel.SIZE_EXPAND_FILL
	metapanel.size_flags_vertical = metapanel.SIZE_EXPAND_FILL

	vbox = VBoxContainer.new()
	vbox.size_flags_horizontal = vbox.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = vbox.SIZE_EXPAND_FILL
	#vbox.valign = vbox.VALIGN_TOP
	#vbox.align = vbox.ALIGN_BEGIN
	metapanel.add_child(vbox)

	nonodelabel = Label.new()
	nonodelabel.text="Select a single node to edit and view its metadata."
	nonodelabel.size_flags_vertical = Label.SIZE_EXPAND_FILL
	nonodelabel.size_flags_horizontal = Label.SIZE_EXPAND_FILL
	nonodelabel.valign = Label.VALIGN_CENTER
	nonodelabel.align = Label.ALIGN_CENTER
	nonodelabel.autowrap = true
	nonodelabel.set_custom_minimum_size(Vector2(100,0))
	metapanel.add_child(nonodelabel)

	add_control_to_dock(DOCK_SLOT_RIGHT_UL, metapanel)

	is_metadata_inspector = true


func update_node(n, act):
	#print("Updating: "+n.name)
#	n.set_meta("weirddata", {"Label": Label.new(), "Quat": Quat(1,1,1,1), "mykey3": "myval3"})
	#n.set_meta("nestedshit", ["array1", "array2", "array3", {"thisisdictkey1": "thisisdictval1", "thisisdictkey2": "thisisdictval2", "shit": [1,2,3,4,5]}])

	for oldentries in vbox.get_children():
		oldentries.call_deferred('free')

	if act == "load":
		metavals = {}
		activenode = n
		for key in n.get_meta_list():
			if typeof(key) == TYPE_STRING:
				metavals[key] = n.get_meta(key)
			else:
				print("Weird meta index, not string, ignoring: "+str(key))
	elif act == "save":
		for key in n.get_meta_list():
			if typeof(key) == TYPE_STRING:
				# Godot 3.1 has no remove_meta and uses null instead
				if n.has_method("remove_meta"):
					n.remove_meta(key)
				else:
					n.set_meta(key, null)
		for key in metavals:
			n.set_meta(key, metavals[key])

	for key in metavals:
		if n.has_method("remove_meta") or metavals[key] != null:
			ui_create_rows_recursively(metavals[key], key, vbox, TYPE_DICTIONARY)
	var dbox = ui_just_make_rootbox(vbox, "NEWENTRY")
	ui_create_row(dbox, "", "", true, [true, true])

	vbox.visible = true
	nonodelabel.visible = false


func delete_entry_from_ui_and_update(unused, obj):
	var rootbox = obj.get_parent().get_parent()
	var parent = rootbox.get_parent()

	var children = []
	for n in parent.get_children():
		children.push_back(n)
	
	parent.remove_child(rootbox)
	
	if update_all_from_ui(null):
		rootbox.queue_free()
	else:
		for n in parent.get_children():
			parent.remove_child(n)
		for n in children:
			parent.add_child(n)


func update_all_from_ui(unused):
	metavals = {}
		
	if update_from_textboxes_recursively(vbox, [[],[],[]]) == 0:
		update_node(activenode, "save")
		return true
	else:
		print("Unknown error while updating! (dup vals?)")
		return false


func update_from_textboxes_recursively(tbox, tpath):
	var failure = 0

	if tbox.is_class("Node"):
		
		# this looks sort of super stupid, but in order to re-count array positions from scratch there seems to be no other way
		var path = [[],[],[]]
		if tbox.name.substr(0,7) == "RootBox":
			path[0] = tpath[0] + [tbox.get_children()[0].get_node("./textbox_key").text]
			path[1] = tpath[1] + [typeof(tbox.get_children()[0].get_node("./textbox_val").get_meta("oval"))]
			path[2] = tpath[2] + [0]
			
			if path[0].size() > 1:
				if tpath[1][-1] == TYPE_ARRAY:
					path[0][-1] = tpath[2][-1]
				tpath[2][-1] += 1
		else:
			path = tpath
			
		for n in tbox.get_children():
			if n.has_node("./textbox_key"):
				if not update_from_textbox(n, path[0]):
					failure += 1
			failure += update_from_textboxes_recursively(n, path)
	return failure


func update_from_textbox(obj, tpath):

	var isnew = obj.get_node("./textbox_key").get_meta("isnew")

	var okey = obj.get_node("./textbox_key").get_meta("oval")
	var oval = obj.get_node("./textbox_val").get_meta("oval")

	var key = obj.get_node("./textbox_key").text
	var val = obj.get_node("./textbox_val").text

	var typ = null
	if obj.get_node("./textbox_val").has_meta("type"):
		typ = obj.get_node("./textbox_val").get_meta("type")

	var save_val	
	# TODO this only detects change correctly in the sense of val2str(str2val(x)) needs str(oval) replaced with custom function to allow for e.g. #FFFFFF to go back and forth
	if( (obj.get_node("./textbox_val").editable)
	and (typeof(oval) != typ or str(oval) != val)
	):
		if typ == null:
			typ = l.guess_my_type(val)

		var val0_err1 = l.custom_convert(val, typ)
		if val0_err1.size() > 1:
			ui_make_error_popup("Error in "+str(key)+" ! "+val0_err1[1])
			return false
		else:
			save_val = val0_err1[0]
	else:
		save_val = oval

	if typeof(oval) == TYPE_DICTIONARY:
		save_val = {}
	if typeof(oval) == TYPE_ARRAY:
		save_val = []
		
	if ( 	(isnew)
		and (val.length() == 0 or not obj.get_node("./textbox_val").editable)
		and (key.length() == 0 or not obj.get_node("./textbox_key").editable) 
		and (not obj.get_node("./textbox_val").has_meta("type"))
		): 
		return true

	return store_in_meta_dict_recursively(metavals, [] + tpath, key, save_val)
	
	
#	recurse(obj.get_parent().get_parent(), "")
#func recurse(obj, level):
#	if obj.name == "textbox_key":
#		print(level+obj.name+" : "+obj.text)
#	else:
#		print(level+obj.name)
#		
#	for n in obj.get_children():
#		recurse(n, level+"   ")


func store_in_meta_dict_recursively(tn, tpath, tkey, tval):
	if tpath.size() > 2:
		var cur = tpath.pop_front()
		return store_in_meta_dict_recursively(tn[cur], tpath, tkey, tval)
	elif  tpath.size() == 2:
#		print(tpath)
		if typeof(tn[tpath[0]]) == TYPE_ARRAY:
			tn[tpath[0]].push_back(tval)
			return true
		else:
			return store_in_meta_dict_if_no_dup(tn[tpath[0]], tkey, tval)
	elif tpath.size() < 2:
			return store_in_meta_dict_if_no_dup(tn, tkey, tval)


func store_in_meta_dict_if_no_dup(obj, tkey, tval):
	if not obj.has(tkey):
		obj[tkey] = tval
		return true
	else:
		ui_make_error_popup("Duplicate key \""+tkey+"\", not updating!")
		return false


func ui_make_error_popup(txt):
	var dia = AcceptDialog.new()
	dia.dialog_text = txt
	#reely.connect("confirmed", self, "delete_and_update_meta", [null, tpath])
	dia.connect("popup_hide", dia, "queue_free")
	activenode.get_tree().get_root().add_child(dia)
	dia.popup_centered()


func change_saved_type(ttype, obj):
	obj.set_meta("type", ttype)
	if not ttype in l.supported_type_names.keys():
		obj.editable = false

	ui_color_indicate_textbox(obj.text, obj)


func ui_color_indicate_textbox(txt, obj):
	if ( txt != str(obj.get_meta("oval"))
	or ( obj.has_meta("type") and obj.get_meta("type") != typeof(obj.get_meta("oval")) )):
		obj.modulate = Color(0.8,0.8,0.8)
		var dtype
		if obj.has_meta("type"):
			dtype = obj.get_meta("type")
		else:
			dtype = l.guess_my_type(txt)

		# this feature would need more work, kind of superflous anyway
		#if dtype in [TYPE_ARRAY, TYPE_DICTIONARY, TYPE_NIL]:
		#	obj.editable = false
			
		for n in obj.get_children():
			if n.is_class("Label") and n.name.substr(0,8) == "TYPEHINT":
				var conv
				var tryconv = l.custom_convert(txt, dtype)
				if tryconv.size() == 1:
					conv = tryconv[0]
				else:
					conv = ["ERR"]

				var dthint = l.get_typehint(conv)

				n.text = dthint[0]
				n.modulate = dthint[1]
				n.visible = true
	else:
		obj.modulate = Color(1,1,1)


func ui_context_menu(ev, obj, act):
	if (ev is InputEventMouseButton and ev.button_index == BUTTON_RIGHT) or (ev is InputEventKey and ev.scancode == KEY_MENU):
		if ev.pressed:
			var dbox = PopupMenu.new()
			obj.add_child(dbox)
			if ev is InputEventMouseButton:
				dbox.set_position(obj.get_global_transform().xform(obj.get_local_mouse_position()))
			else:
				dbox.set_position(obj.get_global_transform().origin+Vector2(10,10))
			dbox.set_size(Vector2(100,10))

			if act == "type":
				if not typeof(obj.get_meta("oval")) in l.supported_type_names.keys():
					dbox.add_item(l.all_type_names[typeof(obj.get_meta("oval"))], typeof(obj.get_meta("oval")))

				for i in l.supported_type_names.keys():
					dbox.add_item(l.supported_type_names[i], i)
					# TODO: nothing happens
				dbox.connect("id_pressed", self, "change_saved_type", [obj])
			elif act == "key":
				dbox.add_item("delete", 0)
				
				dbox.connect("id_pressed", self, "delete_entry_from_ui_and_update", [obj])
				
			dbox.popup()
			dbox.grab_focus()
		else:
			for n in obj.get_children():
				if n.is_class("PopupMenu"):
					n.queue_free()


func ui_resize_child_labels(tbox):
	for n in tbox.get_children():
		if n.is_class("Label"):
			n.set_size(tbox.get_size())


func ui_create_rows_recursively(tval, tkey, tbox, ttype):
	var box = ui_just_make_rootbox(tbox, tkey)
	
	var editables = [true, true]
	if ttype == TYPE_ARRAY:
		editables = [false, true]
		
	if typeof(tval) == TYPE_DICTIONARY:
		ui_create_row(box, tkey, tval, false, [editables[0], false])
		var dbox = ui_just_make_subboxes(box)
		for key in tval.keys():
			ui_create_rows_recursively(tval[key], key, dbox, typeof(tval))
		var ddbox = ui_just_make_rootbox(dbox, "NEWENTRY")
		ui_create_row(ddbox, "", "", true, [true, true])
	elif typeof(tval) == TYPE_ARRAY:
		ui_create_row(box, tkey, tval, false, [editables[0], false])
		var dbox = ui_just_make_subboxes(box)
		for i in range(0, tval.size()):
			ui_create_rows_recursively(tval[i], i, dbox, typeof(tval))
		var ddbox = ui_just_make_rootbox(dbox, "NEWENTRY")
		ui_create_row(ddbox, str(tval.size()), "", true, [false, true])
	else:
		ui_create_row(box, tkey, tval, false, editables)


func ui_create_row(box, tkey, tval, isnew, editables):

	var dbox = HBoxContainer.new()
	dbox.size_flags_horizontal = dbox.SIZE_EXPAND_FILL
	box.add_child(dbox)

	var textbox1 = LineEdit.new()
	textbox1.name = "textbox_key"
	textbox1.size_flags_horizontal = textbox1.SIZE_EXPAND_FILL
	textbox1.editable = editables[0]
	textbox1.set_text(str(tkey))
	textbox1.set_meta("oval", tkey)
	textbox1.set_meta("isnew", isnew)
	textbox1.connect("resized", self, "ui_resize_child_labels", [textbox1])
	textbox1.connect("gui_input", self, "ui_context_menu", [textbox1, "key"])
	textbox1.context_menu_enabled = false
	
	dbox.add_child(textbox1)

	var collection_hint 
	var brackets = []
	
	if typeof(tval) == TYPE_DICTIONARY:
		brackets = ["{", "}"]
	elif typeof(tval) == TYPE_ARRAY:
		brackets = ["[", "]"]
	for i in range(0, brackets.size()):
		collection_hint = Label.new()
		collection_hint.text = brackets[i]
		if i == 0:
			collection_hint.align = Label.ALIGN_LEFT
		else:
			collection_hint.align = Label.ALIGN_RIGHT
		collection_hint.size_flags_horizontal = Label.SIZE_EXPAND_FILL
		textbox1.add_child(collection_hint)
		#typehint.set_size(Vector2(100,100))
		
	var textbox2 = LineEdit.new()
	textbox2.name = "textbox_val"
	textbox2.size_flags_horizontal = textbox2.SIZE_EXPAND_FILL
	textbox2.set_text(str(tval))
	textbox2.editable = editables[1]

	textbox2.set_meta("oval", tval)
	if not isnew:
		textbox2.set_meta("type", typeof(tval))

	if not typeof(tval) in l.supported_type_names.keys():
		textbox2.editable = false
	
	if typeof(tval) in [TYPE_DICTIONARY, TYPE_ARRAY]:
		textbox1.align = LineEdit.ALIGN_CENTER
		textbox2.visible = false

	textbox2.connect("resized", self, "ui_resize_child_labels", [textbox2])
	textbox2.connect("gui_input", self, "ui_context_menu", [textbox2, "type"])
	textbox2.context_menu_enabled = false
	dbox.add_child(textbox2)

	var typehint = Label.new()
	typehint.name = "TYPEHINT"
	typehint.text = l.get_typehint(tval)[0]
	typehint.modulate = l.get_typehint(tval)[1]
	typehint.align = Label.ALIGN_RIGHT
	typehint.size_flags_horizontal = Label.SIZE_EXPAND_FILL
	#typehint.set_size(Vector2(100,100))
	typehint.visible = true
	if isnew:
		typehint.visible = false
	textbox2.add_child(typehint)

	textbox1.connect("text_changed", self, "ui_color_indicate_textbox", [textbox1])
	textbox1.connect("text_entered", self, "update_all_from_ui")
	textbox2.connect("text_changed", self, "ui_color_indicate_textbox", [textbox2])
	textbox2.connect("text_entered", self, "update_all_from_ui")


func ui_just_make_rootbox(tbox, name):
	var box = VBoxContainer.new()
	box.name = "RootBox-"+str(name)
	box.size_flags_horizontal = box.SIZE_EXPAND_FILL
	tbox.add_child(box)
	return box
	
	
func ui_just_make_subboxes(tbox):
	var dbox = HBoxContainer.new()
	dbox.size_flags_horizontal = dbox.SIZE_EXPAND_FILL
	tbox.add_child(dbox)
	var ddbox1 = Panel.new()
	ddbox1.set_custom_minimum_size(Vector2(1,0))
	dbox.add_child(ddbox1)
	var ddbox2 = VBoxContainer.new()
	ddbox2.size_flags_horizontal = ddbox2.SIZE_EXPAND_FILL
	dbox.add_child(ddbox2)

	return ddbox2


func set_node_not_editable():
	vbox.visible = false
	nonodelabel.visible = true


func _exit_tree():
	destroy_old()


func destroy_old():
	for n in get_parent().get_children():
		if n.name.substr(0, 12) == "EditorPlugin" and n.get("is_metadata_inspector") == true:
			remove_inspector_plugin(n.plugin)
			remove_control_from_docks(n.metapanel)
			n.call_deferred('free')


func get_plugin_name():
	return "Metadata Inspector"


#func get_plugin_icon():
   #return get_editor_interface().get_base_control().get_icon("Node", "EditorIcons")



# this function is no longer used
#func ui_adddel_button_pressed(button, tpath):
#	if button.text == "+":
#		update_all_from_ui(null)			# TODO: + button, same as ENTER, no specific function?
#	elif button.text == "-":
#		button.set_meta("delete") == true
#		update_all_from_ui(null)
#	else:
#		if IwantConfirmDialogues == true:
#			var reely = ConfirmationDialog.new()
#			reely.dialog_text = "Really delete "+button.text+"?"
#			reely.connect("confirmed", self, "update_all_from_ui")
#			reely.connect("popup_hide", reely, "queue_free")
#			button.get_tree().get_root().add_child(reely)
#			reely.popup_centered()
#		else:
#			update_all_from_ui(null)
