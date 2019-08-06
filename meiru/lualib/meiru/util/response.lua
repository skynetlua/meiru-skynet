
local Cookie = include("cookie", ...)
local Coder = include(".role.coder", ...)
local json  = Coder("json")

local file_types = {
    ['css']  = "text/css",
    ['html'] = "text/html",
    ['jpg']  = "image/jpeg",
    ['png']  = "image/png",
    ['js']   = "text/javascript",
    ['json'] = "text/json",
    ['svg']  = "text/xml",
    ['less'] = "text/css",
    ['ico']  = "image/x-icon",
    ['txt']  = "text/plain",
    ['woff'] = true,
}

return function(app, res)
    local self = {
        app        = app,
        rawres     = res,
        statuscode = 200,
        headers    = {},
        cookies    = {},
        viewdatas  = {},
        blackboard = {},
        layout = "layout",
    }
    local response = self

    function response.render(view, option)
        local data = self.viewdatas
        if option then
            for k,v in pairs(option) do
                data[k] = v
            end
        end
        self.render_params = {
            view = view,
            data = data
        }
        self.set_type('html')
        self.flush()
        return true
    end

    function response.render404(body)
        self.set_type('txt')
        self.send(404, body)
    end

    function response.renderError(body, code)
        self.send(code, body)
    end

    function response.get_layout()
        return self.layout
    end

    function response.set_layout(layout)
        self.layout = layout
    end

    function response.data(key, value)
        self.viewdatas[key] = value
    end

    function response.send(code, body)
        if type(code) == "number" then
            self.status(code)
        else
            body = body or code
        end
        self.body = body
        self.flush()
        return true
    end

    function response.set_cookie(key, value)
        -- self.cookies = self.cookies or {}
        self.cookies[key] = value
    end

    function response.set_cookies(cookies)
        for k,v in pairs(cookies) do
            self.set_cookie(k, v)
        end
    end

    function response.set_header(key, value)
        self.headers[key] = value
    end

    function response.set(key, value)
        self.headers[key] = value
    end

    function response.set_cache_timeout(max_age)
        -- self.set_header('Expires', os.gmtdate(os.time()+max_age))
        -- self.set_header('Cache-Control', "public")
        self.set_header('Cache-Control', "max-age="..max_age)
    end

    function response.type(ctype)
        -- ..";charset=utf-8"
        self.set_header('content-type', ctype)
    end

    function response.set_type(ctype)
        for i=#ctype,1,-1 do
            if string.byte(ctype, i) == string.byte(".") then
                ctype = string.sub(ctype, i+1)
                break
            end
        end
        local content_type = file_types[ctype]
        if content_type == true then
            return
        end
        assert(content_type, "response.set_type:"..ctype)
        self.set_header('content-type', content_type..";charset=utf-8")
        -- 
    end

    function response.redirect(url)
        self.statuscode = 302
        self.set_header('Location', url)
        -- <meta http-equiv="refresh" content="0; url=">
        self.flush()
        return true
    end

    function response.json(obj)
        self.set_type('json')
        self.body = json.encode(obj)
        self.flush()
        return true
    end

    function response.status(statuscode)
        self.statuscode = statuscode
        return self
    end

    function response.get_statuscode()
        return self.statuscode
    end

    function response.get_body()
        return self.body
    end

    function response.get_headers()
        return self.headers
    end

    function response.flush()
         if self.cookies and next(self.cookies) then
            if not self.cookies['Domain'] then
                self.cookies['Domain'] = self.app.get('host') or ""
            end
            self.set_header('Set-Cookie', Cookie.cookie_encode(self.cookies))
        end
        self.set_header('date', os.gmtdate())
        self.is_end = true
    end

    function response.__response(code, body, headers)
        self.rawres.response(code, body, headers)
    end

    return response
end



