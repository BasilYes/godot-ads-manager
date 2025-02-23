class_name AMFakeAd
extends CanvasLayer


var rewarded: bool = false
var impressed: bool = false

func run(rewarded: bool) -> void:
	self.rewarded = rewarded
	if rewarded:
		AdsManager.rewarded_ad_show_result.emit(true)
	else:
		AdsManager.interstitial_ad_show_result.emit(true)


func _on_close_button_pressed() -> void:
	if rewarded:
		if not impressed:
			AdsManager.rewarded_ad_impression_result.emit(false)
		AdsManager.rewarded_ad_closed.emit(true)
	else:
		AdsManager.interstitial_ad_closed.emit()
	queue_free()


func _on_impression_button_pressed() -> void:
	if rewarded:
		impressed = true
		AdsManager.rewarded_ad_impression_result.emit(true)
