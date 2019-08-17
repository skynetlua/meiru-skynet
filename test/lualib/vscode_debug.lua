
package.path = "../../meiru/lualib/?.lua;" .. package.path

os.mode = 'dev'
local extension = require "meiru.extension"
local meiru     = require "meiru.meiru"

local config = {
    name = 'meiru', 
    description = 'meiru web framework', 
    keywords = 'meiru skynet lua skynetlua'
}
local assets_path = "../assets"
local views_path  = string.format("%s/view", assets_path)
local static_path = string.format("%s/public", assets_path)
local static_url  = "/"

---------------------------------------
--router
---------------------------------------
local router = meiru.router()

router.get('/index', function(req, res)
    local data = {
        topic = {
            title = "hello elua"
        },
        topics = {
            {
                title = "topic1"
            },{
                title = "topic2"
            }
        }
    }
    function data.helloworld(...)
        if select("#", ...) > 0 then
            return "come from helloworld function"..table.concat(... , ", ")
        else
            return "come from helloworld function"
        end
    end
    res.render('index', data)
end)

---------------------------------------
--app
---------------------------------------
local app = meiru.create_app()
app.set("views_path", views_path)
app.set("static_url", static_url)
app.set("session_secret", "meiru")
app.use(meiru.static('/public', static_path))

app.data("config", config)

app.use(router.node())
app.run()

---------------------------------------
--dispatch
---------------------------------------
local req = {
    protocol = 'http',
    method   = "get",
    url      = "/index",
    header  = {},
    body     = "",
}

local res = {
    response = function(code, bodyfunc, header)
        log("response", code, header)
    end,
}

app.dispatch(req, res)

-- local memory_info = dump_memory()
-- log("memory_info\n", memory_info)

-- local foot = app.footprint()
-- log("footprint\n", foot)

-- local chunk = app.chunkprint()
-- log("chunkprint\n", chunk)
