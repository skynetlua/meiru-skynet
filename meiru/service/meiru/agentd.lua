
local skynet = require "skynet"
local handle_web = require "meiru.net.handle_web"

local table  = table
local string = string

local web
local ws

---------------------------------------------
--protocol
---------------------------------------------
local master
local config
local protocol
local services

local function handle_web_cb(is_ws, ...)
    if is_ws then
        assert(ws, "no open ws/wss service")
        local ret = ws.dispatch(...)
        if ret then
            return true
        end
    else
        assert(web, "no open http/https service")
        web.dispatch(...)
    end
end

---------------------------------------------
--slave service
---------------------------------------------
local command = {}
function command.start(data)
    master = data.master
    config = data.config
    services = config.services
    protocol = services.protocol

    local lua_file = services['http'] or services['https']
    if type(lua_file) == "string" then
        web = require(lua_file)
    end

    lua_file = services['ws'] or services['wss']
    if type(lua_file) == "string" then
        ws = require(lua_file)
    end
end

function command.exit()
end

function command.stop()
end

function command.enter(fd, addr)
    handle_web(fd, addr, protocol, handle_web_cb)
end

skynet.start(function()
    skynet.dispatch("lua", function(_,_,cmd,...)
        local f = command[cmd]
        if f then
            skynet.ret(skynet.pack(f(...)))
        else
            assert(false,"error no support cmd"..cmd)
        end
    end)
end)


