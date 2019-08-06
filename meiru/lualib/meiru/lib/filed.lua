local ok, skynet = pcall(require, "skynet.manager")
skynet = ok and skynet

-----------------------------------------
-----------------------------------------
local filed = {}

if skynet then
local stm = require "skynet.stm"
local QueueMap = include("queuemap", ...)
local queue_map = QueueMap(500)
-----------------------------------------------
-----------------------------------------------
local agent_sum = 4
local AGENTS = {}
for i=1,agent_sum do
    AGENTS[i] = ".filed"..i
end

local function get_agent(path)
    local file_name = io.filename(path)
    local sum = 0
    for i=1,#file_name do
        sum = sum+string.byte(file_name, i)
    end
    local idx = sum%(#AGENTS)+1
    return AGENTS[idx]
end

setmetatable(filed, {__index = function(t,cmd)
    local f = function(path, ...)
        local filed = get_agent(path)
    	return skynet.call(filed, "lua", cmd, path, ...)
    end
    t[cmd] = f
    return f
end})

function filed.file_read(path)
    local filed = get_agent(path)
    local copy_obj = skynet.call(filed, "lua", "file_read", path)
    if copy_obj then
        local ref_obj = stm.newcopy(copy_obj)
        local ok, ret = ref_obj(skynet.unpack)
        if ok then
            return ret
        end
    end
end

function filed.file_md5(path)
    if os.mode ~= 'dev' then
        local file_md5 = queue_map.get(path)
        if file_md5 then
            return file_md5
        end
    end
    local filed = get_agent(path)
    local file_md5 = skynet.call(filed, "lua", "file_md5", path)
    if file_md5 then
        queue_map.set(path, file_md5)
        return file_md5
    end
end

function filed.init()
    for _,agent in ipairs(AGENTS) do
        local filed = skynet.newservice("meiru/filed", agent)
        skynet.name(agent, filed)
    end
end

else

-----------------------------------------------
-----------------------------------------------
local platform = include(".util.platform", ...)

function filed.file_read(path)
    return io.readfile(path)
end

function filed.file_md5(path)
    local content = io.readfile(path)
    if content then
        return platform.md5(content)
    end
end

function filed.init()
end

end

return filed 