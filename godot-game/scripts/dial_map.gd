class_name DialMap
extends RefCounted

## Pure helpers for turning input into an absolute dial value (0..1) and then
## into a paddle Y position. Real potentiometers give an absolute 0..1 directly;
## the keyboard integrates a held key into the same 0..1 space so game logic is
## source-agnostic. Convention: value 0 = top of pitch, 1 = bottom.

## Integrate a held up/down key into the virtual dial value.
## up moves toward 0 (top), down moves toward 1 (bottom).
static func integrate_key(current: float, up: bool, down: bool, delta: float, speed: float) -> float:
	var dir := 0.0
	if up:
		dir -= 1.0
	if down:
		dir += 1.0
	return clampf(current + dir * speed * delta, 0.0, 1.0)

## Map a dial value (0..1) to a paddle center Y, given the travel range the
## paddle center may occupy (top_y at value 0, bottom_y at value 1).
static func dial_to_y(value: float, top_y: float, bottom_y: float) -> float:
	return lerpf(top_y, bottom_y, clampf(value, 0.0, 1.0))

## True if the dial moved more than the deadband since the last reading
## (used to detect player activity for attract/abandon transitions).
static func has_activity(prev: float, curr: float, deadband: float) -> bool:
	return absf(curr - prev) > deadband
