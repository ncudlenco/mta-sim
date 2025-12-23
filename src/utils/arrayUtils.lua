function FirstOrDefault(arr, func, getKvp)
    for k, a in pairs(arr) do --I don't care about the order, this will work on arrays and tables
        if not func or func(a) then
            if getKvp then
                return {key = k, value = a}
            else
                return a
            end
        end
    end
    return nil
end

function BoolToStr(bool)
    local str = 'false'
    if bool then
        str = 'true'
    end
    return str
end

function Select(arr, func)
    if not func then
        error('Select: func expected -> got nil')
    end
    local res = {}
    for k, a in pairs(arr) do --this will work on arrays and tables
        local val = func(a, k)
        table.insert(res, val)
    end
    return res
end

function ForEach(arr, func)
    if not func then
        error('[ForEach]: func expected -> got nil')
    end
    for k, a in pairs(arr) do --this will work on arrays and tables
        func(a, k)
    end
end

function UniqueStr(arr, func)
    local res = {}
    local set = {}
    for k, v in pairs(arr) do
        local val = v
        if func then
            val = func(v, k)
        end
        set[val] = true
    end
    for k, v in pairs(set) do
        table.insert(res, k)
    end
    return res
end

function Flatten(arr)
    local res = {}
    for _, arr2 in pairs(arr) do
        if isArray(arr2) then
            for _, item in pairs(arr2) do
                table.insert(res, item)
            end
        else
            table.insert(res, arr2)
        end
    end
    return res
end

--- Filter elements from an array or dictionary based on a predicate function.
--- For dictionaries (tables with non-numeric keys), preserves original keys.
--- For arrays (tables with numeric keys), re-indexes to contiguous [1, 2, 3...].
--- @param arr table The input array or dictionary
--- @param func function Predicate function that returns true for elements to keep
--- @return table Filtered array or dictionary
function Where(arr, func)
    local res = {}
    if arr == nil then return res end

    -- Check if input has any non-numeric keys (dictionary)
    local isDictionary = false
    for k, _ in pairs(arr) do
        if type(k) ~= "number" then
            isDictionary = true
            break
        end
    end

    if isDictionary then
        -- Dictionary: preserve original keys
        for k, v in pairs(arr) do
            if func(v) then
                res[k] = v
            end
        end
    else
        -- Array: re-index to contiguous [1, 2, 3...]
        for k, v in pairs(arr) do
            if func(v) then
                table.insert(res, v)
            end
        end
    end

    return res
end

--- Check if a table is empty (works for both arrays and dictionaries).
--- Uses next() which works correctly regardless of key type.
--- @param tbl table The table to check
--- @return boolean True if table is empty or nil
function IsEmpty(tbl)
    if tbl == nil then return true end
    return next(tbl) == nil
end

--- Count the number of entries in a table (works for both arrays and dictionaries).
--- For arrays, this is equivalent to #arr, but for dictionaries it counts all key-value pairs.
--- @param tbl table The table to count
--- @return number The number of entries in the table
function Count(tbl)
    if tbl == nil then return 0 end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

function DropNull(arr)
    return Where(arr, function(el) return el ~= nil end)
end

function LastIndexOf(arr, item, eqFunc)
    local idx = -1
    for i, a in ipairs(arr) do
        if eqFunc then
            if eqFunc(a, item) then
                idx = i
            end
        elseif a == item then
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

function Any(arr, func)
    if func == nil then
        return #arr > 0
    end
    for _, a in ipairs(arr) do
        if func(a) then
            return true
        end
    end
    return false
end

function PickRandom(arr)
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    if #arr == 0 then
        -- then this is a dictionary
        local keys = {}
        for key, _ in pairs(arr) do
            table.insert(keys, key)
        end

        if #keys == 0 then
            return  nil
        end

        return keys[math.random(#keys)]
    else
        return arr[math.random(#arr)]
    end
end

function Shuffle(arr)
    math.randomseed(os.clock()*100000000000)

	for i = #arr, 2, -1 do
		local j = math.random(i)
		arr[i], arr[j] = arr[j], arr[i]
    end

    return arr
end

function isArray(t)
    if type(t) ~= "table" then
        return false
    end

    local i = 0
    for _ in pairs(t) do
      i = i + 1
      if t[i] == nil then return false end
    end
    return true
end

function starts_with(str, start)
    return str:sub(1, #start) == start
end

function ends_with(str, ending)
    return ending == "" or str:sub(-#ending) == ending
end

function split_string (inputstr, sep)
    if sep == nil then
            sep = "%s"
    end
    local t={}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
            table.insert(t, str)
    end
    return t
end

function trim(s)
    return s:match'^%s*(.*%S)' or ''
 end

function reduce(arr, initial, op)
    local res = initial
    for i, value in ipairs(arr) do
        res = op(res, value)
    end
    return res
end

function getPlayer(id)
    FirstOrDefault(getElementsByType('ped'), function(spectator) return spectator:getData('id') == id end)
end

function reduceLeft(arr, default, op)
    local res = default
    if #arr > 0 then
        res = arr[1]
        for i, value in ipairs(arr) do
            if i > 1 then
                res = op(res, value)
            end
        end
    end
    return res
end

function inList(targetValue, arr)
    for i, value in ipairs(arr) do
        if targetValue == value then
            return true
        end
    end

    return false
end

function concat(arr1, arr2)
    local res = {}
    for i,v in ipairs(arr1) do
        table.insert(res, v)
    end
    for i,v in ipairs(arr2) do
        table.insert(res, v)
    end
    return res
end

function CopyContents(from, to)
    for k,v in pairs(from) do
        to[k] = v
    end
end

function notVeryDeepCopy(obj)
    if type(obj) ~= 'table' then return obj end
    local res = {}
    for k, v in pairs(obj) do res[notVeryDeepCopy(k)] = notVeryDeepCopy(v) end
    return res
end

function join(separator, arr)
    local str = ''
    for i,v in ipairs(arr) do
        if str ~= '' then
            str = str..separator
        end
        str = str..v
    end
    return str
end