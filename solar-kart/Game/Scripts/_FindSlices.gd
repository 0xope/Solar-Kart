extends SceneTree

func _init() -> void:
	var img := Image.load_from_file("res://Game/Assets/GUI/Screens/Menu.png")
	var w := img.get_width()
	var h := img.get_height()
	print("Image dimensions: %dx%d" % [w, h])

	# Let's define the precise crop boxes
	var crops := {
		"Logo": Rect2i(540, 25, 620, 230),
		"Profile_Badge": Rect2i(65, 18, 330, 95),
		"Coin_Pill": Rect2i(1180, 30, 205, 50),
		"Gem_Pill": Rect2i(1405, 30, 205, 50),
		"Button_Play": Rect2i(535, 488, 600, 110),
		"Button_Leaderboard": Rect2i(415, 615, 405, 68),
		"Button_Garage": Rect2i(850, 615, 405, 68),
		"Button_Shop": Rect2i(415, 695, 405, 68),
		"Button_Wallet": Rect2i(850, 695, 405, 68),
		"Button_HowToPlay": Rect2i(415, 775, 405, 68),
		"Button_Settings": Rect2i(850, 775, 405, 68),
		"Bottom_Ticker": Rect2i(540, 882, 590, 40)
	}

	for k in crops:
		var rect: Rect2i = crops[k]
		var sub := img.get_region(rect)
		var out_path := "res://Game/Assets/GUI/Components/%s.png" % k
		sub.save_png(out_path)
		print("Saved %-20s: %s (size %dx%d)" % [k, out_path, rect.size.x, rect.size.y])

	quit()
