
local PQueue = include(".lib.pqueue", ...)

local ok, skynet = pcall(require, "skynet")
skynet = ok and skynet

local _queue = PQueue(function(a, b)
	return b.deadline - a.deadline
end)

local kMCacheInterval = 60*10

local _caches = {}
local function get_data(key)
	local cache = _caches[key]
	if cache then
		if os.time() <= cache.deadline then
			return cache.data
		end
		_caches[key] = nil
		_queue.remove(cache)
	end
end

local function set_data(key, data, timeout)
	if timeout == 0 or timeout > kMCacheInterval then
		timeout = kMCacheInterval
	end
	local cache = {
		data = data,
		key = key,
		deadline = os.time()+timeout
	}
	_caches[key] = cache
	local tmp = _queue.peek()
	while tmp do
		if os.time()>tmp.deadline or _queue.count() > 1000 then
			_queue.poll()
			_caches[tmp.key] = nil
		else
			break
		end
		tmp = _queue.peek()
	end
	_queue.offer(cache)
end

-------------------------------------------------
--cached
-------------------------------------------------
local cached = {}

if skynet then

local _cached
local thread_queue = {}

skynet.fork(function()
	_cached = skynet.uniqueservice("meiru/cached")
	for _,thread in ipairs(thread_queue) do
    	skynet.wakeup(thread)
	end
	thread_queue = nil
end)

local function set(key, data, timeout)
	assert(type(key) == 'string' and #key > 0)
	set_data(key, data, timeout or 0)
	if timeout and timeout < kMCacheInterval then
		return
	end
	data = skynet.packstring(data)
	return skynet.call(_cached, "lua", "set", key, data, timeout)
end

local function get(key)
	assert(type(key) == 'string' and #key > 0)
	local data = get_data(key)
	if data then
		return data
	end
	local data, deadline = skynet.call(_cached, "lua", "get", key)
	if data then
		data = skynet.unpack(data)
		set_data(key, data, deadline-os.time())
	end
	return data
end

setmetatable(cached, {__index = function(t, cmd)
	if not _cached then
		local thread = coroutine.running()
        table.insert(thread_queue, thread)
        skynet.wait(thread)
	end
	if cmd == 'set' then
		t[cmd] = set
    	return set
	elseif cmd == 'get' then
		t[cmd] = get
    	return get
	end
    local f = function(...)
    	return skynet.call(_cached, "lua", cmd, ...)
    end
    t[cmd] = f
    return f
end})


else

function cached.set(key, data, timeout)
	assert(type(key) == 'string' and #key > 0)
	set_data(key, data, timeout or 0)
end

function cached.get(key)
	assert(type(key) == 'string' and #key > 0)
	local data = get_data(key)
	if data then
		return data
	end
end

end

return cached 
