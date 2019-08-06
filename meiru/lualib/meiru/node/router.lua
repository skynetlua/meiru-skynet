
local Node = include("node", ...)


local function create_node(method, path, ...)
    local node = Node.new("node_router")
    node:set_method(method)
    node:set_path(path)
    node:open_strict()
    node:open_terminal()

    for i = 1, select('#', ...) do
        local field = select(i, ...)
        node:add(field)
    end
    return node
end

local function create_router()
    local node_router = Node.new("node_routers")
    node_router:add("ComBody")
    node_router:add("ComCSRF")

    local router = {}
    function router.get(path, ...)
        assert(type(path) == "string")
        assert(select('#', ...) > 0)
        local node = create_node("get", path, ...)
        node_router:add_child(node)
    end

    function router.post(path, ...)
        assert(type(path) == "string")
        assert(select('#', ...) > 0)
        local node = create_node("post", path, ...)
        node_router:add_child(node)
    end

    -- function router.put(path, ...)
    --     assert(type(path) == "string")
    --     assert(select('#', ...) > 0)
    --     local node = create_node("put", path, ...)
    --     node_router:add_child(node)
    -- end

    -- function router.delete(path, ...)
    --     assert(type(path) == "string")
    --     assert(select('#', ...) > 0)
    --     local node = create_node("delete", path, ...)
    --     node_router:add_child(node)
    -- end

    function router.node()
        return node_router
    end
    return router
end


return create_router

