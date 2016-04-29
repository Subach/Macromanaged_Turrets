local function icon_base(x, y) 
	return
	{
		filename = "__core__/graphics/gui.png",
		priority = "extra-high-no-scale",
		width = 36,
		height = 36,
		x = x,
		y = y,
		shift = {0, -10}
	}
end

for name, item in pairs(data.raw["ammo"]) do
	if item.icon ~= nil then
		data.raw["gui-style"]["default"]["MMT-icon-"..name] =
		{
			type = "checkbox_style",
			parent = "MMT-icon-MMT-gui-empty",
			checked =
			{
				filename = item.icon,
				width = 32,
				height = 32,
				shift = {0, -10}
			}
		}
		data.raw["gui-style"]["default"]["MMT-ocon-"..name] =
		{
			type = "checkbox_style",
			parent = "MMT-icon-MMT-gui-empty",
			default_background = icon_base(75, 108),
			hovered_background = icon_base(75, 72),
			clicked_background = icon_base(75, 72),
			checked =
			{
				filename = item.icon,
				priority = "extra-high-no-scale",
				width = 32,
				height = 32,
				shift = {0, -10}
			}
		}
	end
end