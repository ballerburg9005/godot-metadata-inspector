Metadata-Inspector
==================

This Godot 3.2 Plugin allows you to view and edit hidden Metadata.

You can use this most effectively to add custom variables to any node you want without using or attaching any scripts.


[![demo1](/demo1.jpg)](#)

INSTALL
-------

1. Download into folder [urproject]/addons/
2. Go Project -> Project Settings -> Plugins and activate Metadata Inspector

TODO
----
- right click key -> move entry up/down
- doesn't trigger a "really quit changes will be lost" 
- (undo / redo)
- val2str for color is ugly 1,1,1,1 should be #FFFFFFF and tuples have brackets sometimes ()
- restore cursor position to new entry field after pressing enter
- maxentry limit = 60?

BUGS
----
- vbox suddenly disappeared for seriously no reason and totally impossible by code 2020-05-15
