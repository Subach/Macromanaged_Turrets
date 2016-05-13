require("defines")
require("config")
local next = next

--Library--
local function add_logistics(turret)
	local chest = turret.surface.create_entity{name = "MMT-logistic-turret-chest", position = turret.position, force = turret.force,
		request_filters = {{index = 1, name = global.LogicTurretConfig[turret.name].ammo, count = global.LogicTurretConfig[turret.name].count}}}
	if chest == nil then
		return nil
	end
	chest.destructible = false
	chest.minable = false
	chest.operable = false
	return {turret, chest, math.min(turret.prototype.turret_range * 2.5, 100)}
end

local function lookup_turret(turret)
	local lists = {global.LogicTurrets, global.IdleLogicTurrets}
	for i = 1, #lists do
		local list = lists[i]
		for i = 1, #list do
			if list[i][1] == turret then
				return list, i
			end
		end
	end
	return nil, nil
end

local function insert_ammo(logicturret)
	local stash = logicturret[2].get_inventory(1)[1]
	stash.count = stash.count - logicturret[1].insert({name = stash.name, count = stash.count})
	return stash
end

local function find_items_around(entity)
	local collision = entity.prototype.collision_box or {left_top = {x = 0, y = 0}, right_bottom = {x = 0, y = 0}}
	return entity.surface.find_entities_filtered{name = "item-on-ground", area = {
		{x = entity.position.x - math.abs(collision.left_top.x) - 3, y = entity.position.y - math.abs(collision.left_top.y) - 3},
		{x = entity.position.x + math.abs(collision.right_bottom.x) + 3, y = entity.position.y + math.abs(collision.right_bottom.y) + 3}}}
end

local function spill_stack(entity, stack)
	if not (entity.valid and stack.valid_for_read) then
		return
	end
	entity.surface.spill_item_stack(entity.position, {name = stack.name, count = stack.count})
	local items = find_items_around(entity)
	if next(items) ~= nil then
		local count = (stack.count < #items) and stack.count or #items
		for i = 1, #items do
			local item = items[i]
			if item.valid and item.stack.name == stack.name and not item.to_be_deconstructed(entity.force) then
				item.order_deconstruction(entity.force)
				count = count - 1
			end
			if count <= 0 then
				break
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
				spill_stack(logicturret[1], stash)
			end
		end
	end
	if logicturret[2].has_items_inside() then
		local stash = logicturret[2].get_inventory(1)[1]
		if stash.valid_for_read then
			spill_stack(logicturret[1], stash)
		end
	end
end

local function is_idle(logicturret)
	return (logicturret[2].logistic_network == nil or
	((logicturret[1].has_items_inside() or not logicturret[2].has_items_inside()) and
		logicturret[1].surface.find_nearest_enemy{position = logicturret[1].position, max_distance = logicturret[3], force = logicturret[1].force} == nil))
end

--Event handlers--
local function onTick(event)
	local checkidle = event.tick % 30 == global.Timer
	if checkidle == true then
		local list = global.IdleLogicTurrets
		local count = global.IdleCounter
		for i = #list - (count - 1), 1, -5 do
			local logicturret = list[i]
			if not (logicturret[1].valid and logicturret[2].valid) then
				if logicturret[2].valid then
					logicturret[2].destroy()
				end
				table.remove(global.IdleLogicTurrets, i)
			elseif not is_idle(logicturret) == true then
				global.LogicTurrets[#global.LogicTurrets + 1] = logicturret
				table.remove(global.IdleLogicTurrets, i)
			end
		end
		global.IdleCounter = (count % 5) + 1
	end
	local list = global.LogicTurrets
	local count = global.Counter
	for i = #list - (count - 1), 1, -30 do
		local logicturret = list[i]
		if not (logicturret[1].valid and logicturret[2].valid) then
			if logicturret[2].valid then
				logicturret[2].destroy()
			end
			table.remove(global.LogicTurrets, i)
		elseif checkidle == true and is_idle(logicturret) == true then
			global.IdleLogicTurrets[#global.IdleLogicTurrets + 1] = logicturret
			table.remove(global.LogicTurrets, i)
		elseif not logicturret[1].has_items_inside() and logicturret[2].has_items_inside() then
			insert_ammo(logicturret)
		end
	end
	global.Counter = (count % 30) + 1
end

local function toggle_timer(on)
	if next(global.LogicTurrets) ~= nil or next(global.IdleLogicTurrets) ~= nil then
		return
	end
	if on == true then
		global.Counter = 1
		global.IdleCounter = 1
		global.Timer = math.random(30) - 1
		script.on_event(defines.events.on_tick, onTick)
	else
		global.Counter = -1
		global.IdleCounter = -1
		global.Timer = -1
		script.on_event(defines.events.on_tick, nil)
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
	toggle_timer(true)
	global.LogicTurrets[#global.LogicTurrets + 1] = logicturret
end

local function onDeath(event)
	if global.LogicTurretConfig[event.entity.name] == nil then
		return
	end
	local t, i = lookup_turret(event.entity)
	if t == nil then
		return
	else
		local logicturret = t[i]
		if logicturret[1].valid and logicturret[2].valid then
			for player_index in pairs(global.TurretGUI) do
				if logicturret[1] == global.TurretGUI[player_index].logicturret[1] then
					local player = game.players[player_index]
					if player.gui.center["MMT-gui"] ~= nil and player.gui.center["MMT-gui"].valid then
						player.gui.center["MMT-gui"].destroy()
					end
					global.TurretGUI[player_index] = nil
				end
			end
			logicturret[2].destroy()
		end
		table.remove(t, i)
		toggle_timer()
	end
end

local function onMined(event)
	if global.LogicTurretConfig[event.entity.name] == nil then
		return
	end
	local t, i = lookup_turret(event.entity)
	if t == nil then
		return
	else
		local logicturret = t[i]
		if logicturret[1].valid and logicturret[2].valid then
			if logicturret[2].has_items_inside() then
				if event.player_index == nil or not (game.players[event.player_index].character and game.players[event.player_index].character.valid) then
					spill_stack(logicturret[1], logicturret[2].get_inventory(1)[1])
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
			for player_index in pairs(global.TurretGUI) do
				if logicturret[1] == global.TurretGUI[player_index].logicturret[1] then
					local player = game.players[player_index]
					if player.gui.center["MMT-gui"] ~= nil and player.gui.center["MMT-gui"].valid then
						player.gui.center["MMT-gui"].destroy()
					end
					global.TurretGUI[player_index] = nil
				end
			end
			logicturret[2].destroy()
		end
		table.remove(t, i)
		toggle_timer()
	end
end

local function onMarked(event)
	if global.LogicTurretConfig[event.entity.name] == nil then
		return
	end
	local t, i = lookup_turret(event.entity)
	if t == nil then
		return
	elseif t[i][2].valid then
		t[i][2].clear_request_slot(1)
	end
end

local function onUnmarked(event)
	if global.LogicTurretConfig[event.entity.name] == nil then
		return
	end
	local t, i = lookup_turret(event.entity)
	if t == nil then
		local relogicturret = add_logistics(event.entity)
		if relogicturret == nil then
			return
		end
		toggle_timer(true)
		global.LogicTurrets[#global.LogicTurrets + 1] = relogicturret
	else
		local logicturret = t[i]
		if logicturret[1].valid and logicturret[2].valid then
			logicturret[2].set_request_slot({name = global.LogicTurretConfig[logicturret[1].name].ammo, count = global.LogicTurretConfig[logicturret[1].name].count}, 1)
		end
	end
end

--Configuration--
--Testing surface
local function decorate_workshop(workshop, area)
	if game.surfaces[workshop.name] == nil or not game.surfaces[workshop.name].valid then
		script.on_event(defines.events.on_chunk_generated, nil)
		return
	end
	local nature = workshop.find_entities(area)
	for i = 1, #nature do
		if nature[i].valid and nature[i].type ~= "player" then
			nature[i].destroy()
		end
	end
	local flooring = {}
	for x = area.left_top.x, area.right_bottom.x - 1 do
		for y = area.left_top.y, area.right_bottom.y - 1 do
			local tile = {name = "concrete", position = {x, y}}
			flooring[#flooring + 1] = tile
		end
	end
	workshop.set_tiles(flooring)
	script.on_event(defines.events.on_chunk_generated, nil)
end

local function onChunkGenerated(event)
	if event.surface == game.surfaces["MMT-workshop"] then
		decorate_workshop(event.surface, event.area)
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
		width = 1,
		height = 1,
		peaceful_mode = true})
	local area = {left_top = {x = 0, y = 0}, right_bottom = {x = 32, y = 32}}
	decorate_workshop(workshop, area)
	workshop.request_to_generate_chunks({16, 16}, 0)
	script.on_event(defines.events.on_chunk_generated, onChunkGenerated)
	return workshop
end

--Sanititazion
local function validate_ammo(turret, ammo)
	local surface = build_workshop()
	local position = surface.find_non_colliding_position(turret, {16, 16}, 16, 1)
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
	if turret == nil or ammo == nil or count == nil or not (type(turret) == "string" and type(ammo) == "string" and type(count) == "number") or count < 1 then
		return nil, nil, nil
	end
	local config = nil
	local NewTurret = nil
	local UpdatedTurret = nil
	if global.LogicTurretConfig[turret] ~= nil and global.LogicTurretConfig[turret].ammo == ammo then
		if global.LogicTurretConfig[turret].count ~= count then
			count = math.min(math.floor(count), game.item_prototypes[ammo].stack_size)
			UpdatedTurret = true
		end
		config = {ammo = ammo, count = count}
	elseif game.entity_prototypes[turret] ~= nil and game.entity_prototypes[turret].type == "ammo-turret" and
		game.item_prototypes[ammo] ~= nil and game.item_prototypes[ammo].type == "ammo" and
		validate_ammo(turret, ammo) == true then
			if global.LogicTurretConfig[turret] == nil then
				NewTurret = true
			else
				UpdatedTurret = true
			end
			count = math.min(math.floor(count), game.item_prototypes[ammo].stack_size)
			config = {ammo = ammo, count = count}
	end
	return config, NewTurret, UpdatedTurret
end

local function check_config()
	local turretlist = {}
	local LogisticTurret = LogisticTurret or {}
	for turret in pairs(LogisticTurret) do
		turretlist[turret] = turretlist[turret] or LogisticTurret[turret]
	end
	local RemoteTurretConfig = RemoteTurretConfig
	if AllowRemoteCalls ~= false then
		for turret, config in pairs(RemoteTurretConfig) do
			turretlist[turret] = turretlist[turret] or config
		end
	end
	if UseBobsDefault == true and game.entity_prototypes["bob-sniper-turret-1"] ~= nil then
		local entities = game.entity_prototypes
		local BobsDefault = BobsDefault or {ammo = "piercing-bullet-magazine", count = 5}
		for turret, entity in pairs(entities) do
			if entity.type == "ammo-turret" and string.match(turret, "bob%-") ~= nil then
				turretlist[turret] = turretlist[turret] or BobsDefault
			end
		end
	end
	local NewTurrets = {}
	local UpdatedTurrets = {}
	for turret, config in pairs(turretlist) do
		turretlist[turret], NewTurrets[turret], UpdatedTurrets[turret] = validate_config(turret, config.ammo, config.count)
	end
	for turret in pairs(global.LogicTurretConfig) do
		if turretlist[turret] == nil then
			UpdatedTurrets[turret] = true
		end
	end
	global.LogicTurretConfig = turretlist
	return NewTurrets, UpdatedTurrets
end

--GUI--
local function open_gui(player)
	local request = global.TurretGUI[player.index].logicturret[2].get_request_slot(1) or {name = "MMT-gui-empty", count = 0}
	local root = player.gui.center.add{type = "frame", name = "MMT-gui", direction = "vertical", style = "inner_frame_in_outer_frame_style"}
		root.add{type = "flow", name = "MMT-title", direction = "horizontal", style = "flow_style"}
			root["MMT-title"].add{type = "label", name = "MMT-name", style = "MMT-name", caption = global.TurretGUI[player.index].logicturret[1].localised_name}
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
	local turret = global.TurretGUI[player_index].logicturret[1].name
	if global.TurretGUI[player_index]["cashe"] == nil then
		global.TurretGUI[player_index]["cashe"] = request
	else
		request = global.TurretGUI[player_index]["cashe"]
	end
	local ammo_table = gui.add{type = "table", name = "MMT-ammo", colspan = 5, style = "slot_table_style"}
		ammo_table.add{type = "checkbox", name = "MMT-icon-empty", style = "MMT-icon-MMT-gui-empty", state = true}
		for i = 1, #global.IconSets[turret] do
			local ammo = global.IconSets[turret][i]
			if ammo == request and request ~= "MMT-gui-empty" then
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
	if ammo == "MMT-gui-empty" or count == nil or count < 1 then
		if gui.parent["MMT-ammo"] ~= nil and global.TurretGUI[player.index]["cashe"] ~= "MMT-gui-empty" then
			gui.parent["MMT-ammo"]["MMT-icon-"..(global.TurretGUI[player.index]["cashe"])].style = "MMT-icon-"..global.TurretGUI[player.index]["cashe"]
		end
		global.TurretGUI[player.index]["request"] = "clear"
		global.TurretGUI[player.index]["cashe"] = "MMT-gui-empty"
		player.print({"MMT-gui-request-clear"})
	else
		if gui.parent["MMT-ammo"] ~= nil then
			if global.TurretGUI[player.index]["cashe"] ~= "MMT-gui-empty" then
				gui.parent["MMT-ammo"]["MMT-icon-"..(global.TurretGUI[player.index]["cashe"])].style = "MMT-icon-"..global.TurretGUI[player.index]["cashe"]
			end
			gui.parent["MMT-ammo"]["MMT-icon-"..ammo].style = "MMT-ocon-"..ammo
		end
		count = math.min(math.floor(count), game.item_prototypes[ammo].stack_size)
		global.TurretGUI[player.index]["request"] = {ammo = ammo, count = count}
		global.TurretGUI[player.index]["cashe"] = ammo
		player.print({"MMT-gui-request-save"})
	end
end

local function close_gui(player)
	if player.gui.center["MMT-gui"] == nil or not player.gui.center["MMT-gui"].valid then
		if global.TurretGUI[player.index] ~= nil then
			global.TurretGUI[player.index] = nil
		end
		return
	elseif global.TurretGUI[player.index] == nil or not (global.TurretGUI[player.index].logicturret[1].valid and global.TurretGUI[player.index].logicturret[2].valid) then
		if player.gui.center["MMT-gui"].valid then
			player.gui.center["MMT-gui"].destroy()
		end
		global.TurretGUI[player.index] = nil
		return
	end
	if global.TurretGUI[player.index]["request"] ~= nil then
		local logicturret = global.TurretGUI[player.index].logicturret
		local t, i = lookup_turret(logicturret[1])
		if global.TurretGUI[player.index]["request"] == "clear" then
			if logicturret[2].has_items_inside() then
				local stash = insert_ammo(logicturret)
				if stash.valid_for_read then
					spill_stack(logicturret[1], stash)
				end
			end
			t[i]["custom-request"] = "clear"
			logicturret[2].clear_request_slot(1)
		else
			local ammo = global.TurretGUI[player.index]["request"].ammo
			local count = global.TurretGUI[player.index]["request"].count
			local request = logicturret[2].get_request_slot(1)
			if ammo == global.LogicTurretConfig[logicturret[1].name].ammo and count == global.LogicTurretConfig[logicturret[1].name].count then
				t[i]["custom-request"] = nil
			else
				t[i]["custom-request"] = {ammo = ammo, count = count}
			end
			if request == nil or (request.name == ammo and request.count ~= count) then
				logicturret[2].set_request_slot({name = ammo, count = count}, 1)
				if logicturret[1].has_items_inside() then
					local inv = logicturret[1].get_inventory(1)
					for j = 1, #inv do
						local stash = inv[j]
						if stash.valid_for_read and stash.name ~= ammo then
							spill_stack(logicturret[1], stash)
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
	elseif global.TurretGUI[player.index] == nil or not (global.TurretGUI[player.index].logicturret[1].valid and global.TurretGUI[player.index].logicturret[2].valid) then
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
	local turret = player.surface.find_entities_filtered{area = {event.position, event.position}, type = "ammo-turret", force = player.force}[1]
	if turret == nil or global.LogicTurretConfig[turret.name] == nil or turret.to_be_deconstructed(player.force) then
		close_gui(player)
		return
	end
	local t, i = lookup_turret(turret)
	if t == nil or not (t[i][1].valid and t[i][2].valid) then
		close_gui(player)
		return
	else
		close_gui(player)
		global.TurretGUI[event.player_index] = {logicturret = t[i]}
		open_gui(player)
	end
end

--GUI Icons
local function make_iconsets()
	local ammosets = {}
	for turret, entity in pairs(game.entity_prototypes) do
		if entity.type == "ammo-turret" then
			ammosets[turret] = {}
			for ammo, item in pairs(game.item_prototypes) do
				if item.type == "ammo" and not item.has_flag("hidden") and validate_ammo(turret, ammo) == true then
					ammosets[turret][#ammosets[turret] + 1] = ammo
				end
			end
		end
	end
	global.IconSets = ammosets
end

--Remote interface--
local add_logistic_turret = function(turret, ammo, count)
	if turret ~= nil and ammo ~= nil and count ~= nil then
		RemoteTurretConfig[turret] = {ammo = ammo, count = count}
	end
end

--Loader--
local function update_requests(UpdatedTurrets)
	if next(UpdatedTurrets) == nil then
		return
	end
	local lists = {global.LogicTurrets, global.IdleLogicTurrets}
	for i = 1, #lists do
		local t = lists[i]
		for j = #t, 1, -1 do
			local logicturret = t[j]
			if not (logicturret[1].valid and logicturret[2].valid) then
				if logicturret[2].valid then
					logicturret[2].destroy()
				end
				table.remove(t, j)
			elseif UpdatedTurrets[logicturret[1].name] ~= nil then
				if global.LogicTurretConfig[logicturret[1].name] == nil then
					if logicturret[2].has_items_inside() then
						local stash = insert_ammo(logicturret)
						if stash.valid_for_read then
							spill_stack(logicturret[1], stash)
						end
					end
					logicturret[2].destroy()
					table.remove(t, j)
				else
					local ammo = global.LogicTurretConfig[logicturret[1].name].ammo
					local count = global.LogicTurretConfig[logicturret[1].name].count
					local request = logicturret[2].get_request_slot(1)
					if logicturret["custom-request"] ~= nil then
						if logicturret["custom-request"] ~= "clear" and logicturret["custom-request"].ammo == ammo and logicturret["custom-request"].count == count then
							logicturret["custom-request"] = nil
						end
					elseif request == nil or (request.name == ammo and request.count ~= count) then
						logicturret[2].set_request_slot({name = ammo, count = count}, 1)
						if logicturret[1].has_items_inside() then
							local inv = logicturret[1].get_inventory(1)
							for k = 1, #inv do
								local stash = inv[k]
								if stash.valid_for_read and stash.name ~= ammo then
									spill_stack(logicturret[1], stash)
								end
							end
						end
					elseif request.name ~= ammo then
						logicturret[2].set_request_slot({name = ammo, count = count}, 1)
						fully_eject(logicturret)
					end
				end
			end
		end
	end
end

local function find_turrets(NewTurrets)
	if next(NewTurrets) == nil then
		return
	end
	for _, surface in pairs(game.surfaces) do
		for chunk in surface.get_chunks() do
			if surface.is_chunk_generated({chunk.x, chunk.y}) then
				local area = {{x = chunk.x * 32, y = chunk.y * 32}, {x = (chunk.x + 1) * 32, y = (chunk.y + 1) * 32}}
				for name in pairs(NewTurrets) do
					for _, turret in pairs(surface.find_entities_filtered{area = area, name = name}) do
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

local function set_autofill(lists)
	if remote.interfaces["af"] == nil or next(global.LogicTurretConfig) == nil then
		return
	end
	local AutofillSets = {remote.call("af", "getItemArray", "ammo-bullets"), remote.call("af", "getItemArray", "ammo-rockets"), remote.call("af", "getItemArray", "ammo-shells")}
	local turretlist = {}
	for i = 1, #lists do
		for turret in pairs(lists[i]) do
			turretlist[turret] = global.LogicTurretConfig[turret]
		end
	end
	for turret, config in pairs(turretlist) do
		local ammo = config.ammo
		local found = false
		for j = 1, #AutofillSets do
			for k = 1, #AutofillSets[j] do
				if ammo == AutofillSets[j][k] then
					ammo = AutofillSets[j]
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
	local NewTurrets, UpdatedTurrets = check_config()
	update_requests(UpdatedTurrets)
	find_turrets(NewTurrets)
	set_autofill({NewTurrets, UpdatedTurrets})
	for player_index in pairs(global.TurretGUI) do
		local player = game.players[player_index]
		if player.gui.center["MMT-gui"] ~= nil and player.gui.center["MMT-gui"].valid then
			player.gui.center["MMT-gui"].destroy()
		end
		global.TurretGUI[player_index] = nil
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
	if next(global.LogicTurrets) ~= nil or next(global.IdleLogicTurrets) ~= nil then
		global.Counter = 1
		global.IdleCounter = 1
		global.Timer = math.random(30) - 1
		script.on_event(defines.events.on_tick, onTick)
	else
		global.Counter = -1
		global.IdleCounter = -1
		global.Timer = -1
		script.on_event(defines.events.on_tick, nil)
	end
end

local function onLoad()
	RemoteTurretConfig = {}
	remote.add_interface("Macromanaged_Turrets", {add_logistic_turret = add_logistic_turret})
	script.on_event(defines.events.on_built_entity, onBuilt)
	script.on_event(defines.events.on_tick, onStart)
end

local function onInit()
	global.LogicTurretConfig = {}
	global.LogicTurrets = {}
	global.IdleLogicTurrets = {}
	global.TurretGUI = {}
	global.IconSets = {}
	make_iconsets()
	onLoad()
end

local function onModChanges(data)
	if data == nil or data.mod_changes == nil then
		return
	end
	if data.mod_changes["autofill"] ~= nil then
		local old_version = data.mod_changes["autofill"].old_version
		local new_version = data.mod_changes["autofill"].new_version
		if old_version == nil then
			set_autofill({global.LogicTurretConfig})
		end
	end
	if data.mod_changes["Macromanaged_Turrets"] ~= nil then
		local old_version = data.mod_changes["Macromanaged_Turrets"].old_version
		local new_version = data.mod_changes["Macromanaged_Turrets"].new_version
		if old_version == nil then
			onInit()
		else
			if old_version < "1.0.2" then
				global.IdleLogicTurrets = {}
				for i = 1, #global.LogicTurrets do
					table.insert(global.LogicTurrets[i], 3, math.min(global.LogicTurrets[i][1].prototype.turret_range * 2.5, 100))
				end
			end
		end
	end
	make_iconsets()
end

script.on_init(onInit)
script.on_load(onLoad)
script.on_configuration_changed(onModChanges)