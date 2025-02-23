extends Node


enum AdProvider {
	NO_ADS,
	FAKE_ADS,
	YANDEX_MOBILE,
	YANDEX_GAMES
}


signal interstitial_ad_clicked()
signal interstitial_ad_show_result(result: bool)
signal interstitial_ad_closed()

signal rewarded_ad_clicked()
signal rewarded_ad_show_result(result: bool)
signal rewarded_ad_impression_result(rewarded: bool)
signal rewarded_ad_closed(rewarded: bool)


var _ad_provider: AdProvider = AdProvider.NO_ADS
var _ad_singleton: Node = null
var _is_ad_processing: bool = false
var _rewarded: bool = false

func _ready() -> void:
	rewarded_ad_closed.connect(func(rewarded: bool) -> void:
			_mute_sound(false)
			_is_ad_processing = false
			_rewarded = false)
	interstitial_ad_closed.connect(func() -> void:
			_mute_sound(false)
			_is_ad_processing = false)
	if has_node("/root/YandexAds") and get_node("/root/YandexAds").is_working():
		_ad_provider = AdProvider.YANDEX_MOBILE
		_ad_singleton = get_node("/root/YandexAds")
		if not _ad_singleton.is_node_ready():
			await _ad_singleton.ready
		var _plugin_singleton: JNISingleton = _ad_singleton._plugin_singleton
		_plugin_singleton.interstitial_ad_shown.connect(
				func():
					interstitial_ad_show_result.emit(true))
		_plugin_singleton.interstitial_ad_failed_to_show.connect(
				func():
					interstitial_ad_show_result.emit(false))
		_plugin_singleton.interstitial_ad_dismissed.connect(
				func():
					interstitial_ad_closed.emit())
		_plugin_singleton.interstitial_ad_clicked.connect(
				func(): interstitial_ad_clicked.emit())

		_plugin_singleton.rewarded_ad_shown.connect(
				func():
					rewarded_ad_show_result.emit(true))
		_plugin_singleton.rewarded_ad_failed_to_show.connect(
				func():
					rewarded_ad_show_result.emit(false))
		_plugin_singleton.rewarded_ad_dismissed.connect(
				func():
					if not _rewarded:
						rewarded_ad_impression_result.emit(false)
					rewarded_ad_impression_result.emit(false))
		_plugin_singleton.rewarded_ad_rewarded.connect(
				func():
					_rewarded = true
					rewarded_ad_impression_result.emit(true))
		_plugin_singleton.rewarded_ad_clicked.connect(
				func(): rewarded_ad_clicked.emit())
	elif has_node("/root/YandexSDK") and get_node("/root/YandexSDK").is_working():
		_ad_provider = AdProvider.YANDEX_GAMES
		_ad_singleton = get_node("/root/YandexSDK")
		if not _ad_singleton.is_node_ready():
			await _ad_singleton.ready
		_ad_singleton.init_game()
		_ad_singleton.rewarded_ad.connect(func(result: String) -> void:
				if not result:
					return
				match result:
					"opened":
						rewarded_ad_show_result.emit(true)
					"rewarded":
						_rewarded = true
						rewarded_ad_impression_result.emit(true)
					"closed":
						if not _rewarded:
							rewarded_ad_impression_result.emit(false)
						rewarded_ad_closed.emit(_rewarded)
					"error":
						rewarded_ad_show_result.emit(false)
				)
		_ad_singleton.interstitial_ad.connect(func(result: String) -> void:
				if not result:
					return
				match result:
					"closed":
						interstitial_ad_closed.emit(true)
					"error":
						interstitial_ad_show_result.emit(false)
					"opened":
						interstitial_ad_show_result.emit(true)
				)
	elif "fake_ads" in OS.get_cmdline_args() and OS.is_debug_build():
		_ad_provider = AdProvider.FAKE_ADS
		_ad_singleton = self
	print("Ads provider ", AdProvider.keys()[_ad_provider])


func show_interstitial_ad() -> bool:
	if is_working():
		_is_ad_processing = true
		match _ad_provider:
			AdProvider.FAKE_ADS:
				var fake: AMFakeAd = preload("uid://dpoyxge8ps7fo").instantiate()
				fake.run.call_deferred(false)
				add_child(fake)
			_:
				_ad_singleton.show_interstitial_ad()
		var shown: bool = await interstitial_ad_show_result
		if shown:
			_mute_sound(true)
		else:
			_is_ad_processing = false
		return shown
	else:
		interstitial_ad_show_result.emit(false)
		return false


func show_rewarded_ad() -> bool:
	if is_working():
		_is_ad_processing = true
		match _ad_provider:
			AdProvider.FAKE_ADS:
				var fake: AMFakeAd = preload("uid://dpoyxge8ps7fo").instantiate()
				fake.run.call_deferred(true)
				add_child(fake)
			_:
				_ad_singleton.show_interstitial_ad()
		var shown: bool = await rewarded_ad_show_result
		if shown:
			_mute_sound(true)
		else:
			_is_ad_processing = false
		return shown
	else:
		rewarded_ad_show_result.emit(false)
		return false


func is_working() -> bool:
	return is_instance_valid(_ad_singleton)


func _create_fake_ad(revarded: bool = false) -> void:
	var fake: AMFakeAd = preload("res://addons/godot-ads-manager/fake_ad.tscn").instantiate()
	fake.run(revarded)
	add_child(fake)


func get_ads_provider() -> AdProvider:
	return _ad_provider


func _mute_sound(mute: bool) -> void:
	if not mute and has_node("/root/SettingsSaves"):
		AudioServer.set_bus_mute(0, await get_node("/root/SettingsSaves").load_mute_volume("Master"))
	else:
		AudioServer.set_bus_mute(0, mute)
