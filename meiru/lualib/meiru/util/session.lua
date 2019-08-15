local Cookie = include("cookie", ...)
local platform = include("platform", ...)
local cached = include(".db.cached", ...)
local uuid  = include(".lib.uuid", ...)

local kMSessionKey = "mrsid"
local kMSessionTimeout = 3600*24*365


local function get_data_from_cache(sessionid)
    return cached.get(sessionid)
end

local function save_data_to_cache(sessionid, session)
    assert(sessionid)
    assert(session)
    cached.set(sessionid, session)
end

local function session_create(req, sessionid)
    -- log("session_create sessionid =", sessionid)
    local session = {
        sessionid = sessionid,
        create_at = os.time(),
        req_url   = req.rawurl,
        referer   = req.get('referer'),
        useragent = req.get('user-agent'),
    }
    local cookie = {
        ['Expires'] = os.time()+kMSessionTimeout,
        ['max-age'] = kMSessionTimeout
    }
    local session_secret = req.app.get("session_secret") or "meiru"
    cookie.key   = kMSessionKey
    cookie.value = Cookie.cookie_sign(sessionid, session_secret)
    session.cookie = cookie
    return session
end

local function session_load(sessionid)
    local session = get_data_from_cache(sessionid)
    if session and session.sessionid == sessionid then
        if not session.cookie or os.time() > session.cookie.Expires then
            session = nil
        end
    else
        session = nil
    end
    return session
end

----------------------------------------------
----------------------------------------------
return function(req, res)
    local Session = {}
    local self = Session
    function Session.ctor(req, res)
        local sessionid = req.get_signcookie(kMSessionKey)
        if not sessionid then
            sessionid = uuid()
        end
        self.sessionid = sessionid
        local session = session_load(sessionid)
        if session then
            if session.useragent ~= req.get('user-agent') then
                -- log("session useragent change")
                -- log("session req.get('user-agent') =", req.get('user-agent'))
                -- log("session session.useragent =", session.useragent)
                session = nil
            end
        end
        if not session then
            session = session_create(req, sessionid)
            res.set_cookie(session.cookie)

            self.session = session
            session.update_at = os.time()
            self.save_session()
        else
            self.session = session
            session.update_at = os.time()
        end
    end

    function Session.set(key, val)
        self.session[key] = val
        self.save_session()
    end

    function Session.get(key)
        local val = self.session[key]
        return val
    end

    function Session.save_session()
        save_data_to_cache(self.sessionid, self.session)
    end

    self.ctor(req, res)
    return self
end

