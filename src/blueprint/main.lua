local _blueprint = require("src/blueprint/event")

function _blueprint:handler(event, ...)
	return self.dispatch[event](...)
end

return _blueprint