PREV_RANDOM_NUMBER = -1

--Busy waiting, not useful at all
function sleep(n, ...)  -- n: max seconds to wait; args[0]: wake up condition func
    local wakeUp = false
    for _,v in ipairs(arg) do
        wakeUp = v
        break
    end

    local t0 = os.clock()
    while not (wakeUp and wakeUp()) and os.clock() - t0 <= n do end
end

function findRotation(x1, y1, x2, y2)
    local t = -math.deg( math.atan2( x2 - x1, y2 - y1 ) )
    return t < 0 and t + 360 or t
end

function getPedMaxHealth(ped)
    -- Output an error and stop executing the function if the argument is not valid
    assert(isElement(ped) and (getElementType(ped) == "ped" or getElementType(ped) == "player"), "Bad argument @ 'getPedMaxHealth' [Expected ped/player at argument 1, got " .. tostring(ped) .. "]")

    -- Grab his player health stat.
    local stat = getPedStat(ped, 24)

    -- Do a linear interpolation to get how many health a ped can have.
    -- Assumes: 100 health = 569 stat, 200 health = 1000 stat.
    local maxhealth = 100 + (stat - 569) / 4.31

    -- Return the max health. Make sure it can't be below 1
    return math.max(1, maxhealth)
end

function getWordPrefix(word)
    if string.sub(word, 1, 1) == "a" or string.sub(word, 1, 1) == "e" or string.sub(word, 1, 1) == "i" or string.sub(word, 1, 1) == "o" or string.sub(word, 1, 1) == "u" then
        return "an"
    elseif word:sub(1, 4) == "two " or word:sub(1, 5) == "three " or word:sub(1, 5) == "four " then
        return ""
    else
        return "a"
    end
end

function random(a, b)
    local random_number = PREV_RANDOM_NUMBER

    while random_number == PREV_RANDOM_NUMBER do
        math.randomseed(os.clock()*100000000000)
        math.random(a, b); math.random(a, b); math.random(a, b);
        random_number = math.random(a, b)
    end

    PREV_RANDOM_NUMBER = random_number

    return  random_number
end

function num2word(number)
    if number == 1 then
        return "one"
    elseif number == 2 then
        return "two"
    elseif number == 3 then
        return "three"
    elseif number == 4 then
        return "four"
    elseif number == 5 then
        return "five"
    elseif number == 6 then
        return "six"
    elseif numbre == 7 then
        return "seven"
    elseif number == 8 then
        return "eight"
    else
        return nil
    end
end

function string.split(s, delimiter)
    result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return result;
end

--- Returns a string representation of a table.
---@param tbl any The table to stringify.
---@param indent any The indentation level.
---@return string s The string representation of the table.
function stringifyTable(tbl, indent)
    local function stringify(value, indent)
        local typ = type(value)
        if typ == "table" then
            return stringifyTable(value, indent)
        elseif typ == "string" then
            return '"' .. value .. '"'
        elseif typ == "boolean" then
            return value and "true" or "false"
        else
            return tostring(value)
        end
    end

    indent = indent or 0
    local toprint = string.rep(" ", indent) .. "{\n"
    indent = indent + 2

    for k, v in pairs(tbl) do
        toprint = toprint .. string.rep(" ", indent)
        if type(k) == "string" then
            toprint = toprint .. k .. " = " .. stringify(v, indent) .. ",\n"
        else
            toprint = toprint .. "[" .. tostring(k) .. "] = " .. stringify(v, indent) .. ",\n"
        end
    end

    return toprint .. string.rep(" ", indent - 2) .. "}"
end