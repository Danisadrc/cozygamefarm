extends AnimatedSprite2D
## Builds a looping SpriteFrames animation from a horizontal sprite strip.
##
## The Sunnyside decor sheets store one animation per file, laid out left to
## right with no padding, so a single script drives the windmill, the chickens,
## the ducks, and anything else that needs to move.

@export var sheet: Texture2D
@export var frame_count: int = 4
@export var fps: float = 8.0
@export var frame_size: Vector2i = Vector2i.ZERO
@export var start_frame: int = 0


func _ready() -> void:
	if sheet == null:
		return
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("loop")
	sf.set_animation_speed("loop", fps)
	sf.set_animation_loop("loop", true)

	var fw: int = frame_size.x if frame_size.x > 0 else sheet.get_width() / frame_count
	var fh: int = frame_size.y if frame_size.y > 0 else sheet.get_height()
	for i in frame_count:
		var at := AtlasTexture.new()
		at.atlas = sheet
		at.region = Rect2(i * fw, 0, fw, fh)
		sf.add_frame("loop", at)

	sprite_frames = sf
	frame = start_frame % maxi(frame_count, 1)
	play("loop")
