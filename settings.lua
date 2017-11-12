local MOD_PREFIX = "MMT-"

data:extend(
{
	{
		type = "bool-setting",
		name = MOD_PREFIX.."show-circuit-connector",
		setting_type = "startup",
		default_value = true,
		order = "a"
	},
	{
		type = "int-setting",
		name = MOD_PREFIX.."tick-interval",
		setting_type = "runtime-global",
		default_value = 30,
		minimum_value = 1,
		order = "a"
	},
--[[ --TODO: desync
	{
		type = "int-setting",
		name = MOD_PREFIX.."time-factor",
		setting_type = "runtime-global",
		default_value = 5,
		minimum_value = 5,
		order = "a-a"
	},
--]]
	{
		type = "bool-setting",
		name = MOD_PREFIX.."allow-remote-config",
		setting_type = "runtime-global",
		default_value = true,
		order = "b"
	},
	{
		type = "bool-setting",
		name = MOD_PREFIX.."uninstall-mod",
		setting_type = "runtime-global",
		default_value = false,
		order = "c"
	},
	{
		type = "string-setting",
		name = MOD_PREFIX.."quickpaste-mode",
		setting_type = "runtime-per-user",
		default_value = "Match ammo category",
		allowed_values = {"Match ammo category", "Match turret name"},
		allow_blank = false,
		auto_trim = true,
		order = "a"
	},
	{
		type = "bool-setting",
		name = MOD_PREFIX.."quickpaste-circuitry",
		setting_type = "runtime-per-user",
		default_value = true,
		order = "a-a"
	},
	{
		type = "bool-setting",
		name = MOD_PREFIX.."use-classic-GUI",
		setting_type = "runtime-per-user",
		default_value = false,
		order = "b"
	}
})