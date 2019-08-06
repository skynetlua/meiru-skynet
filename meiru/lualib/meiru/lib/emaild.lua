local skynet = require "skynet"

local _maild

local thread_queue = {}

skynet.fork(function()
    _maild = skynet.uniqueservice("meiru/lib/emaild")
    for _,thread in ipairs(thread_queue) do
        skynet.wakeup(thread)
    end
    thread_queue = nil
end)

local emaild = {}

setmetatable(emaild, {__index = function(t,cmd)
	if not _maild then
		local thread = coroutine.running()
        table.insert(thread_queue, thread)
        skynet.wait(thread)
	end
    local f = function(...)
    	return skynet.call(_maild, "lua", cmd, ...)
    end
    t[cmd] = f
    return f
end})

return emaild 