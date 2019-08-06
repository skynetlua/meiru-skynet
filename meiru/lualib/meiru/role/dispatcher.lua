
---------------------------------------------------
--Dispatcher
---------------------------------------------------
local Dispatcher = class("Dispatcher")

function Dispatcher:ctor(user)
	self.user = user

	self.commands = {}
	self.requests = {}
	self.triggers = {}
end

function Dispatcher:add_modules(modules)
	for k,v in pairs(modules) do
		self:add_module(k, v)
	end
end

function Dispatcher:add_module(name, m)
	if m.command then
		for k,v in pairs(m.command) do
			assert(not self.commands[k], "["..name.."]module command error:"..k)
			self.commands[k] = v
		end
	end
	if m.request then
		for k,v in pairs(m.request) do
			assert(not self.requests[k], "["..name.."]module request error:"..k)
			self.requests[k] = v
		end
	end
	if m.trigger then
		for k,v in pairs(m.trigger) do
			assert(not self.triggers[k], "["..name.."]module trigger error:"..k)
			self.triggers[k] = v
		end
	end
end

function Dispatcher:command(name, ...)
	local command = self.commands[name]
	if command then
		command(self.user, ...)
	else
		log("Dispatcher:dispatch_command not implement:", name)
	end
end

function Dispatcher:request(name, proto)
	local request = self.requests[name]
	if request then
		request(self.user, proto)
	else
		log("Dispatcher:dispatch_request not implement:", name)
	end
end

function Dispatcher:trigger(name, data)
	for _,trigger in pairs(self.triggers) do
		trigger(self.user, name, data)
	end
end

return Dispatcher
