
local skynet = require "skynet.manager"
local stm    = require "skynet.stm"
local QueueMap = require "meiru.lib.queuemap"
local Markdown = require "meiru.lib.md"

local __queue_map = QueueMap(300)
local function markdown_file(path)
    if os.mode == 'dev' then
        local content = io.readfile(path)
        if not content then
            return
        end
        local obj = stm.new(skynet.pack(Markdown(content)))
        return stm.copy(obj)
    end
    local obj = __queue_map.get(path)
    if obj == false then
        return
    end
    if not obj then
        local content = io.readfile(path)
        if not content then
            __queue_map.set(path, false)
            return
        end
        local md_data = Markdown(content)
        obj = stm.new(skynet.pack(md_data))
        __queue_map.set(path, obj)
    end
    return stm.copy(obj)
end


local command = {}
function command.markdown_file(file_path)
    return markdown_file(file_path)
end


skynet.start(function()
    skynet.dispatch("lua", function(_,_,cmd,...)
        local f = command[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            assert(false, "error no support cmd"..cmd)
        end
    end)
end)