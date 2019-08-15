local Com = include("com", ...)
local Cookie = include(".util.cookie", ...)

----------------------------------------------
--ComCookie
----------------------------------------------
local ComCookie = class("ComCookie", Com)

function ComCookie:ctor()
end

function ComCookie:match(req, res)
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
end

return ComCookie
