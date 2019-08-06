local Node = include("node", ...)

local Root = class("Root", Node)

function Root:ctor(name, meiru)
	Node.ctor(self, name, meiru)
end

function Root:add_com(com)
    assert(false)
end

function Root:add_child(child)
    assert(child.name == "node_req" or child.name == "node_res")
    Node.add_child(self, child)
end

function Root:footprint(depth)
    depth = (depth or 0)+1
    local rets = {}
    if self.path then
        table.insert(rets, string.rep("++", depth) .. self.name..":"..self.path)
    else
        table.insert(rets, string.rep("++", depth) .. self.name)
    end
    if self.children then
        for _,child in ipairs(self.children) do
            local ret = child:footprint(depth)
            if ret then
                table.insert(rets, ret)
            end
        end
    end
    return table.concat(rets, "\n")
end

return Root
