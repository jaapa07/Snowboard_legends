class_name HumanProvider
extends RefCounted
## Reads the assigned local device each physics frame.

var device: String = "kb"
var _cmd := InputCommand.new()

func _init(dev: String) -> void:
	device = dev

func command(_r: RiderController, _delta: float) -> InputCommand:
	Inputs.read(device, _cmd)
	return _cmd
