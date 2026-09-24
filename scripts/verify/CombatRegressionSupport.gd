extends RefCounted
## Allow the audio server to release queued OGG playback references before test exit.
static func finish(tree: SceneTree, exit_code: int) -> void:
	AudioManager.queue_free()
	await tree.create_timer(0.2).timeout
	tree.quit(exit_code)
