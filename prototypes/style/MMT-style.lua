local function icon_base(x) 
	return
	{
		filename = "__core__/graphics/gui.png",
		priority = "extra-high-no-scale",
		width = 36,
		height = 36,
		x = x,
		shift = {0, -10}
	}
end

data.raw["gui-style"]["default"]["MMT-name"] =
{
	type = "label_style",
	parent = "frame_caption_label_style",
	width = 145
}

data.raw["gui-style"]["default"]["MMT-count"] =
{
	type = "textfield_style",
	minimal_width = 54
}

data.raw["gui-style"]["default"]["MMT-save"] =
{
	type = "button_style",
	parent = "slot_button_style",
	font = "default-semibold",
	hovered_font_color = {r = 0.1, g = 0.1, b = 0.1},
	width = 66,
	height = 32,
	top_padding = 0,
	right_padding = 0,
	bottom_padding = 0,
	left_padding = 0
}

data.raw["gui-style"]["default"]["MMT-icon-MMT-gui-empty"] =
{
	type = "checkbox_style",
	scalable = false,
	width = 36,
	height = 36,
	default_background = icon_base(111),
	hovered_background = icon_base(148),
	clicked_background = icon_base(185),
	checked =
	{
		filename = "__core__/graphics/empty.png",
		priority = "extra-high-no-scale",
		width = 0,
		height = 0,
		shift = {0, -10}
	}
}