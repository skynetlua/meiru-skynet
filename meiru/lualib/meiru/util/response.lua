
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
        header     = {},
        viewdata   = {},
        layout     = "layout",
    }
    local response = self

    function response.render(view, option)
        local data = self.viewdata
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

    function response.get_layout()
        return self.layout
    end

    function response.set_layout(layout)
        self.layout = layout
    end

    function response.data(key, value)
        self.viewdata[key] = value
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

    function response.set_header(key, value, multi)
        if multi then
            local values = self.header[key]
            if values then
                if type(values) ~= 'table' then
                    local tmp = {values}
                    values = tmp
                end
                table.insert(values, value)
            else
                self.header[key] = value
            end
        else
            self.header[key] = value
        end
    end

    function response.set(key, value, multi)
        response.set_header(key, value, multi)
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
    end

    function response.redirect(url)
        self.statuscode = 302
        self.set_header('Location', url)
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

    function response.get_header()
        return self.header
    end

    -----------------------------------
    -- cookie
    -----------------------------------
    -- local cookie = {
    --     key = "cookie_name",
    --     value = "cookie_value",
    --     ['Secure'] = true,
    --     ['HttpOnly'] = true,
    --     ['Expires'] = "Thurs, 15 Aug 2019 15:59:38 GMT",
    --     ['Domain'] = "www.skynetlua.com",
    --     ['Path'] = "/",
    --     ['max-age'] = 365*24*3600,
    -- }
    --example:
    -- response.set_cookie("cookie_name", "value", "cookie_value")
    -- response.set_cookie("cookie_name", "max-age", 3600)
    -- response.set_cookie("cookie_name", "HttpOnly", true)
    function response.set_cookie(name, key, value)
        self.cookies = self.cookies or {}
        if type(name) == 'table' then
            assert(not key and not value)
            local cookie = name
            self.cookies[cookie.key] = cookie
        else
            if key == "value" then
                if not value then
                    self.cookies[name] = nil
                else
                    local cookie = self.cookies[name]
                    if not cookie then
                        cookie = {}
                        self.cookies[name] = cookie
                    end
                    cookie.key   = name
                    cookie.value = value
                end
            else
                local cookie = self.cookies[name]
                if cookie then
                    cookie[key] = value
                end
            end
        end
    end

    function response.set_cookies(cookies)
        for _,cookie in pairs(cookies) do
            self.set_cookie(cookie)
        end
    end

    function response.flush()
         if self.cookies then
            for _,cookie in pairs(self.cookies) do
                self.set_header('Set-Cookie', Cookie.cookie_encode(cookie), true)
            end
        end
        self.set_header('date', os.gmtdate())
        self.is_end = true
    end

    function response.__response(code, body, header)
        self.rawres.response(code, body, header)
    end

    return response
end



