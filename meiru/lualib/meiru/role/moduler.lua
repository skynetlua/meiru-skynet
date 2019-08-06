
local Moduler = class("Moduler")

function Moduler:ctor(dispatcher, module_path)
	self.modules = {}
end

function Moduler:add_module(name, m)
	self.modules[name] = m
end

function Moduler:get_modules()
	return self.modules
end

return Moduler