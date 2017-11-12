local function memory_flag(opts)
	return
	{
		type = "item",
		name = MOD_PREFIX.."memory-"..opts.name,
		icon = "__base__/graphics/icons/signal/signal_"..opts.color..".png",
		icon_size = 32,
		flags = {"goes-to-main-inventory", "hidden"},
		subgroup = "other",
		stack_size = 1,
		localised_name = {"item-name."..MOD_PREFIX.."logistic-turret-memory-flag", opts.localised_name},
		localised_description = {"item-name."..MOD_PREFIX.."logistic-turret-memory-flag", opts.localised_description}
	}
end

data:extend(
{
	{
		type = "selection-tool",
		name = MOD_PREFIX.."logistic-turret-remote",
		icon = MOD_GFX.."remote.png",
		icon_size = 32,
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
		name = MOD_PREFIX.."logistic-turret-remote",
		result = MOD_PREFIX.."logistic-turret-remote",
		enabled = (data.raw.recipe["logistic-chest-requester"] ~= nil and data.raw.recipe["logistic-chest-requester"].enabled),
		ingredients = {{"electronic-circuit", 1}}
	},
	{
		type = "item",
		name = MOD_PREFIX.."logistic-turret-chest",
		icon = MOD_GFX.."chest.png",
		icon_size = 32,
		flags = {"goes-to-main-inventory", "hidden"},
		place_result = MOD_PREFIX.."logistic-turret-chest",
		subgroup = "other",
		stack_size = 1
	},
	{
		type = "item",
		name = MOD_PREFIX.."logistic-turret-memory",
		icon = MOD_GFX.."chest.png",
		icon_size = 32,
		flags = {"goes-to-main-inventory", "hidden"},
		place_result = MOD_PREFIX.."logistic-turret-memory",
		subgroup = "other",
		stack_size = 1
	},
	memory_flag{name = "limit-full", color = "blue", localised_name = "Insert limit", localised_description = "The amount of ammo this turret will attempt to keep in its inventory."},
	memory_flag{name = "limit-half", color = "pink", localised_name = "Insert limit", localised_description = "This turret is requesting a single item and will attempt to keep half of a magazine in its inventory."},
	memory_flag{name = "override", color = "grey", localised_name = "Manual override", localised_description = "This turret's request slot has been manually overridden."},
	memory_flag{name = "circuit-input", color = "cyan", localised_name = {"gui-control-behavior-modes.set-requests"}, localised_description = "This turret is changing its request slot based on the signals it is receiving."},
	memory_flag{name = "circuit-output", color = "cyan", localised_name = {"gui-control-behavior-modes.read-contents"}, localised_description = "This turret is transmitting the contents of its inventory to the circuit network."},
	memory_flag{name = "wire-red", color = "red", localised_name = {"item-name.red-wire"}, localised_description = "This turret is able to connect to red wires."},
	memory_flag{name = "wire-green", color = "green", localised_name = {"item-name.green-wire"}, localised_description = "This turret is able to connect to green wires."}
})

for _, tech in pairs(data.raw.technology) do
	if tech.effects ~= nil then
		for i, effect in pairs(tech.effects) do
			if effect.recipe == "logistic-chest-requester" then
				table.insert(tech.effects, {type = "unlock-recipe", recipe = MOD_PREFIX.."logistic-turret-remote"})
				break
			end
		end
	end
end

if data.raw.technology["logistic-system"] ~= nil then
	local found = false
	for _, effect in pairs(data.raw.technology["logistic-system"].effects) do
		if effect.recipe == MOD_PREFIX.."logistic-turret-remote" then
			found = true
			break
		end
	end
	if not found then
		table.insert(tech.effects, {type = "unlock-recipe", recipe = MOD_PREFIX.."logistic-turret-remote"})
	end
end