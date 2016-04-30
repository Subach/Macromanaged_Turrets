require("defines")
require("config")
local next = next

--Library--
local function add_logistics(turret)
	local chest = turret.surface.create_entity{name = "MMT-logistic-turret-chest", position = turret.position, force = turret.force, request_filters = {{index = 1, name = global.LogicTurretConfig[turret.name].ammo, count = global.LogicTurretConfig[turret.name].count}}}
	if chest == nil then
		return nil
	end
	chest.destructible = false
	chest.minable = false
	chest.operable = false
	return {turret, chest}
end

local function lookup_turret(turret)
	if next(global.LogicTurrets) == nil then
		return nil, nil
	end
	for i = 1, #global.LogicTurrets do
		if global.LogicTurrets[i][1] == turret then
			return global.LogicTurrets[i], i
		end
	end
	return nil, nil
end

local function insert_ammo(logicturret)
	local stash = logicturret[2].get_inventory(1)[1]
	stash.count = stash.count - logicturret[1].insert({name = stash.name, count = stash.count})
	return stash
end

local function check_ammo()
	for i = #global.LogicTurrets, 1, -1 do
		local logicturret = global.LogicTurrets[i]
		if logicturret[1].valid and logicturret[2].valid then
			if not logicturret[1].has_items_inside() and logicturret[2].has_items_inside() then
				insert_ammo(logicturret)
			end
		else
			if logicturret[2].valid then
				logicturret[2].destroy()
			end
			table.remove(global.LogicTurrets, i)
		end
	end
end

local function find_items_around(entity, radius)
	local collision = entity.prototype.collision_box or {left_top = {x = 0, y = 0}, right_bottom = {x = 0, y = 0}}
	return entity.surface.find_entities_filtered{
		name = "item-on-ground",
		area = {{
			entity.position.x - math.abs(collision.left_top.x) - (radius or 3),
			entity.position.y - math.abs(collision.left_top.y) - (radius or 3) },{
			entity.position.x + math.abs(collision.right_bottom.x) + (radius or 3),
			entity.position.y + math.abs(collision.right_bottom.y) + (radius or 3) }}}
end

local function spill_stack(entity, stack, cleanup, radius)
	if not entity.valid or not stack.valid_for_read then
		return
	end
	entity.surface.spill_item_stack(entity.position, {name = stack.name, count = stack.count})
	if cleanup == true then
		local items = find_items_around(entity, radius)
		if next(items) ~= nil then
			local count = (stack.count < #items) and stack.count or #items
			for i = 1, #items do
				if count <= 0 then
					break
				end
				local item = items[i]
				if item.valid and item.stack.name == stack.name and not item.to_be_deconstructed(entity.force) then
					item.order_deconstruction(entity.force)
					count = count - 1
				end
			end
		end
	end
	stack.clear()
end

local function fully_eject(logicturret)
	if logicturret[1].has_items_inside() then
		local inv = logicturret[1].get_inventory(1)
		for i = 1, #inv do
			local stash = inv[i]
			if stash.valid_for_read then
				spill_stack(logicturret[1], stash, true)
			end
		end
	end
	if logicturret[2].has_items_inside() then
		local stash = logicturret[2].get_inventory(1)[1]
		if stash.valid_for_read then
			spill_stack(logicturret[1], stash, true)
		end
	end
end

--Event handlers--
local function onTick(event)
	if event.tick == global.Timer then
		global.Timer = global.Timer + 30
		check_ammo()
	end
end

local function onBuilt(event)
	if event.created_entity.name == "MMT-logistic-turret-remote" then
		local item = game.players[event.player_index].cursor_stack
		if not item.valid_for_read then
			item.set_stack{name = "MMT-logistic-turret-remote", count = 1}
		elseif item.name == "MMT-logistic-turret-remote" then
			item.count = item.count + 1
		end
		event.created_entity.destroy()
		return
	elseif global.LogicTurretConfig[event.created_entity.name] == nil then
		return
	end
	local logicturret = add_logistics(event.created_entity)
	if logicturret == nil then
		return
	end
	if next(global.LogicTurrets) == nil then
		global.Timer = event.tick + math.random(30)
		script.on_event(defines.events.on_tick, onTick)
	end
	global.LogicTurrets[#global.LogicTurrets + 1] = logicturret
end

local function onDeath(event)
	if event.entity.type ~= "ammo-turret" then
		return
	end
	local logicturret, i = lookup_turret(event.entity)
	if logicturret == nil then
		return
	elseif logicturret[2].valid then
		logicturret[2].destroy()
	end
	table.remove(global.LogicTurrets, i)
	if next(global.LogicTurrets) == nil then
		global.Timer = -1
		script.on_event(defines.events.on_tick, nil)
	end
end

local function onMined(event)
	if event.entity.type ~= "ammo-turret" then
		return
	end
	local logicturret, i = lookup_turret(event.entity)
	if logicturret == nil then
		return
	elseif logicturret[1].valid and logicturret[2].valid then
		if logicturret[2].has_items_inside() then
			if event.player_index == nil or game.players[event.player_index].character == nil or not game.players[event.player_index].character.valid then
				spill_stack(logicturret[1], logicturret[2].get_inventory(1)[1], true)
			else
				local stash = insert_ammo(logicturret)
				if stash.valid_for_read then
					local player = game.players[event.player_index]
					stash.count = stash.count - player.insert({name = stash.name, count = stash.count})
					if stash.valid_for_read then
						player.surface.spill_item_stack(player.position, {name = stash.name, count = stash.count})
					end
				end
			end
		end
		logicturret[2].destroy()
	end
	table.remove(global.LogicTurrets, i)
	if next(global.LogicTurrets) == nil then
		global.Timer = -1
		script.on_event(defines.events.on_tick, nil)
	end
end

local function onMarked(event)
	if event.entity.type ~= "ammo-turret" then
		return
	end
	local logicturret = lookup_turret(event.entity)
	if logicturret == nil then
		return
	elseif logicturret[2].valid then
		logicturret[2].clear_request_slot(1)
	end
end

local function onUnmarked(event)
	if global.LogicTurretConfig[event.entity.name] == nil then
		return
	end
	local logicturret = lookup_turret(event.entity)
	if logicturret == nil then
		local relogicturret = add_logistics(event.entity)
		if relogicturret == nil then
			return
		end
		global.LogicTurrets[#global.LogicTurrets + 1] = relogicturret
	elseif logicturret[1].valid and logicturret[2].valid then
		logicturret[2].set_request_slot({name = global.LogicTurretConfig[logicturret[1].name].ammo, count = global.LogicTurretConfig[logicturret[1].name].count}, 1)
	end
end

--Configuration--
--Testing surface
local function decorate_workshop(workshop)
	if not game.surfaces[workshop.name].valid then
		script.on_event(defines.events.on_chunk_generated, nil)
		return
	end
	local nature = workshop.find_entities({{-16, -16}, {15, 15}})
	for i = 1, #nature do
		if nature[i].valid and nature[i].type ~= "player" then
			nature[i].destroy()
		end
	end
	local flooring = {}
	for x = -16, 15 do
		for y = -16, 15 do
			local tile = {name = "concrete", position = {x, y}}
			flooring[#flooring + 1] = tile
		end
	end
	workshop.set_tiles(flooring)
	script.on_event(defines.events.on_chunk_generated, nil)
end

local function onChunkGenerated(event)
	if event.surface == game.surfaces["MMT-workshop"] then
		decorate_workshop(event.surface)
	end
end

local function build_workshop()
	if game.surfaces["MMT-workshop"] ~= nil and game.surfaces["MMT-workshop"].valid then
		return game.surfaces["MMT-workshop"]
	end
	local workshop = game.create_surface("MMT-workshop", {
		terrain_segmentation = "very-low",
		water = "none",
		starting_area = "none",
		width = 32,
		height = 32,
		peaceful_mode = true })
	decorate_workshop(workshop)
	workshop.request_to_generate_chunks({0, 0}, 1)
	script.on_event(defines.events.on_chunk_generated, onChunkGenerated)
	return workshop
end

--Sanititazion
local function validate_ammo(turret, ammo)
	local surface = build_workshop()
	local position = surface.find_non_colliding_position(turret, {0, 0}, 0, 1)
	if position == nil then
		return false
	end
	local testturret = surface.create_entity{name = turret, position = position, force = "neutral"}
	if testturret == nil then
		return false
	end
	local test = testturret.can_insert(ammo)
	testturret.destroy()
	return test
end

local function validate_config(turret, ammo, count)
	if turret == nil or ammo == nil or count == nil then
		return nil, false, false
	elseif global.LogicTurretConfig[turret] ~= nil and global.LogicTurretConfig[turret].ammo == ammo then
		if global.LogicTurretConfig[turret].count == count then
			return {ammo = ammo, count = count}, false, false
		else
			return {ammo = ammo, count = count}, false, true
		end
	end
	if type(turret) == "string" and type(ammo) == "string" and type(count) == "number" and
	game.entity_prototypes[turret] ~= nil and game.entity_prototypes[turret].type == "ammo-turret" and
	game.item_prototypes[ammo] ~= nil and game.item_prototypes[ammo].type == "ammo" and
	validate_ammo(turret, ammo) == true then
		count = math.min(math.floor(count), game.item_prototypes[ammo].stack_size)
		if count > 0 then
			if global.LogicTurretConfig[turret] == nil then
				return {ammo = ammo, count = count}, true, false
			else
				return {ammo = ammo, count = count}, false, true
			end
		end
	end
	return nil, false, false
end

local function check_config()
	local turretlist = {}
	local LogisticTurret = LogisticTurret or {}
	if next(LogisticTurret) ~= nil then
		for turret in pairs(LogisticTurret) do
			turretlist[turret] = turretlist[turret] or LogisticTurret[turret]
		end
	end
	local RemoteTurretConfig = RemoteTurretConfig
	if AllowRemoteCalls ~= false and next(RemoteTurretConfig) ~= nil then
		for turret, config in pairs(RemoteTurretConfig) do
			turretlist[turret] = turretlist[turret] or config
		end
	end
	if UseBobsDefault == true and game.entity_prototypes["bob-sniper-turret-1"] ~= nil then
		local BobsDefault = BobsDefault or {ammo = "piercing-bullet-magazine", count = 5}
		for turret, entity in pairs(game.entity_prototypes) do
			if entity.type == "ammo-turret" and string.match(turret, "bob%-") ~= nil then
				turretlist[turret] = turretlist[turret] or BobsDefault
			end
		end
	end
	local NewTurret = false
	local RequestUpdate = false
	if next(turretlist) ~= nil then
		for turret, config in pairs(turretlist) do
			local a, b
			turretlist[turret], a, b = validate_config(turret, config.ammo, config.count)
			NewTurret = a or NewTurret
			RequestUpdate = b or RequestUpdate
		end
	end
	if next(global.LogicTurretConfig) ~= nil then
		for turret in pairs(global.LogicTurretConfig) do
			if turretlist[turret] == nil then
				RequestUpdate = true
				break
			end
		end
	end
	global.LogicTurretConfig = turretlist
	return NewTurret, RequestUpdate
end

--GUI--
local function open_gui(player)
	local request = global.TurretGUI[player.index][1][2].get_request_slot(1) or {name = "MMT-gui-empty", count = 0}
	local root = player.gui.center.add{type = "frame", name = "MMT-gui", direction = "vertical", style = "inner_frame_in_outer_frame_style"}
		root.add{type = "flow", name = "MMT-title", direction = "horizontal", style = "flow_style"}
			root["MMT-title"].add{type = "label", name = "MMT-name", style = "MMT-name", caption = global.TurretGUI[player.index][1][1].localised_name}
			root["MMT-title"].add{type = "checkbox", name = "MMT-close", style = "checkbox_style", state = true}
		root.add{type = "label", name = "MMT-text", style = "description_label_style", caption = game.item_prototypes[request.name].localised_name}
		local request_flow = root.add{type = "flow", name = "MMT-request", direction = "horizontal", style = "description_flow_style"}
			request_flow.add{type = "checkbox", name = "MMT-ammo", style = "MMT-icon-"..request.name, state = true}
			request_flow.add{type = "textfield", name = "MMT-count", style = "MMT-count", text = request.count}
			request_flow.add{type = "button", name = "MMT-save", style = "MMT-save", caption = {"MMT-gui-save"}}
end

local function show_ammo_table(player_index, gui, request)
	if gui["MMT-ammo"] ~= nil then
		gui["MMT-ammo"].destroy()
		return
	end
	local turret = global.TurretGUI[player_index][1][1].name
	if global.TurretGUI[player_index]["cashe"] == nil then
		global.TurretGUI[player_index]["cashe"] = request
	else
		request = global.TurretGUI[player_index]["cashe"]
	end
	local ammo_table = gui.add{type = "table", name = "MMT-ammo", colspan = 5, style = "slot_table_style"}
		ammo_table.add{type = "checkbox", name = "MMT-icon-empty", style = "MMT-icon-MMT-gui-empty", state = true}
		for i = 1, #global.IconSets[turret] do
			local ammo = global.IconSets[turret][i]
			if request ~= "MMT-gui-empty" and ammo == request then
				ammo_table.add{type = "checkbox", name = "MMT-icon-"..ammo, style = "MMT-ocon-"..ammo, state = true}
			else
				ammo_table.add{type = "checkbox", name = "MMT-icon-"..ammo, style = "MMT-icon-"..ammo, state = true}
			end
		end
end

local function set_request(gui, ammo)
	gui["MMT-text"].caption = game.item_prototypes[ammo].localised_name
	gui["MMT-request"]["MMT-ammo"].style = "MMT-icon-"..ammo
	gui["MMT-ammo"].destroy()
end

local function save_request(player, gui)
	local ammo = string.sub(gui["MMT-ammo"].style.name, 10)
	local count = tonumber(gui["MMT-count"].text)
	if count == nil then
		return
	else
		count = math.min(math.floor(count), game.item_prototypes[ammo].stack_size)
	end
	if ammo == "MMT-gui-empty" or count <= 0 then
		if gui.parent["MMT-ammo"] ~= nil and global.TurretGUI[player.index]["cashe"] ~= "MMT-gui-empty" then
			gui.parent["MMT-ammo"]["MMT-icon-"..(global.TurretGUI[player.index]["cashe"])].style = "MMT-icon-"..global.TurretGUI[player.index]["cashe"]
		end
		global.TurretGUI[player.index]["request"] = "clear"
		player.print({"MMT-gui-request-clear"})
	else
		if gui.parent["MMT-ammo"] ~= nil then
			if global.TurretGUI[player.index]["cashe"] ~= "MMT-gui-empty" then
				gui.parent["MMT-ammo"]["MMT-icon-"..(global.TurretGUI[player.index]["cashe"])].style = "MMT-icon-"..global.TurretGUI[player.index]["cashe"]
			end
			gui.parent["MMT-ammo"]["MMT-icon-"..ammo].style = "MMT-ocon-"..ammo
		end
		global.TurretGUI[player.index]["request"] = {ammo = ammo, count = count}
		player.print({"MMT-gui-request-save"})
	end
	global.TurretGUI[player.index]["cashe"] = ammo
end

local function close_gui(player)
	if player.gui.center["MMT-gui"] == nil or not player.gui.center["MMT-gui"].valid then
		if global.TurretGUI[player.index] ~= nil then
			global.TurretGUI[player.index] = nil
		end
		return
	elseif global.TurretGUI[player.index] == nil or not global.TurretGUI[player.index][1][1].valid or not global.TurretGUI[player.index][1][2].valid then
		if player.gui.center["MMT-gui"].valid then
			player.gui.center["MMT-gui"].destroy()
		end
		global.TurretGUI[player.index] = nil
		return
	end
	if global.TurretGUI[player.index]["request"] ~= nil then
		local logicturret = global.TurretGUI[player.index][1]
		local index = global.TurretGUI[player.index][2]
		if global.TurretGUI[player.index]["request"] == "clear" then
			if logicturret[2].has_items_inside() then
				local stash = insert_ammo(logicturret)
				if stash.valid_for_read then
					spill_stack(logicturret[1], stash, true)
				end
			end
			global.LogicTurrets[index]["custom-request"] = "clear"
			logicturret[2].clear_request_slot(1)
		else
			local ammo = global.TurretGUI[player.index]["request"].ammo
			local count = global.TurretGUI[player.index]["request"].count
			local request = logicturret[2].get_request_slot(1)
			if ammo == global.LogicTurretConfig[logicturret[1].name].ammo and count == global.LogicTurretConfig[logicturret[1].name].count then
				global.LogicTurrets[index]["custom-request"] = nil
			else
				global.LogicTurrets[index]["custom-request"] = {ammo = ammo, count = count}
			end
			if request == nil or request.name == ammo and request.count ~= count then
				logicturret[2].set_request_slot({name = ammo, count = count}, 1)
				if logicturret[1].has_items_inside() then
					local inv = logicturret[1].get_inventory(1)
					for i = 1, #inv do
						local stash = inv[i]
						if stash.valid_for_read and stash.name ~= ammo then
							spill_stack(logicturret[1], stash, true)
						end
					end
				end
			elseif request.name ~= ammo then
				logicturret[2].set_request_slot({name = ammo, count = count}, 1)
				fully_eject(logicturret)
			end
		end
	end
	global.TurretGUI[player.index] = nil
	player.gui.center["MMT-gui"].destroy()
end

local function onGuiClick(event)
	local player = game.players[event.player_index]
	if player.gui.center["MMT-gui"] == nil or not player.gui.center["MMT-gui"].valid then
		if global.TurretGUI[player.index] ~= nil then
			global.TurretGUI[player.index] = nil
		end
		return
	elseif global.TurretGUI[player.index] == nil or not global.TurretGUI[player.index][1][1].valid or not global.TurretGUI[player.index][1][2].valid then
		if player.gui.center["MMT-gui"].valid then
			player.gui.center["MMT-gui"].destroy()
		end
		global.TurretGUI[player.index] = nil
		return
	end
	local element = event.element
	local gui = player.gui.center["MMT-gui"]
	if element == gui["MMT-title"]["MMT-close"] then
		element.state = true
		close_gui(player)
	elseif element == gui["MMT-request"]["MMT-ammo"] then
		element.state = true
		show_ammo_table(player.index, gui, string.sub(element.style.name, 10))
	elseif element.parent == gui["MMT-ammo"] then
		element.state = true
		set_request(gui, string.sub(element.style.name, 10))
	elseif element == gui["MMT-request"]["MMT-save"] then
		save_request(player, element.parent)
	end
end

local function onPutItem(event)
	local player = game.players[event.player_index]
	if player.cursor_stack == nil or not player.cursor_stack.valid_for_read or player.cursor_stack.name ~= "MMT-logistic-turret-remote" then
		return
	end
	local turret = player.surface.find_entities_filtered{area = {event.position, event.position}, type = "ammo-turret", force = player.force}
	if next(turret) == nil or global.LogicTurretConfig[turret[1].name] == nil or turret[1].to_be_deconstructed(player.force) then
		close_gui(player)
		return
	end
	local logicturret, index = lookup_turret(turret[1])
	if logicturret == nil then
		close_gui(player)
		return
	elseif logicturret[1].valid and logicturret[2].valid then
		close_gui(player)
		global.TurretGUI[event.player_index] = {logicturret, index}
		open_gui(player)
	end
end

--GUI Icons
local function make_iconsets()
	local ammoset = {}
	for turret, entity in pairs(game.entity_prototypes) do
		if entity.type == "ammo-turret" then
			ammoset[turret] = {}
			for ammo, item in pairs(game.item_prototypes) do
				if item.type == "ammo" and not item.has_flag("hidden") then
					if validate_ammo(turret, ammo) == true then
						ammoset[turret][#ammoset[turret] + 1] = ammo
					end
				end
			end
		end
	end
	global.IconSets = ammoset
end

--Remote interface--
local add_logistic_turret = function(turret, ammo, count)
	if turret ~= nil and ammo ~= nil and count ~= nil then
		RemoteTurretConfig[turret] = {ammo = ammo, count = count}
	end
end

--Loader--
local function update_requests()
	if next(global.LogicTurrets) == nil then
		return
	end
	for i = #global.LogicTurrets, 1, -1 do
		local logicturret = global.LogicTurrets[i]
		if logicturret[1].valid and logicturret[2].valid then
			if global.LogicTurretConfig[logicturret[1].name] ~= nil then
				local ammo = global.LogicTurretConfig[logicturret[1].name].ammo
				local count = global.LogicTurretConfig[logicturret[1].name].count
				local request = logicturret[2].get_request_slot(1)
				if logicturret["custom-request"] ~= nil then
					if logicturret["custom-request"] ~= "clear" and logicturret["custom-request"].ammo == ammo and logicturret["custom-request"].count == count then
						logicturret["custom-request"] = nil
					end
				elseif request == nil or request.name == ammo and request.count ~= count then
					logicturret[2].set_request_slot({name = ammo, count = count}, 1)
					if logicturret[1].has_items_inside() then
						local inv = logicturret[1].get_inventory(1)
						for i = 1, #inv do
							local stash = inv[i]
							if stash.valid_for_read and stash.name ~= ammo then
								spill_stack(logicturret[1], stash, true)
							end
						end
					end
				elseif request.name ~= ammo then
					logicturret[2].set_request_slot({name = ammo, count = count}, 1)
					fully_eject(logicturret)
				end
			else
				if logicturret[2].has_items_inside() then
					local stash = insert_ammo(logicturret)
					if stash.valid_for_read then
						spill_stack(logicturret[1], stash, true)
					end
				end
				logicturret[2].destroy()
				table.remove(global.LogicTurrets, i)
			end
		else
			if logicturret[2].valid then
				logicturret[2].destroy()
			end
			table.remove(global.LogicTurrets, i)
		end
	end
end

local function find_turrets()
	if next(global.LogicTurretConfig) == nil then
		return
	end
	for _, surface in pairs(game.surfaces) do
		for chunk in surface.get_chunks() do
			if surface.is_chunk_generated({chunk.x, chunk.y}) == true then
				local area = {{chunk.x * 32, chunk.y * 32}, {(chunk.x + 1) * 32, (chunk.y + 1) * 32}}
				for t in pairs(global.LogicTurretConfig) do
					for _, turret in pairs(surface.find_entities_filtered{area = area, name = t}) do
						if lookup_turret(turret) == nil then
							local logicturret = add_logistics(turret)
							if logicturret ~= nil then
								global.LogicTurrets[#global.LogicTurrets + 1] = logicturret
							end
						end
					end
				end
			end
		end
	end
end

local function set_autofill()
	if remote.interfaces["af"] == nil or next(global.LogicTurretConfig) == nil then
		return
	end
	local AutofillSets = {remote.call("af", "getItemArray", "ammo-bullets"), remote.call("af", "getItemArray", "ammo-rockets"), remote.call("af", "getItemArray", "ammo-shells")}
	for turret, config in pairs(global.LogicTurretConfig) do
		local ammo = config.ammo
		local found = false
		for i = 1, #AutofillSets do
			for j = 1, #AutofillSets[i] do
				if ammo == AutofillSets[i][j] then
					ammo = AutofillSets[i]
					found = true
					break
				end
			end
			if found == true then
				break
			end
		end
		remote.call("af", "addToDefaultSets", turret, {priority = 1, group = "turrets", limits = {10}, ammo})
	end
end

local function onStart(event)
	local NewTurret, RequestUpdate = check_config()
	if NewTurret == true or RequestUpdate == true then
		if RequestUpdate == true then
			update_requests()
		end
		if NewTurret == true then
			find_turrets()
		end
		set_autofill()
	end
	if next(global.IconSets) == nil then
		make_iconsets()
	end
	if next(global.LogicTurretConfig) ~= nil then
		script.on_event(defines.events.on_robot_built_entity, onBuilt)
		script.on_event(defines.events.on_entity_died, onDeath)
		script.on_event(defines.events.on_preplayer_mined_item, onMined)
		script.on_event(defines.events.on_robot_pre_mined, onMined)
		script.on_event(defines.events.on_marked_for_deconstruction, onMarked)
		script.on_event(defines.events.on_canceled_deconstruction, onUnmarked)
		script.on_event(defines.events.on_gui_click, onGuiClick)
		script.on_event(defines.events.on_put_item, onPutItem)
	end
	if next(global.LogicTurrets) == nil then
		script.on_event(defines.events.on_tick, nil)
	else
		global.Timer = event.tick + math.random(30)
		script.on_event(defines.events.on_tick, onTick)
	end
end

local function onLoad()
	global.TurretGUI = {}
	RemoteTurretConfig = {}
	remote.add_interface("Macromanaged_Turrets", {add_logistic_turret = add_logistic_turret})
	script.on_event(defines.events.on_built_entity, onBuilt)
	script.on_event(defines.events.on_tick, onStart)
end

local function onInit()
	global.IconSets = {}
	global.LogicTurrets = {}
	global.LogicTurretConfig = {}
	global.Timer = -1
	onLoad()
end

local function onModChanges(data)
	if data == nil or data.mod_changes == nil then
		return
	end
	if data.mod_changes["Macromanaged_Turrets"] ~= nil then
		local old_version = data.mod_changes["Macromanaged_Turrets"].old_version
		local new_version = data.mod_changes["Macromanaged_Turrets"].new_version
		if old_version == nil then
			onInit()
		end
	end
	make_iconsets()
end

script.on_init(onInit)
script.on_load(onLoad)
script.on_configuration_changed(onModChanges)