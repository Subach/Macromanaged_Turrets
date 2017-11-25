local function nav_button(opts)
	return
	{
		type = "monolith",
		top_monolith_border = 0,
		right_monolith_border = 0,
		bottom_monolith_border = 0,
		left_monolith_border = 0,
		stretch_monolith_image_to_size = false,
		monolith_image =
		{
			filename = MOD_GFX.."gui.png",
			priority = "extra-high-no-scale",
			width = 16,
			height = 16,
			x = opts.x
		}
	}
end

local function radio_button(opts)
	return
	{
		type = "monolith",
		top_monolith_border = 0,
		right_monolith_border = 0,
		bottom_monolith_border = 0,
		left_monolith_border = 0,
		stretch_monolith_image_to_size = false,
		monolith_image =
		{
			filename = MOD_GFX.."gui.png",
			priority = "extra-high-no-scale",
			width = 10,
			height = 10,
			x = opts.x,
			y = 32
		}
	}
end

local function sprite_button(opts)
	return
	{
		type = "monolith",
		top_monolith_border = 1,
		right_monolith_border = 1,
		bottom_monolith_border = 1,
		left_monolith_border = 1,
		monolith_image =
		{
			filename = MOD_GFX.."gui.png",
			priority = "extra-high-no-scale",
			width = 36,
			height = 36,
			x = opts.x,
			y = opts.y
		}
	}
end

local function sprite(opts)
	return
	{
		type = "sprite",
		name = MOD_PREFIX..opts.name,
		filename = MOD_GFX.."gui.png",
		priority = "extra-high-no-scale",
		width = opts.width or 16,
		height = opts.height or 16,
		x = opts.x or 0,
		y = opts.y or 0,
		shift = opts.shift
	}
end

data:extend(
{
	sprite{name = "close", y = 16},
	sprite{name = "prev", x = 16, y = 16, shift = {-1, 0}},
	sprite{name = "next", x = 32, y = 16, shift = {1, 0}},
	sprite{name = "paste-match", x = 48, y = 32},
	sprite{name = "paste-all", x = 64, y = 32},
	sprite{name = "paste-behavior", x = 80, y = 32},
	sprite{name = "circuitry", x = 96, y = 32},
	sprite{name = "save", width = 32, height = 32, x = 48},
	sprite{name = "copy", width = 32, height = 32, x = 80},
	sprite{name = "unknown", width = 32, height = 32, x = 112},
	sprite{name = "bullet", width = 10, height = 10, x = 30, y = 32}
})

data.raw["gui-style"]["default"][MOD_PREFIX.."index"] =
{
	type = "label_style",
	font = "default-small-semibold",
	align = "center",
	minimal_width = 46
}

data.raw["gui-style"]["default"][MOD_PREFIX.."nav"] =
{
	type = "button_style",
	default_font_color = {a = 0},
	hovered_font_color = {a = 0},
	clicked_font_color = {a = 0},
	scalable = false,
	width = 16,
	height = 20,
	top_padding = 2,
	right_padding = 0,
	bottom_padding = 2,
	left_padding = 0,
	default_graphical_set = nav_button{x = 0},
	hovered_graphical_set = nav_button{x = 16},
	clicked_graphical_set = nav_button{x = 32}
}

data.raw["gui-style"]["default"][MOD_PREFIX.."radio"] =
{
	type = "button_style",
	default_font_color = {a = 0},
	hovered_font_color = {a = 0},
	clicked_font_color = {a = 0},
	scalable = false,
	width = 10,
	height = 20,
	top_padding = 6,
	right_padding = 0,
	bottom_padding = 6,
	left_padding = 0,
	default_graphical_set = radio_button{x = 0},
	hovered_graphical_set = radio_button{x = 10},
	clicked_graphical_set = radio_button{x = 20}
}

data.raw["gui-style"]["default"][MOD_PREFIX.."base"] =
{
	type = "button_style",
	default_font_color = {a = 0},
	hovered_font_color = {a = 0},
	clicked_font_color = {a = 0},
	scalable = false,
	width = 36,
	height = 36,
	top_padding = 1,
	right_padding = 1,
	bottom_padding = 1,
	left_padding = 1
}

data.raw["gui-style"]["default"][MOD_PREFIX.."icon-v0.14"] =
{
	type = "button_style",
	parent = MOD_PREFIX.."base",
	width = 20,
	height = 20,
	default_graphical_set = sprite_button{x = 0, y = 48},
	hovered_graphical_set = sprite_button{x = 36, y = 48},
	clicked_graphical_set = sprite_button{x = 72, y = 48}
}

data.raw["gui-style"]["default"][MOD_PREFIX.."icon-v0.15"] =
{
	type = "button_style",
	parent = MOD_PREFIX.."base",
	width = 20,
	height = 20,
	default_graphical_set = sprite_button{x = 0, y = 120},
	hovered_graphical_set = sprite_button{x = 36, y = 120},
	clicked_graphical_set = sprite_button{x = 72, y = 48}
}

data.raw["gui-style"]["default"][MOD_PREFIX.."gray-v0.14"] =
{
	type = "button_style",
	parent = MOD_PREFIX.."base",
	default_graphical_set = sprite_button{x = 0, y = 48},
	hovered_graphical_set = sprite_button{x = 36, y = 48},
	clicked_graphical_set = sprite_button{x = 72, y = 48}
}

data.raw["gui-style"]["default"][MOD_PREFIX.."gray-v0.15"] =
{
	type = "button_style",
	parent = MOD_PREFIX.."base",
	default_graphical_set = sprite_button{x = 0, y = 120},
	hovered_graphical_set = sprite_button{x = 36, y = 120},
	clicked_graphical_set = sprite_button{x = 72, y = 48}
}

data.raw["gui-style"]["default"][MOD_PREFIX.."orange-v0.14"] =
{
	type = "button_style",
	parent = MOD_PREFIX.."base",
	default_graphical_set = sprite_button{x = 108, y = 48},
	hovered_graphical_set = sprite_button{x = 108, y = 84},
	clicked_graphical_set = sprite_button{x = 108, y = 84}
}

data.raw["gui-style"]["default"][MOD_PREFIX.."orange-v0.15"] =
{
	type = "button_style",
	parent = MOD_PREFIX.."base",
	default_graphical_set = sprite_button{x = 108, y = 120},
	hovered_graphical_set = sprite_button{x = 108, y = 156},
	clicked_graphical_set = sprite_button{x = 108, y = 84}
}

data.raw["gui-style"]["default"][MOD_PREFIX.."blue-v0.14"] =
{
	type = "button_style",
	parent = MOD_PREFIX.."base",
	default_graphical_set = sprite_button{x = 0, y = 84},
	hovered_graphical_set = sprite_button{x = 36, y = 84},
	clicked_graphical_set = sprite_button{x = 72, y = 84}
}

data.raw["gui-style"]["default"][MOD_PREFIX.."blue-v0.15"] =
{
	type = "button_style",
	parent = MOD_PREFIX.."base",
	default_graphical_set = sprite_button{x = 0, y = 156},
	hovered_graphical_set = sprite_button{x = 36, y = 156},
	clicked_graphical_set = sprite_button{x = 72, y = 84}
}