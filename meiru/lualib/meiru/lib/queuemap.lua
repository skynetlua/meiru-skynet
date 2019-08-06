-------------------------------------
--Queue
-------------------------------------
-- local Queue = class("Queue")

-- function Queue:ctor()
--     self.head_idx    = 1
--     self.empty_idx   = 1
--     self.cache_queue = {}
--     self.cache_map   = {}
-- end

-- function Queue:get(key)
--     return self.cache_map[key]
-- end
-- function Queue:set(key, data)
--     self.cache_map[key] = data

--     self.cache_queue[self.empty_idx] = key
--     self.empty_idx = self.empty_idx+1
--     while self.empty_idx-self.head_idx >= 1000 do
--         local tmp_key = self.cache_queue[self.head_idx]
--         self.cache_queue[self.head_idx] = nil
--         if tmp_key then
--             self.cache_map[tmp_key] = nil
--         end
--         self.head_idx = self.head_idx+1
--     end
-- end

-- function Queue:remove(key)
--     self.cache_map[key] = nil
-- end
-- function Queue:removes(keys)
--  for _,key in ipairs(keys) do
--      self.cache_map[key] = nil
--  end
-- end

local function QueueMap(max, map)
    max = max or 1000
    map = map or {}

    local head_idx  = 1
    local empty_idx = 1
    local queue = {}
    -- local map   = {}
    --------------------------------
    --exports
    --------------------------------
    local QueueMap = {}
    function QueueMap.get(key)
        return map[key]
    end
    function QueueMap.set(key, data)
        map[key] = data

        queue[empty_idx] = key
        empty_idx = empty_idx+1

        while empty_idx-head_idx > max do
            local remove_key = queue[head_idx]
            queue[head_idx] = nil
            head_idx = head_idx+1
            if remove_key then
                map[remove_key] = nil
            end
        end
    end
    function QueueMap.remove(key)
        map[key] = nil
    end
    function QueueMap.removes(keys)
        for _,key in ipairs(keys) do
            map[key] = nil
        end
    end
    return QueueMap
end

return QueueMap