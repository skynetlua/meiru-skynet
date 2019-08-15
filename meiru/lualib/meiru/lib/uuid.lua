

local function num_to_num36(num)
    local num36 = ""
    while num > 0 do
        local remainder = num%36
        if remainder>9 then
            num36 = string.char(remainder-10+97) .. num36
        else
            num36 = string.char(remainder+48) .. num36
        end
        num = math.floor(num/36)
    end
    return num36
end

local __suid = 1
math.randomseed(os.time())
local function generate_uuid()
    local id = num_to_num36(os.time()) 
                .. num_to_num36(math.random(100000000, 1000000000-1)) 
                .. num_to_num36(__suid)
    __suid = __suid+1
    return id
end

return generate_uuid
