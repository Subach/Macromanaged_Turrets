local function icon_base(x) 
	return
	{
		filename = "__core__/graphics/gui.png",
		priority = "extra-high-no-scale",
		width = 36,
		height = 36,
		shift = {10, 0},
		x = x,
		scale = 2
	}
end

data.raw["gui-style"]["default"]["MMT-name"] =
{
	type = "label_style",
	parent = "frame_caption_label_style",
	width = 145
}

data.raw["gui-style"]["default"]["MMT-table"] =
{
	type = "table_style",
	horizontal_spacing = 1,
	vertical_spacing = 2
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

data.raw["gui-style"]["default"]["MMT-close"] =
{
	type = "checkbox_style",
	default_background =
	{
		filename = "__core__/graphics/gui.png",
		priority = "extra-high-no-scale",
		width = 16,
		height = 16,
		x = 43,
		y = 17,
		scale = 0.9
	},
	hovered_background =
	{
		filename = "__core__/graphics/gui.png",
		priority = "extra-high-no-scale",
		width = 16,
		height = 16,
		x = 60,
		y = 17,
		scale = 0.9
	},
	clicked_background =
	{
		filename = "__core__/graphics/gui.png",
		priority = "extra-high-no-scale",
		width = 16,
		height = 16,
		x = 77,
		y = 17,
		scale = 0.9
	},
	checked =
	{
		filename = "__core__/graphics/gui.png",
		priority = "extra-high-no-scale",
		width = 16,
		height = 16,
		x = 94,
		y = 17,
		scale = 0.91
	}
}

data.raw["gui-style"]["default"]["MMT-icon-MMT-gui-empty"] =
{
	type = "checkbox_style",
	scalable = false,
	width = 37,
	height = 37,
	default_background = icon_base(111),
	hovered_background = icon_base(148),
	clicked_background = icon_base(185),
	checked =
	{
		filename = "__core__/graphics/empty.png",
		priority = "extra-high-no-scale",
		width = 0,
		height = 0,
		shift = {1, 0}
	}
}