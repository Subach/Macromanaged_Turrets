data:extend(
{
	{
		type = "logistic-container",
		name = "MMT-logistic-turret-chest",
		icon = "__base__/graphics/icons/logistic-chest-requester.png",
		flags = {"not-on-map", "not-repairable"},
		max_health = 0,
		alert_when_damaged = false,
		collision_box = {{0, 0}, {0, 0}},
		selection_box = {{-1, -1}, {1, 1}},
		selectable_in_game = false,
		inventory_size = 1,
		logistic_mode = "requester",
		picture =
		{
			filename = "__core__/graphics/empty.png",
			priority = "very-low",
			width = 0,
			height = 0
		},
		order = "b[storage]-c[logistic-chest-requester]-a[logistic-turret-chest]"
	},
	{
		type = "decorative",
		name = "MMT-logistic-turret-remote",
		icon = "__Macromanaged_Turrets__/graphics/remote_32.png",
		flags = {"placeable-off-grid", "not-repairable", "not-on-map"},
		collision_box = {{0, 0}, {0, 0}},
		selection_box = {{0, 0}, {0, 0}},
		selectable_in_game = false,
		render_layer = "air-object",
		pictures =
		{
			{
				filename = "__Macromanaged_Turrets__/graphics/remote.png",
				priority = "extra-high",
				width = 64,
				height = 64,
				shift = {0.35, 0.35},
				scale = 0.25
			}
		}
	}
})