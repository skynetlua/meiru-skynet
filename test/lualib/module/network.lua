
---------------------------------------------
--command
---------------------------------------------
local command = {}

function command:network_open()
	log("command:network_open==========>>")
	
end

function command:network_message(data)
	log("command:network_message==========>>#data =", #data)

end

function command:network_ping()
	log("command:network_ping==========>>")

end

function command:network_pong()
	log("command:network_pong==========>>")

end

function command:network_close(code, reason)
	log("command:network_close==========>>code =", code, "reason =", reason)

end

function command:network_error(msg)
	log("command:network_error==========>> msg =", msg)

end

function command:network_warning(msg)
	log("command:network_warning==========>> msg =", msg)

end

---------------------------------------------
--trigger
---------------------------------------------
local trigger = {}

function trigger:network_test()
	log("trigger:network_test==========>>")


end

return {command = command, trigger = trigger}