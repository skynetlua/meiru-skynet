
----------------------------------------------
--Com
----------------------------------------------
local Com = class("Com")

function Com:ctor()
	self.name = name
end

function Com:match(req, res)
end

function Com:get_name()
	if not self.name then
		return self.__cname
	end
end

function Com:get_node()
    return self.node
end

function Com:set_node(node)
    self.node = node
    self.meiru  = node:get_meiru()
end

function Com:set_meiru(meiru)
	self.meiru = meiru
end

return Com
