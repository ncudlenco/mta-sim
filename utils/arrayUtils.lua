function Where(arr, func)
    local res = {}
    for _, a in ipairs(arr) do
        if func(a) then 
            table.insert(res, a)
        end
    end
    return res
end

function LastIndexOf(arr, item)
    local idx = -1
    for i, a in ipairs(arr) do
        if a == item then 
            idx = i
        end
    end
    return idx
end

function All(arr, func)
    for _, a in ipairs(arr) do
        if not func(a) then 
            return false
        end
    end
    return true
end

function PickRandom(arr)
    if #arr == 0 then
        -- then this is a dictionary
        local keys = {}
        for key, _ in pairs(arr) do
            table.insert(keys, key)
        end

        return keys[math.random(#keys)]
    else
        return arr[math.random(#arr)]
    end
end