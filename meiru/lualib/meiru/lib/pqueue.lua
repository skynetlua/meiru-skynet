
----------------------------------------------
--优先队列
----------------------------------------------
-- local PQueue = class("PQueue")
-- function PQueue:ctor(compare)
--     self.map = {}
--     self.array = {}
-- 	self.compare = assert(compare)
-- end

-- function PQueue:count()
-- 	return #self.array
-- end

-- function PQueue:siftup(i, x)
--     local array, map = self.array,self.map
--     local compare = self.compare
-- 	local parent,e
--     while i > 0 do
--         parent = (i - 1) >> 1
--         e = array[parent+1]
--         if compare(x, e) >= 0 then
--             break
--         end
--         array[i+1], map[e] = e, i
--         i = parent
--     end
--     array[i+1], map[x] = x, i
-- end

-- function PQueue:offer(e) 
--     assert(e)
--     assert(not self.map[e])
--     local i = #self.array
--     if i == 0 then
--         self.array[i+1], self.map[e] = e, i
--     else
--         self:siftup(i, e)
--     end
-- end

-- function PQueue:peek()
--     if #self.array == 0 then
--         return
--     end
--     return self.array[0+1]
-- end

-- function PQueue:siftdown(i, x)
--     local size = #self.array
--     local half = size >> 1
--     local array, map = self.array,self.map
--     local compare = self.compare
--     local child, c, right
--     while i < half do
--         child = (i << 1) + 1
--         c = array[child+1]
--         right = child + 1
--         if right < size and compare(c, array[right+1]) > 0 then
--         	child = right
--             c = array[child+1]
--         end
--         if compare(x, c) <= 0 then
--             break
--         end
--         array[i+1], map[c] = c, i
--         i = child
--     end
--     array[i+1], map[x] = x, i
-- end

-- function PQueue:poll()
--     local s = #self.array
--     if s == 0 then
--         return
--     end
--     s = s-1
--    	local ret = self.array[0+1]
--     local x = self.array[s+1]
--     self.array[s+1] = nil
--     if s ~= 0 then
--         self:siftdown(0, x)
--     end
--     self.map[ret] = nil
--     return ret
-- end

-- function PQueue:remove(e)
--     assert(e)
--     local i = self.map[e]
--     if not i then
--     	return false
--     end
--     self.map[e] = nil
--     local s = #self.array-1
--     if s == i then
--         self.array[i+1] = nil
--     else
--         local moved = self.array[s+1]
--         self.array[s+1] = nil
--         self:siftdown(i, moved)
--     end
--     return true
-- end


local function PQueue(_compare)
    local map = {}
    local array = {}
    local compare = assert(_compare)

    local PQueue = {}
    function PQueue.count()
        return #array
    end

    function PQueue.siftup(i, x)
        local parent,e
        while i > 0 do
            parent = (i - 1) >> 1
            e = array[parent+1]
            if compare(x, e) >= 0 then
                break
            end
            array[i+1], map[e] = e, i
            i = parent
        end
        array[i+1], map[x] = x, i
    end

    function PQueue.offer(e) 
        assert(e)
        assert(not map[e])
        local i = #array
        if i == 0 then
            array[i+1], map[e] = e, i
        else
            PQueue.siftup(i, e)
        end
    end

    function PQueue.peek()
        if #array == 0 then
            return
        end
        return array[0+1]
    end

    function PQueue.siftdown(i, x)
        local size = #array
        local half = size >> 1
        local child, c, right
        while i < half do
            child = (i << 1) + 1
            c = array[child+1]
            right = child + 1
            if right < size and compare(c, array[right+1]) > 0 then
                child = right
                c = array[child+1]
            end
            if compare(x, c) <= 0 then
                break
            end
            array[i+1], map[c] = c, i
            i = child
        end
        array[i+1], map[x] = x, i
    end

    function PQueue.poll()
        local s = #array
        if s == 0 then
            return
        end
        s = s-1
        local ret = array[0+1]
        local x = array[s+1]
        array[s+1] = nil
        if s ~= 0 then
            PQueue.siftdown(0, x)
        end
        map[ret] = nil
        return ret
    end

    function PQueue.remove(e)
        assert(e)
        local i = map[e]
        if not i then
            return false
        end
        map[e] = nil
        local s = #array-1
        if s == i then
            array[i+1] = nil
        else
            local moved = array[s+1]
            array[s+1] = nil
            PQueue.siftdown(i, moved)
        end
        return true
    end
    return PQueue
end

return PQueue
