local _config = require("src/gui/config/event")

function _config:handler(event, ...)
	return self.dispatch[event](...)
end

return _config