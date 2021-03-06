local blank_sprite =
{
	filename = MOD_GFX.."blank.png",
	priority = "very-low",
	width = 0,
	height = 0
}

local default_wire_distance = 9
local minimum_wire_distance = 0.03125
local main_offset = {x = 0.1 + 0.03125, y = 0.25 + 0.03125}
local connection_point =
{
	wire =
	{
		red = {main_offset.x + 0.15, main_offset.y + 0.1},
		green = {main_offset.x + 0.1, main_offset.y}
	},
	shadow =
	{
		red = {main_offset.x + 0.25, main_offset.y + 0.1},
		green = {main_offset.x + 0.2, main_offset.y}
	}
}

local function get_circuit_connector_sprites()
	if settings.startup[MOD_PREFIX.."show-circuit-connector"].value then
		return
		{
			connector_main =
			{
				filename = "__base__/graphics/entity/circuit-connector/circuit-connector-main.png",
				priority = "low",
				width = 17,
				height = 15,
				x = 63,
				y = 63,
				shift = main_offset,
				scale = 0.75
			},
			led_red =
			{
				filename = "__base__/graphics/entity/circuit-connector/circuit-connector-led-red.png",
				priority = "low",
				width = 17,
				height = 15,
				x = 43,
				y = 33,
				shift = {main_offset.x, main_offset.y - 0.09375},
				scale = 0.75
			},
			led_green =
			{
				filename = "__base__/graphics/entity/circuit-connector/circuit-connector-led-green.png",
				priority = "low",
				width = 17,
				height = 15,
				x = 43,
				y = 33,
				shift = {main_offset.x, main_offset.y - 0.09375},
				scale = 0.75
			},
			led_blue =
			{
				filename = "__base__/graphics/entity/circuit-connector/circuit-connector-led-blue.png",
				priority = "low",
				width = 17,
				height = 15,
				x = 46,
				y = 51,
				shift = main_offset,
				scale = 0.75
			},
			logistic_animation =
			{
				filename = "__base__/graphics/entity/circuit-connector/circuit-connector-logistic-animation.png",
				priority = "low",
				width = 43,
				height = 43,
				frame_count = 15,
				line_length = 4,
				blend_mode = "additive",
				shift = {0.13125, 0.25}
			},
			led_light = {intensity = 0.6, size = 0.675},
			red_green_led_light_offset = {main_offset.x, main_offset.y - 0.09375},
			blue_led_light_offset = main_offset
		}
	end
end

data:extend(
{
	{
		type = "logistic-container",
		name = MOD_PREFIX.."logistic-turret-bin",
		icon = MOD_GFX.."module.png",
		icon_size = 32,
		flags = {"not-blueprintable", "not-deconstructable", "not-on-map", "not-repairable", "placeable-off-grid"},
		max_health = 1,
		collision_mask = {"not-colliding-with-itself"},
		collision_box = {{0, 0}, {0, 0}},
		selection_box = {{-0.2, -0.05}, {0.45, 0.6}},
		alert_when_damaged = false,
		selectable_in_game = false,
		allow_copy_paste = false,
		scale_info_icons = false,
		render_not_in_network_icon = false,
		inventory_size = 1,
		logistic_mode = "active-provider",
		picture = blank_sprite
	},
	{
		type = "logistic-container",
		name = MOD_PREFIX.."logistic-turret-chest",
		icon = MOD_GFX.."module.png",
		icon_size = 32,
		flags = {"not-deconstructable", "not-on-map", "not-repairable", "placeable-off-grid", "player-creation"},
		max_health = 1,
		collision_mask = {"layer-11"},
		collision_box = {{0, 0}, {0, 0}},
		selection_box = {{-0.2, -0.05}, {0.45, 0.6}},
		alert_when_damaged = false,
		selectable_in_game = false,
		allow_copy_paste = false,
		scale_info_icons = false,
		render_not_in_network_icon = false,
		inventory_size = 1,
		logistic_mode = "requester",
		num_logistic_slots = 1,
		picture = blank_sprite,
		circuit_wire_connection_point = connection_point,
		circuit_wire_max_distance = minimum_wire_distance
	},
	{
		type = "constant-combinator",
		name = MOD_PREFIX.."logistic-turret-combinator",
		icon = MOD_GFX.."module.png",
		icon_size = 32,
		flags = {"not-blueprintable", "not-deconstructable", "not-on-map", "not-repairable", "placeable-off-grid"},
		max_health = 1,
		collision_mask = {"not-colliding-with-itself"},
		collision_box = {{0, 0}, {0, 0}},
		selection_box = {{-0.2, -0.05}, {0.45, 0.6}},
		alert_when_damaged = false,
		selectable_in_game = false,
		allow_copy_paste = false,
		item_slot_count = 10,
		sprites = {north = blank_sprite, east = blank_sprite, south = blank_sprite, west = blank_sprite},
		activity_led_sprites = {north = blank_sprite, east = blank_sprite, south = blank_sprite, west = blank_sprite},
		activity_led_light_offsets = {{0, 0}, {0, 0}, {0, 0}, {0, 0}},
		circuit_wire_connection_points = {connection_point, connection_point, connection_point, connection_point},
		circuit_wire_max_distance = minimum_wire_distance
	},
	{
		type = "lamp",
		name = MOD_PREFIX.."logistic-turret-interface",
		icon = MOD_GFX.."module.png",
		icon_size = 32,
		flags = {"not-blueprintable", "not-deconstructable", "not-on-map", "not-repairable", "placeable-off-grid"},
		minable = {mining_time = 0.5},
		max_health = 1,
		collision_mask = {"water-tile", "item-layer", "object-layer", "player-layer"},
		collision_box = {{0, 0}, {0, 0}},
		selection_box = {{-0.2, -0.05}, {0.45, 0.6}},
		alert_when_damaged = false,
		allow_copy_paste = false,
		energy_source =
		{
			usage_priority = "secondary-input",
			render_no_network_icon = false,
			render_no_power_icon = false
		},
		energy_usage_per_tick = "0kW",
		picture_on = blank_sprite,
		picture_off = blank_sprite,
		circuit_wire_connection_point = connection_point,
		circuit_wire_max_distance = default_wire_distance,
		circuit_connector_sprites = get_circuit_connector_sprites()
	},
	{
		type = "logistic-container",
		name = MOD_PREFIX.."logistic-turret-memory",
		icon = MOD_GFX.."module.png",
		icon_size = 32,
		flags = {"not-deconstructable", "not-on-map", "not-repairable", "placeable-off-grid", "player-creation"},
		max_health = 1,
		collision_mask = {"layer-13"},
		collision_box = {{0, 0}, {0, 0}},
		selection_box = {{-0.2, -0.05}, {0.45, 0.6}},
		alert_when_damaged = false,
		selectable_in_game = false,
		allow_copy_paste = false,
		scale_info_icons = false,
		render_not_in_network_icon = false,
		inventory_size = 1,
		logistic_mode = "requester",
		num_logistic_slots = 5,
		picture = blank_sprite,
		circuit_wire_connection_point = connection_point,
		circuit_wire_max_distance = default_wire_distance,
		circuit_connector_sprites = get_circuit_connector_sprites()
	}
})