class_name RiderTuning
extends Resource
## Every arcade physics value lives here (spec section 5: "todos os valores configuráveis").

@export var gravity: float = 16.0
@export var max_speed: float = 24.0
@export var tuck_speed: float = 29.0
@export var boost_speed: float = 35.0
@export var slope_accel_factor: float = 1.25
@export var push_accel: float = 7.0
@export var push_until: float = 7.0
@export var drag_k: float = 0.0042
@export var tuck_drag_mult: float = 0.55
@export var rolling: float = 0.35
@export var brake_decel: float = 11.0
@export var overspeed_decel: float = 9.0
@export var turn_rate_low: float = 2.5
@export var turn_rate_high: float = 1.35
@export var turn_response: float = 9.0
@export var brake_turn_mult: float = 1.35
@export var tuck_turn_mult: float = 0.65
@export var lateral_grip: float = 34.0
@export var ice_grip: float = 6.0
@export var spinout_grip: float = 2.0
@export var carve_speed_cost: float = 0.035
@export var air_steer: float = 0.9
@export var jump_charge_max: float = 0.65
@export var jump_min: float = 4.0
@export var jump_max: float = 8.0
@export var coyote_time: float = 0.10
@export var jump_buffer: float = 0.12
@export var spin_rate_deg: float = 620.0
@export var flip_rate_deg: float = 520.0
@export var land_clean_deg: float = 30.0
@export var land_perfect_deg: float = 12.0
@export var land_sloppy_deg: float = 60.0
@export var sloppy_speed_mult: float = 0.7
@export var fall_min: float = 0.8
@export var fall_max: float = 1.4
@export var offtrack_reset_time: float = 2.0
@export var reset_penalty: float = 2.0
@export var grind_min_speed: float = 12.0
@export var ground_stick: float = 1.2
