
local skynet = require "skynet"
local meiru  = require "meiru.meiru"
local api_router = require "api_router"

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

router.get('/', function(req, res)
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

router.get('/system', function(req, res)
    local tab = req.query.tab
    local item = req.query.item 
    res.set_layout(nil)
    return res.render('system/index', {
        cur_tab  = tab,
        cur_item = item,
    })
end)


---------------------------------------
--app
---------------------------------------
local filed = require "meiru.lib.filed"

local function staticFile(filePath)
    local file_md5 = filed.file_md5(static_path..filePath)
    if file_md5 then
        if filePath:find('?') then
            filePath = filePath.."&fv="..file_md5
        else
            filePath = filePath.."?fv="..file_md5
        end
    else
        log("staticFile not find filePath =", static_path..filePath)
    end
    return filePath
end

local app = meiru.create_app()
app.set("views_path", views_path)
app.set("static_url", static_url)
app.set("session_secret", "meiru")

--配置viewdata，方便在view elua中访问数据
app.data("config", config)
app.data("staticFile", staticFile)

--静态资源路由
app.use(meiru.static('/public', static_path))

--api 借口
local api_node = api_router.node()
app.use(api_node)

--动态网页路由
app.use(router.node())

--什么都找不到，就路由静态资源
app.use(meiru.static('/', static_path))

--打开浏览器访问足迹
app.open_footprint()

--运行
app.run()

--把所有的路由树打印出来
local tree = app.treeprint()
log("treeprint\n", tree)

--打印所有的对象
local memory_info = dump_memory()
log("memory_info\n", memory_info)

return app

