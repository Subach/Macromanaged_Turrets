local function item_icon_base_orange(pos)
	return
	{
		filename = "__core__/graphics/gui.png",
		priority = "extra-high-no-scale",
		width = 36,
		height = 36,
		x = 75,
		y = pos,
		shift = {10, 0},
		scale = 2
	}
end

local function item_icon_image(icon)
	return
	{
		filename = icon,
		priority = "extra-high-no-scale",
		width = 32,
		height = 32,
		shift = {1, 0},
		scale = 0.9
	}
end

for name, item in pairs(data.raw["ammo"]) do
	if item.icon ~= nil then
		data.raw["gui-style"]["default"]["MMT-icon-"..name] =
		{
			type = "checkbox_style",
			parent = "MMT-icon-MMT-gui-empty",
			checked = item_icon_image(item.icon)
		}
		data.raw["gui-style"]["default"]["MMT-ocon-"..name] =
		{
			type = "checkbox_style",
			parent = "MMT-icon-MMT-gui-empty",
			default_background = item_icon_base_orange(108),
			hovered_background = item_icon_base_orange(72),
			clicked_background = item_icon_base_orange(72),
			checked = item_icon_image(item.icon)
		}
	end
end