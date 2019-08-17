local Com = include("com", ...)
local Cookie = include(".util.cookie", ...)
local Session = include(".util.session", ...)

----------------------------------------------
--ComSession
----------------------------------------------
local ComSession = class("ComSession", Com)

function ComSession:ctor()
end

function ComSession:match(req, res)
	if req.session then
		return
	end
	if not req.cookies then
		if not req.get('cookie') then
			req.cookies = {}
		    req.signcookies = {}
		else
			local session_secret = req.app.get("session_secret") or "meiru"
			local cookies, signcookies = Cookie.cookie_decode(req.get('cookie'), session_secret)
			req.cookies = cookies or {}
		    req.signcookies = signcookies or {}
		end
	end
	req.session = Session(req, res)
	req.sessionid = req.session.sessionid
end



return ComSession
