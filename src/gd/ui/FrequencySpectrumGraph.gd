extends Control

## Custom-draw frequency-spectrum graph for the practice frequency meter.
## Renders a row of vertical bars representing the magnitude of each band
## emitted by AudioProcessor.spectrum_bins_updated, with a target-marker
## line at the center frequency and a needle indicating the live detected
## pitch offset (cents) from the target.
##
## Bands are received as PackedVector2Array: x = band center Hz, y = normalized
## magnitude (0..1). The band whose center is closest to the meter center is
## treated as the target band and gets a gold marker; adjacent bands show
## harmonics/neighbors for at-a-glance tuning context.

const COLOR_BG: Color = Color(0.06, 0.05, 0.11, 1.0)
const COLOR_BAR: Color = Color(0.45, 0.55, 0.95, 0.85)
const COLOR_BAR_TARGET_BAND: Color = Color(0.85, 0.78, 0.32, 0.95)
const COLOR_CENTER_LINE: Color = Color(1.0, 0.84, 0.40, 0.95)
const COLOR_NEEDLE: Color = Color(0.60, 1.0, 0.60, 1.0)
const COLOR_TEXT: Color = Color(0.95, 0.94, 0.86, 0.9)
const TEXT_PADDING: float = 4.0

# Latest bins received from AudioProcessor.spectrum_bins_updated.
var _bins: PackedVector2Array = PackedVector2Array()
# Meter center Hz (target frequency). Bars are spaced around this.
var _center_hz: float = 0.0
# Live detected frequency (Hz) for the needle; 0 = no signal.
var _detected_hz: float = 0.0
# Live cents offset (-50..+50) for the needle position.
var _cents_offset: float = 0.0
# Whether the meter should be dimmed (below noise floor / paused).
var _dimmed: bool = false
# Set true when the graph has received at least one non-empty bins frame.
var _has_data: bool = false


func _draw() -> void:
	var size_vec: Vector2 = get_size()
	if size_vec.x <= 1.0 or size_vec.y <= 1.0:
		return
	# Background.
	draw_rect(Rect2(Vector2.ZERO, size_vec), COLOR_BG, true)

	var alpha: float = 0.35 if _dimmed else 1.0
	var graph_height: float = size_vec.y - TEXT_PADDING
	var graph_rect: Rect2 = Rect2(Vector2.ZERO, Vector2(size_vec.x, graph_height))

	# Center target line (vertical, at the middle x).
	var center_x: float = size_vec.x * 0.5
	draw_line(
		Vector2(center_x, 0.0),
		Vector2(center_x, graph_height),
		Color(COLOR_CENTER_LINE.r, COLOR_CENTER_LINE.g, COLOR_CENTER_LINE.b, COLOR_CENTER_LINE.a * alpha),
		2.0
	)

	# Bars.
	if _has_data and not _bins.is_empty():
		var band_count: int = _bins.size()
		var band_width: float = size_vec.x / float(band_count)
		# Find the target band index (closest frequency to _center_hz).
		var target_band_index: int = _find_target_band_index()
		for i: int in range(band_count):
			var magnitude: float = float(_bins[i].y)
			# If a bin has a 0 Hz x (cleared frame from stop_capture), magnitude
			# is treated as 0 and we skip drawing a bar.
			if _bins[i].x <= 0.0:
				continue
			var bar_height: float = max(magnitude * graph_height, 2.0) * (alpha if _dimmed else 1.0)
			var bar_rect: Rect2 = Rect2(
				Vector2(float(i) * band_width + 1.0, graph_height - bar_height),
				Vector2(max(band_width - 2.0, 1.0), bar_height)
			)
			var bar_color: Color = COLOR_BAR_TARGET_BAND if i == target_band_index else COLOR_BAR
			bar_color.a = bar_color.a * alpha
			draw_rect(bar_rect, bar_color, true)

	# Needle (horizontal position = cent offset mapped across the bar area).
	# cents -50 -> left edge, 0 -> center, +50 -> right edge.
	if not _dimmed and _detected_hz > 0.0 and absf(_cents_offset) <= 60.0:
		var needle_t: float = clamp((_cents_offset + 50.0) / 100.0, 0.0, 1.0)
		var needle_x: float = needle_t * size_vec.x
		draw_line(
			Vector2(needle_x, 0.0),
			Vector2(needle_x, graph_height),
			COLOR_NEEDLE,
			2.0
		)

	# Bottom labels: -50¢ / 0 / +50¢.
	var label_color: Color = Color(COLOR_TEXT.r, COLOR_TEXT.g, COLOR_TEXT.b, COLOR_TEXT.a * alpha)
	draw_string(_label_font(), Vector2(2.0, size_vec.y - 1.0), "-50¢", HORIZONTAL_ALIGNMENT_LEFT, -1, _label_font_size())
	draw_string(_label_font(), Vector2(center_x - 6.0, size_vec.y - 1.0), "0¢", HORIZONTAL_ALIGNMENT_CENTER, -1, _label_font_size())
	draw_string(_label_font(), Vector2(size_vec.x - 26.0, size_vec.y - 1.0), "+50¢", HORIZONTAL_ALIGNMENT_RIGHT, -1, _label_font_size())


func set_bins(bins: PackedVector2Array, center_hz: float) -> void:
	_bins = bins
	_center_hz = center_hz
	_has_data = not bins.is_empty()
	# If all bins are zeroed (cleared frame), keep _has_data true but data is zero.
	if bins.is_empty():
		_has_data = false
	queue_redraw()


func set_needle(detected_hz: float, cents_offset: float) -> void:
	_detected_hz = maxf(detected_hz, 0.0)
	# Clamp for the needle position; larger absolute offsets pin to the edge.
	_cents_offset = clamp(cents_offset, -60.0, 60.0)
	queue_redraw()


func set_dimmed(dimmed: bool) -> void:
	_dimmed = bool(dimmed)
	queue_redraw()


func _find_target_band_index() -> int:
	if _center_hz <= 0.0 or _bins.is_empty():
		return -1
	var best_index: int = 0
	var best_distance: float = INF
	for i: int in range(_bins.size()):
		if _bins[i].x <= 0.0:
			continue
		var distance: float = absf(_bins[i].x - _center_hz)
		if distance < best_distance:
			best_distance = distance
			best_index = i
	return best_index


func _label_font() -> FontFile:
	return load("res://src/gd/assets/ui/fonts/PixeloidSans.ttf") as FontFile


func _label_font_size() -> int:
	return 10
