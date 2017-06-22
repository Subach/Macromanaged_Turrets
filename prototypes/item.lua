data:extend(
{
	{
		type = "selection-tool",
		name = ModPrefix.."logistic-turret-remote",
		icon = ModGFX.."remote.png",
		flags = {"goes-to-main-inventory"},
		subgroup = "tool",
		order = "m[logistic-turret-remote]",
		stack_size = 1,
		stackable = false,
		selection_color = {r = 1, g = 0.53, b = 0},
		alt_selection_color = {r = 0, g = 0.65, b = 0.96},
		selection_mode = {"buildable-type", "matches-force"},
		alt_selection_mode = {"buildable-type", "matches-force"},
		selection_cursor_box_type = "logistics",
		alt_selection_cursor_box_type = "copy"
	},
	{
		type = "recipe",
		name = ModPrefix.."logistic-turret-remote",
		enabled = data.raw.recipe["logistic-chest-requester"].enabled,
		ingredients = {{"electronic-circuit", 1}},
		result = ModPrefix.."logistic-turret-remote"
	}
})

for _, tech in pairs(data.raw.technology) do
	if tech.effects ~= nil then
		for i, effect in pairs(tech.effects) do
			if effect.recipe == "logistic-chest-requester" then
				table.insert(tech.effects, {type = "unlock-recipe", recipe = ModPrefix.."logistic-turret-remote"})
				break
			end
		end
	end
end