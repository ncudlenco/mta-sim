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