
local skynet = require "skynet"
local meiru  = require "meiru.meiru"

local config = {
    name = 'meiru', 
    description = 'meiru web framework', 
    keywords = 'meiru skynet lua skynetlua'
}
local test_path   = skynet.getenv("test_path")
local views_path  = string.format("%s/assets/view", test_path)
local static_path = string.format("%s/assets/public", test_path)
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

local tree = app.treeprint()
log("treeprint\n", tree)

local memory_info = dump_memory()
log("memory_info\n", memory_info)

return app

