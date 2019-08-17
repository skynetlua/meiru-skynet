local Com    = include("com", ...)
local Render = include(".util.render", ...)
local filed = include(".lib.filed", ...)

local views_path

local function get_res(path)
    local content = filed.file_read(views_path.."/"..path..".html")
    if not content then
        content = filed.file_read(views_path.."/"..path..".lua")
        if not content then
            print("[ERROR]not exit path:", views_path.."/"..path..".lua", debug.traceback())
            assert(false)
            return
        end
    end
    return content
end

-----------------------------------------------
--ComRender
----------------------------------------------
local ComRender = class("ComRender", Com)

function ComRender:ctor()
end

function ComRender:match(req, res)
	if res.render_params then
		views_path = req.app.get("views_path")
        local render
        if os.mode == 'dev' then
            render = Render(get_res, req.app.get_viewdatas(), 2)
        else
            render = Render(get_res, req.app.get_viewdatas())
        end
		local csrf = res.res_csrf
		local data = res.render_params.data or {}
		data.csrf = csrf

		local ok, body = render(res.render_params.view, data)
        if not ok then
            req.app.__render_error = body
            assert(false)
            return false
        end
		local layout = res.get_layout()
		if layout and #layout > 0 then
			data.body = body
    		ok, res.body = render(layout, data)
            if not ok then
                req.app.__render_error = body
                assert(false)
                return false
            end
    	else
    		res.body = body
    	end
	end
end


return ComRender
