
return function(app, req)
    req = req or {}
    local self = {
        app       = app,
        rawreq    = req,
        ip        = req.ip,
        addr      = req.addr,
        rawmethod = req.method,
        rawbody   = req.body,
        rawurl    = req.url or "/",
        rawheader = req.header or {},
        method    = string.lower(req.method) or "get",
        -- path      = req.path or "/",
    }
    local request =  self

    function request.get(key)
        if self.header then
            return self.header[key]
        end
        return self.rawheader[key]
    end

    -----------------------------------
    -- cookie
    -----------------------------------
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
    
    -----------------------------------
    -- csrf
    -----------------------------------
    function request.get_body_csrf()
        return self.body and self.body._csrf
    end

    function request.get_header_csrf()
        local check_csrf = (self.query and self.query._csrf)
            or self.header['csrf-token']
            or self.header['xsrf-token']
            or self.header['x-csrf-token']
            or self.header['x-xsrf-token']
        return check_csrf
    end
    return request
end
