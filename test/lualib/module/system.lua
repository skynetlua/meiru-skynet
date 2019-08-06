local systemd = require "meiru.lib.systemd"

---------------------------------------------
--command
---------------------------------------------
local command = {}

function command:system_test()
	log("command:system_test==========>>")


end

---------------------------------------------
--request
---------------------------------------------
local request = {}

function request:system_stat_req(proto)
	
	local stat_info = systemd.stat()
	self:send("system_stat_res", stat_info)
end

---------------------------------------------
--trigger
---------------------------------------------
local trigger = {}

function trigger:system_test()
	log("trigger:system_test==========>>")


end


return {command = command, request = request, trigger = trigger}