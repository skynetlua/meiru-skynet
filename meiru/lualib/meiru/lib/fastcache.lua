
---------------------------------------
--FiFoList
---------------------------------------
local FiFoList = class("FiFoList")

function FiFoList:ctor()
	self:clear()
end

function FiFoList:clear()
	self._emptyIdx = 1
	self._tailIdx = 1
	self._array = {}

	self._map = {}
	self._count = 0
end

function FiFoList:isexist(entry)
	local idx = self._map[entry]
	return idx
end

function FiFoList:push(entry)
	assert(entry and not self._map[entry])
	local idx = self._emptyIdx
	while idx>1 do
		if not self._array[idx-1] then
			idx = idx-1
		else
			if self._tailIdx > idx then
				self._tailIdx = idx
			end
			break
		end
	end
	self._array[idx] = entry
	self._map[entry] = idx

	self._emptyIdx = idx+1
	self._count = self._count+1
	return idx
end

function FiFoList:remove(entry)
	assert(entry)
	local idx = self._map[entry]
	if not idx then return end

	self._array[idx] = nil
	self._map[entry] = nil
	self._count = self._count-1
end

function FiFoList:move(entry)
	local idx = self._map[entry]
	if not idx then return end

	self:remove(entry)
	return self:push(entry)
end

function FiFoList:pop()
	local entry
	local tailIdx = self._tailIdx
	while tailIdx < self._emptyIdx do
		entry = self._array[tailIdx]
		if entry then
			self._array[tailIdx] = nil
			self._map[entry] = nil
			
			self._tailIdx = tailIdx+1
			self._count = self._count-1
			return entry
		end
		tailIdx = tailIdx+1
	end
end

function FiFoList:header()
	local entry
	while self._tailIdx < self._emptyIdx do
		entry = self._array[self._tailIdx]
		if entry then
			return entry
		else
			self._tailIdx = self._tailIdx+1
		end
	end
end

--------------------------------------
--数据条目
-------------------------------------
-- local ticker = skynet.now
local ticker = os.time

local Entry = class("Entry")

function Entry:ctor(key)
	self.key = assert(key)
	self.value = nil
	self.accessTime = 0
end

function Entry:setValue(value)
	self.value = value
end

function Entry:getValue()
	self.accessTime = ticker()
	return self.value
end

function Entry:reset()
	self.lastValue = self.value
	self.value = nil
	self.isLoadFailedTime = nil
end

function Entry:isEmpty()
	return self.value == nil
end

function Entry:isExpire(interval)
	return ticker() >= self.accessTime+interval
end

function Entry:makeLoadFailed()
	self.isLoadFailedTime = ticker()+3600
end

function Entry:isTimeoutFailed()
	if not self.isLoadFailedTime then
		return true
	end
	if ticker() >= self.isLoadFailedTime then
		self.isLoadFailedTime = nil
		return true
	end
end

----------------------------------------------
--Cache
----------------------------------------------
local Cache = class("Cache")

function Cache:ctor(loader, config)
	self.entrysMap = {}
	self.count = 0

	config = config or {}
	self.maximumSize = config.maximum_size
	self.expire_access = config.expire_access
	self.expire_loading = config.expire_loading or 2
	if self.expire_access then
		self.accessList = FiFoList.new()
	end
	if loader then
		self.waitLoadThreads = {}
		self.loader = loader
		loader:setCache(self)
	end
end

function Cache:getLoader()
	return self.loader
end

function Cache:isExpired(entry)
	return self.expire_access and entry:isExpire(self.expire_access)
end

function Cache:removeEntry(entry)
	local key = entry.key
	if self.entrysMap[key] then
		self.entrysMap[key] = nil
		self.count = self.count-1
		assert(self.count >= 0)
		if self.accessList then
			self.accessList:remove(entry)
		end
	end
end

function Cache:addEntry(entry)
	local key = entry.key
	if not self.entrysMap[key] then
		self.entrysMap[key] = entry
		self.count = self.count+1
		if self.accessList then
			self.accessList:push(entry)
		end
	else
		assert(entry == self.entrysMap[key])
	end
end

function Cache:removeExtraEntrys()
	local entry
	while self.accessList do
		entry = self.accessList:header()
		if not entry then break end

		if self.count > self.maximumSize or entry:isExpire(self.expire_access) then
			self:removeEntry(entry)
		else
			break
		end
	end
end

function Cache:createEntry(key)
	if self.maximumSize and self.count > self.maximumSize then
		self:removeExtraEntrys()
	end
	return Entry.new(key)
end

function Cache:set(key, value, ...)
	assert(false)
	local entry =self.entrysMap[key]
	if entry then
		entry:resetEmpty()
		entry.isLoadFaildTime = nil
	end
	self.loader:setValue(key, value, ...)
end

function Cache:getOrCreateEntry(key)
	local entry = self.entrysMap[key]
	if not entry then
		entry = self:createEntry(key)
		self:addEntry(entry)
	end
	return entry
end

function Cache:loadValue(entry, key, ...)
	if not self.loader.isMultiThread then
		local value = self.loader:getValue(key, ...)
		if value then
			entry:setValue(value)
		else
			entry:makeLoadFailed()
		end
		return
	end
	if entry.isLoading then
		if os.time() - entry.isLoading >= self.expire_loading then
			if #self.waitLoadThreads > 0 then
				local nextThread = table.remove(self.waitLoadThreads, 1)
				if nextThread then
					self.loader.wakeup(nextThread)
				end
			else
				self.curThread = nil
			end
		end
	end
	local thread = coroutine.running()
	if not self.curThread then
		self.curThread = thread
		entry.isLoading = os.time()
		local value = self.loader:getValue(key, ...)
		if value then
			entry:setValue(value)
		else
			entry:makeLoadFailed()
		end
		entry.isLoading = nil
	else
		table.insert(self.waitLoadThreads, thread)
		self.loader.wait(thread)
		self.curThread = thread
	end
	if #self.waitLoadThreads > 0 then
		local nextThread = table.remove(self.waitLoadThreads, 1)
		if nextThread then
			self.loader.wakeup(nextThread)
		end
	end
	self.curThread = nil
end

function Cache:get(key, ...)
	local entry = self.entrysMap[key]
	if entry and not entry.isLoading then
		if entry:isEmpty() then
			if not entry:isTimeoutFailed() then
				return
			end
		else
			if not self:isExpired(entry) then
				if self.accessList then
					self.accessList:move(entry)
				end
				return entry:getValue()
			end
		end
		--timeout reset data
		entry:reset()
	end
	if not self.loader then
		self:removeEntry(entry)
		return
	end
	if not entry then
		entry = self:createEntry(key)
		self:addEntry(entry)
	end
	self:loadValue(entry, key, ...)
	local value = entry:getValue()
	if value and self.accessList then
		self.accessList:move(entry)
	end
	return value
end

function Cache:getValid(key)
	local entry = self.entrysMap[key]
	if not entry then
		return
	end
	local value = entry:getValue()
	if value and self.accessList then
		self.accessList:move(entry)
	end
	return value
end

function Cache:setValid(key, value)
	local entry = self:getOrCreateEntry(key)
	if entry then
		entry:reset()
		entry:setValue(value)
	end
end

function Cache:remove(key)
	local entry = self.entrysMap[key]
	if entry then
		self:removeEntry(entry)
	end
end

function Cache:clear()
	self.entrysMap = {}
	self.count = 0
	if self.accessList then
		self.accessList:clear()
	end
end

----------------------------------------------
--Loader数据加载器
----------------------------------------------
local Loader = class("Loader")

function Loader:ctor(loadFunc)
	self.loadFunc = assert(loadFunc)
	assert(type(self.loadFunc) == "function")
end

function Loader:setCache(cache)
	self.cache = cache
	self.expire_loading = cache.expire_loading
end

function Loader:getValue(key, ...)
	local ok, value = xpcall(self.loadFunc, debug.traceback, key)
	return ok and value or ni
end

function Loader:setValue(key, value, ...)
	assert(false)
end

return {
	FiFoList = FiFoList,
	Cache    = Cache,
	Loader   = Loader,
}