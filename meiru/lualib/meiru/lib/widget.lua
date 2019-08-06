local Widget = {}

local meta = {__index = Widget}

local table = table
local string = string
local assert = assert

function Widget.create(name, ...)
	assert(name)
	local obj = {
		_name = name
	}
	setmetatable(obj, meta)
	if select("#",...)>0 then
		obj:set(...)
	end
	return obj
end

function Widget:set(...)
	local arg, atype
	for i=1,select("#",...) do
		arg = select(i, ...)
		atype = type(arg)
		if atype == "string" then
			self._text = arg
		elseif atype == "number" then
			self._text = tostring(arg)
		elseif atype == "boolean" then
			self._text = tostring(arg)
		elseif atype == "table" then
			if getmetatable(arg) == meta then
				self._childs = self._childs or {}
				table.insert(self._childs, arg)
			else
				self._props = self._props or {}
				for k,v in pairs(arg) do
					assert(type(v) == "string" or type(v) == "number")
					self._props[k] = v
				end
			end
		else
			assert(false)
		end
	end
	return self
end

function Widget:addchild(child)
	self._childs = self._childs or {}
	table.insert(self._childs, child)
	return self
end

function Widget:new(...)
	local child = Widget.create(...)
	self:addchild(child)
	return child
end

function Widget:batch(name, args)
	for _,arg in ipairs(args) do
		local child = Widget.create(name)
		local atype = type(arg)
		if atype == "string" or atype == "number" then
			child:set(arg)
		elseif atype == "table" then
			child:set(table.unpack(arg))
		else
			assert(false)
		end
		self:addchild(child)
	end
	return self
end

function Widget:setprop(key, val, ...)
	self._props = self._props or {}
	local len = select("#",...)
	if len <= 0 then
		self._props[key] = val
	else
		assert(len%2 == 0)
		for i=1, len, 2 do
			self._props[select(i, ...)] = select(i+1, ...)
		end
	end
	return self
end

function Widget.echo(self)
	assert(self._name)
	if self._name == "txt" then
		local retval = self._text or ""
		if self._childs then
			for _,child in ipairs(self._childs) do
				retval = retval..child:echo()
			end
		end
		return retval
	end
	local retval = "<"..self._name.." "
	if self._props then
		for k,v in pairs(self._props) do
			if type(v) == "string" then
				retval = retval .. k ..'="'..v..'" '
			else
				retval = retval .. k .."="..v.." "
			end
		end
	end
	if not self._text and not self._childs then
		return retval.."/>"
	end
	retval = retval ..">".. (self._text or "")
	if self._childs then
		for _,child in ipairs(self._childs) do
			retval = retval.. child:echo()
		end
	end
	return retval.."</"..self._name..">"
end

function Widget.goodecho(self, sep, depth)
	assert(self._name)
	if self._name == "txt" then
		local retval = self._text or ""
		if self._childs then
			for _,child in ipairs(self._childs) do
				retval = retval.. child:goodecho(sep, depth + 1)
			end
		end
		return retval
	end
	sep = sep or "\n"
	depth = depth or 0
	local indent = string.rep("  ", depth)
	local props = ""
	if self._props then
		for k,v in pairs(self._props) do
			if type(v) == "string" then
				props = props ..k..'="'..v..'" '
			else
				props = props ..k..'='..v..' '
			end
		end
	end
	if not self._text and not self._childs then
		return indent .."<"..self._name.." "..props.."/>" .. sep
	end
	if self._name == 'pre' then
		sep = ""
	end
	local preseq = sep
	local suindent = indent
	local retval = self._text or ""
	if self._childs then
		for _,child in ipairs(self._childs) do
			retval = retval.. child:goodecho(sep, depth + 1)
		end
	else
		preseq = ""
		suindent = ""
	end
	return indent.."<"..self._name.." "..props..">"..preseq..retval..suindent.."</"..self._name..">"..sep
end

return Widget.create



