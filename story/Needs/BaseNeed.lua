--min and max inclusive
BaseNeed = class(function(o, params)
    o.min = params.min
    o.max = params.max
    o.type = params.type
    o.value = params.value
    o.name = params.name
end)

BaseNeed.Types = {
    Physiological = 0,
    Psychological = 1
}

function BaseNeed:setForPlayer(player)
    player:setData(self.name, self.value)
    if DEBUG then
        outputConsole(self.name..": "..self.value.." / "..self.max)
    end
end

function BaseNeed:setRandomForPlayer(player)
    self.value = math.random(self.min, self.max)
    player:setData(self.name, self.value)
    if DEBUG then
        outputConsole(self.name..": "..self.value.." / "..self.max)
    end
end