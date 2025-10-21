function createGuid()
    -- math.randomseed(os.clock()*100000000000) everything stops working when I set a random seed ???????????????????????????????????????????????????????????????
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

Guid = class(function(a)
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()
    math.randomseed(os.clock()*100000000000)
    math.random(); math.random(); math.random()

    -- math.randomseed(os.clock()*100000000000)
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    a.Id = string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end)

function Guid:__tostring()
    return self.Id
end