
return function(app, req)
    req = req or {}
    local self = {
        app       = app,
        rawreq    = req,
        rawmethod = req.method,
        rawbody   = req.body,
        rawurl    = req.url or "/",
        rawheaders= req.headers or {},
        method    = string.lower(req.method) or "get",
        -- path      = req.path or "/",
    }
    local request =  self

    -- setmetatable(request, {__index = function(t, k, v)
    --     log("request k =", k, "v =", v)
    -- end})

    function request.get(key)
        if self.headers then
            return self.headers[key]
        end
        return self.rawheaders[key]
    end

    function request.get_cookie(key)
        if not self.cookies then
            return
        end
        return self.cookies[key]
    end
    
    function request.get_signcookie(key)
        if not self.signcookies then
            return
        end
        return self.signcookies[key]
    end
    
    function request.get_body_csrf()
        return self.body and self.body._csrf
    end

    function request.get_header_csrf()
        local check_csrf = (self.query and self.query._csrf)
            or self.headers['csrf-token']
            or self.headers['xsrf-token']
            or self.headers['x-csrf-token']
            or self.headers['x-xsrf-token']
        return check_csrf
    end
    return request
end
