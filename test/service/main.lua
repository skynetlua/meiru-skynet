local skynet = require "skynet.manager"
local filed = require "meiru.lib.filed"

skynet.start(function()
    filed.init()
    local dbgport = skynet.getenv("dbgport")
    if dbgport then
        skynet.newservice("debug_console", "0.0.0.0", dbgport)
    end

    local httpd = skynet.newservice("meiru/serverd")
    skynet.call(httpd, "lua", "start", {
        port = skynet.getenv("http_port"),
        services = {
            ['http'] = "web", 
            ['ws'] = "ws"
        },
        instance = 1,
    })

    local httpsd = skynet.newservice("meiru/serverd")
    skynet.call(httpsd, "lua", "start", {
        port = skynet.getenv("https_port"),
        services = {
            ['https'] = "web", 
            ['wss'] = "ws"
        },
        instance = 1,
    })

end)



