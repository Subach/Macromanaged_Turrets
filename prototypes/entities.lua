require("config")

local function get_led(opts)
	return
	{
		filename = ModGFX.."connector.png",
		priority = "low",
		width = 13,
		height = 11,
		x = opts.x or 0,
		y = opts.y or 0,
		shift = {0.1, 0.25}
	}
end

local function get_circuit_connector_sprites(opts)
	if ShowCircuitConnector ~= false then
		return
		{
			connector_main =
			{
				filename = ModGFX.."connector.png",
				priority = "low",
				width = 13,
				height = 11,
				shift = {0.1, 0.25}
			},
			led_red = get_led{x = 14, y = 12},
			led_green = get_led{x = opts.x, y = 12},
			led_blue = get_led{x = 14},
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
			red_green_led_light_offset = {0.1, 0.25},
			blue_led_light_offset = {0.1, 0.375}
		}
	end
end

local blank_sprite =
{
	filename = ModGFX.."blank.png",
	priority = "very-low",
	width = 0,
	height = 0
}

local connection_point =
{
	wire =
	{
		red = {0.25, 0.225},
		green = {0.25, 0.355}
	},
	shadow =
	{
		red = {0.35, 0.225},
		green = {0.35, 0.355}
	}
}

data:extend(
{
	{
		type = "logistic-container",
		name = ModPrefix.."logistic-turret-chest",
		flags = {"not-blueprintable", "not-deconstructable", "not-on-map"},
		max_health = 0,
		collision_box = {{0, 0}, {0, 0}},
		selection_box = {{0.125, 0.275}, {0.125, 0.275}},
		selectable_in_game = false,
		inventory_size = 1,
		logistic_mode = "requester",
		picture = blank_sprite,
		circuit_wire_connection_point = connection_point,
		circuit_wire_max_distance = 0.05,
		circuit_connector_sprites = get_circuit_connector_sprites{x = 14}
	},
	{
		type = "logistic-container",
		name = ModPrefix.."logistic-turret-bin",
		flags = {"not-blueprintable", "not-deconstructable", "not-on-map"},
		max_health = 0,
		collision_box = {{0, 0}, {0, 0}},
		selection_box = {{0.125, 0.275}, {0.125, 0.275}},
		selectable_in_game = false,
		inventory_size = 1,
		logistic_mode = "active-provider",
		picture = blank_sprite
	},
	{
		type = "constant-combinator",
		name = ModPrefix.."logistic-turret-combinator",
		flags = {"not-blueprintable", "not-deconstructable", "not-on-map"},
		max_health = 0,
		collision_box = {{0, 0}, {0, 0}},
		selection_box = {{0.125, 0.275}, {0.125, 0.275}},
		selectable_in_game = false,
		item_slot_count = 10,
		sprites = {north = blank_sprite, east = blank_sprite, south = blank_sprite, west = blank_sprite},
		activity_led_sprites = {north = blank_sprite, east = blank_sprite, south = blank_sprite, west = blank_sprite},
		activity_led_light_offsets = {{0, 0}, {0, 0}, {0, 0}, {0, 0}},
		circuit_wire_connection_points = {connection_point, connection_point, connection_point, connection_point},
		circuit_wire_max_distance = 0.05
	},
	{
		type = "lamp",
		name = ModPrefix.."logistic-turret-interface",
		flags = {"not-blueprintable", "not-deconstructable", "not-on-map"},
		minable = {mining_time = 0.5},
		max_health = 0,
		collision_box = {{0, 0}, {0, 0}},
		selection_box = {{-0.2, -0.05}, {0.45, 0.6}},
		energy_source = {type = "electric", usage_priority = "secondary-input", render_no_network_icon = false, render_no_power_icon = false},
		energy_usage_per_tick = "0kW",
		picture_on = blank_sprite,
		picture_off = blank_sprite,
		circuit_wire_connection_point = connection_point,
		circuit_wire_max_distance = 7.5,
		circuit_connector_sprites = get_circuit_connector_sprites{}
	},
	{
		type = "flying-text",
		name = ModPrefix.."flying-text",
		flags = {"not-on-map", "placeable-off-grid"},
		time_to_live = 150,
		speed = 0.05
	}
})