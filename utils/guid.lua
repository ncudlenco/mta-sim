function createGuid()
    -- math.randomseed(os.time()) everything stops working when I set a random seed ???????????????????????????????????????????????????????????????
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end

Guid = class(function(a)
    math.randomseed(os.time())
    math.random(); math.random(); math.random()
    math.randomseed(os.time())
    math.random(); math.random(); math.random()

    -- math.randomseed(os.time())
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    a.Id = string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and math.random(0, 0xf) or math.random(8, 0xb)
        return string.format('%x', v)
    end)
end)

function Guid:__tostring()
    return self.Id
end