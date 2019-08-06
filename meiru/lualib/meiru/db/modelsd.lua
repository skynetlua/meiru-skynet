local QueueMap = include(".lib.queuemap", ...)

local ok, skynet = pcall(require, "skynet")
skynet = ok and skynet

-------------------------------------
-------------------------------------
local _maps = {}

local function get_data(tblName, id)
	local map = _maps[tblName]
	if not map then
		return
	end
	return map.get(id)
end

local function set_data(tblName, id, data)
	local map = _maps[tblName]
	if not map then
		map = QueueMap(1000)
		_maps[tblName] = map
	end
	map.set(id, data)
end

local function remove_data(tblName, id)
	local map = _maps[tblName]
	if not map then
		return
	end
	return map.remove(id)
end

local function remove_datas(tblName, ids)
	local map = _maps[tblName]
	if not map then
		return
	end
	return map.removes(ids)
end

--------------------------------------
--------------------------------------
local _modelsd

local command = {}

if skynet then
skynet.fork(function()
	_modelsd = skynet.uniqueservice("meiru/modelsd")
end)
setmetatable(command, {__index = function(t,cmd)
    local f = function(...)
    	return skynet.call(_modelsd, "lua", cmd, ...)
    end
    t[cmd] = f
    return f
end})
end


function command.get(tblName, id)
	local data = get_data(tblName, id)
	if data then
		return table.clone(data)
	end
	if skynet then
		local data = skynet.call(_modelsd, "lua", "get", tblName, id)
		set_data(tblName, id, data)
		return table.clone(data)
	end
end

function command.gets(tblName, ids)
	local datas = {}
	local req_ids = {}
	local data
	for i,id in ipairs(ids) do
		data = get_data(tblName, id)
		if data then
			table.insert(datas, table.clone(data))
		else
			table.insert(req_ids, id)
		end
	end
	if #req_ids == 0 then
		return datas
	end
	if skynet then
		local ndatas = skynet.call(_modelsd, "lua", "gets", tblName, req_ids)
		for _,data in ipairs(ndatas) do
			assert(data.id)
			table.insert(datas, table.clone(data))
			set_data(tblName, data.id, data)
		end
		return datas
	else
		return datas
	end
end

function command.update(tblName, id, data)
	local save_data = get_data(tblName, id)
	if save_data then
		for k,v in pairs(data) do
			save_data[k] = v
		end
	end
	if skynet then
		return skynet.call(_modelsd, "lua", "update", tblName, id, data)
	end
end

function command.updates(tblName, ids, data)
	for _,id in ipairs(ids) do
		local save_data = get_data(tblName, id)
		if save_data then
			for k,v in pairs(data) do
				save_data[k] = v
			end
		end
	end
	if skynet then
		return skynet.call(_modelsd, "lua", "updates", tblName, ids, data)
	end
end

function command.clear(tblName)
	_queues[tblName] = nil
end

function command.remove(tblName, id, ...)
	remove_data(tblName, id)
	if skynet then
		return skynet.call(_modelsd, "lua", "remove", tblName, id, ...)
	end
end

function command.removes(tblName, ids, ...)
	remove_datas(tblName, ids)
	if skynet then
		return skynet.call(_modelsd, "lua", "removes", tblName, ids, ...)
	end
end

function command.delete(tblName, id, ...)
	remove_data(tblName, id)
	if skynet then
		return skynet.call(_modelsd, "lua", "delete", tblName, id, ...)
	end
end

function command.deletes(tblName, ids, ...)
	remove_datas(tblName, ids)
	if skynet then
		return skynet.call(_modelsd, "lua", "deletes", tblName, ids, ...)
	end
end

return command 

