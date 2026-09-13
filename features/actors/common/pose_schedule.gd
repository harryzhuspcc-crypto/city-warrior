class_name PoseSchedule
extends RefCounted

## Maps an elapsed logical frame onto an authored pose index using a sorted
## list of pose start frames. Presentation reads the schedule; gameplay
## components remain the timing authority.
static func pose_index(frame: int, frame_starts: PackedInt32Array, frame_count: int) -> int:
	var result: int = 0
	for frame_index: int in range(frame_starts.size()):
		if frame < frame_starts[frame_index]:
			break
		result = frame_index
	return clampi(result, 0, maxi(frame_count - 1, 0))
