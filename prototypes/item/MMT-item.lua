data:extend(
{
	{
		type = "item",
		name = "MMT-gui-empty",
		icon = "__core__/graphics/remove-icon.png",
		flags = {"hidden"},
		order = "z[MMT-gui]",
		stack_size = 1
	},
	{
		type = "item",
		name = "MMT-logistic-turret-remote",
		icon = "__Macromanaged_Turrets__/graphics/remote_32.png",
		flags = {"goes-to-quickbar"},
		subgroup = "tool",
		order = "m[MMT-logistic-turret-remote]",
		place_result = "MMT-logistic-turret-remote",
		stack_size = 1
	}
})