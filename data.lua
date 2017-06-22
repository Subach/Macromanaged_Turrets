ModGFX = "__Macromanaged_Turrets__/graphics/"
ModPrefix = "MMT-"

require("prototypes.entities")
require("prototypes.items")
require("prototypes.style")

data:extend(
{
	{
		type = "custom-input",
		name = ModPrefix.."close-gui",
		key_sequence = "E",
		consuming = "none"
	},
	{
		type = "custom-input",
		name = ModPrefix.."select-remote",
		key_sequence = "SHIFT + R",
		consuming = "all"
	}
})