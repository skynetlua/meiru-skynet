local skynet = require "skynet"
local function __dump(t, d, dups)
    if type(t) ~= "table" then 
        return t and tostring(t) or "nil"
    end
    dups = dups or {}
    if dups[t] then
        return tostring(t)
    else
        dups[t] = true
    end
    d = (d or 0) + 1
    if d > 10 then
        return "..."
    else
        local retval = {}
        for k, v in pairs(t) do
            table.insert(retval, string.format("%s%s = %s,\n", string.rep("\t", d), k, __dump(v, d, dups)))
        end
        return "{\n"..table.concat(retval)..string.format("%s}", string.rep("\t", d - 1))
    end
end

function skynet.log(...)
    local sid = 1
    if type(select(1, ...)) == "boolean" then
        sid = 2
    end
    local logs = {}
    for i = sid, select('#', ...) do
        local v = select(i, ...)
        if type(v) == "table" then
            table.insert(logs, __dump(v, 0))
        else
            table.insert(logs, v and tostring(v) or "nil")
        end
    end
    local output
    if sid == 2 then
        output = table.concat(logs," ") .. "\n" .. debug.traceback()
    else
        output = table.concat(logs," ")
    end
    local info = debug.getinfo(2)
    if info then
        info = "[".. SERVICE_NAME..":"..(info.name or info.what)..os.date(":%y-%m-%d %X") .."]"
    end
 	skynet.error(info, output)
end

local debug = skynet.getenv("debug")
if debug then
    os.mode = 'dev'
end
require "meiru.extension"

