local Cookie = include("cookie", ...)
local platform = include("platform", ...)
local cached = include(".db.cached", ...)

local kMSessionKey = "mrsid"


local function create_session(sessionid, req)
    local cur_time = os.time()
    local session = {
        sessionid = sessionid,
        referer   = req.get('referer'),
        create_at = cur_time,
        req_url   = req.rawurl,
        vdata = {
            useragent = req.get('user-agent'),
        }
    }
    local cookies = {
        Expires = cur_time+3600*24*365,
        Secure = false,
        -- HttpOnly = true,
        Path = "/"
    }
    session.cookies = cookies
    return session
end

local function get_data_from_cache(sessionid)
    return cached.get(sessionid)
end

local function save_data_to_cache(sessionid, session)
    assert(sessionid)
    assert(session)
    cached.set(sessionid, session)
end

local function load_session(sessionid)
    local session = get_data_from_cache(sessionid)
    if session and session.sessionid == sessionid then
        if not session.cookies or os.time() > session.cookies.Expires then
            session = nil
        end
    else
        session = nil
    end
    return session
end

return function(req, res, session_secret)
    local Session = {}
    local self = Session
    function Session.ctor(req, res, session_secret)
        local sessionid = req.get_signcookie(kMSessionKey)
        local is_new
        if not sessionid then
            sessionid = Cookie.generate_sessionid()
            is_new = true
        end
        self.sessionid = sessionid
        local session = load_session(sessionid)
        if not session then
            session = create_session(sessionid, req)
            if is_new then
                session.cookies[kMSessionKey] = Cookie.cookie_sign(sessionid, session_secret)
                res.set_cookies(session.cookies)
            end
        else
            if session.vdata.useragent ~= req.get('user-agent') then
                log("session useragent change")
                log("session req.get('user-agent') =", req.get('user-agent'))
                log("session session.vdata.useragent =", session.vdata.useragent)
            end
        end
        session.update_at = os.time()
        self.session = session
        self.save_session()
    end

    function Session.set(key, val)
        self.session[key] = val
        self.save_session()
    end

    function Session.get(key)
        return self.session[key]
    end

    function Session.save_session()
        save_data_to_cache(self.sessionid, self.session)
    end

    function Session.make_cookie(key, val)
        local auth_token = tostring(val)
        res.set_cookie(key, auth_token)
        local cookies = {
            Expires = os.time()+3600*24*365,
            Secure  = false,
            Path    = "/",
        }
        res.set_cookies(cookies)
    end

    function Session.clear_cookie(key)
        res.set_cookie(key, "")
        -- local cookies = {
        --     Expires  = os.time()+3600*24*365,
        --     Secure   = false,
        --     Path     = "/",
        -- }
        -- res.set_cookies(cookies)
    end

    function Session.get_cookie(key)
        return res.set_cookie(key, "")
    end

    self.ctor(req, res, session_secret)
    return self
end

