local ok, skynet = pcall(require, "skynet")
skynet = ok and skynet

-----------------------------------------
-----------------------------------------
local markdownd = {}

if skynet then

local stm = require "skynet.stm"
local QueueMap = include("queuemap", ...)
local __queue_map = QueueMap(30)
-----------------------------------------------
-----------------------------------------------
local _markdownd

local thread_queue = {}

skynet.fork(function()
    _markdownd = skynet.uniqueservice("meiru/markdownd")
    for _,thread in ipairs(thread_queue) do
        skynet.wakeup(thread)
    end
    thread_queue = nil
end)

local function markdown_file(path)
    if os.mode == 'dev' then
        local copy_obj = skynet.call(_markdownd, "lua", "markdown_file", path)
        if copy_obj then
            local ref_obj = stm.newcopy(copy_obj)
            local ok, retval = ref_obj(skynet.unpack)
            if ok then
                return retval
            end
        end
        return
    end
    local retval = __queue_map.get(path)
    if retval then
        return retval
    end
    local copy_obj = skynet.call(_markdownd, "lua", "markdown_file", path)
    if copy_obj then
        local ref_obj = stm.newcopy(copy_obj)
        local ok, retval = ref_obj(skynet.unpack)
        if ok then
            __queue_map.set(path, retval)
            return retval
        end
    end
end

setmetatable(markdownd, {__index = function(t, cmd)
    if not _markdownd then
        local thread = coroutine.running()
        table.insert(thread_queue, thread)
        skynet.wait(thread)
    end
    if cmd == 'markdown_file' then
        t[cmd] = markdown_file
        return markdown_file
    end
    local f = function(...)
        return skynet.call(_markdownd, "lua", cmd, ...)
    end
    t[cmd] = f
    return f
end})


else

-----------------------------------------------
-----------------------------------------------
local Markdown = include("md", ...)

function markdownd.markdown_file(path)
    local content = io.readfile(path)
    if not content then
        return
    end
    return Markdown(content)
end


end

return markdownd 
