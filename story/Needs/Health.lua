Health = class(BaseNeed, function(o, value, max)
    params = {}
    params.name = "health"
    params.min = 1
    params.max = max or 100
    params.type = BaseNeed.Types.Physiological
    params.value = value or -1
    BaseNeed.init(o, params)
end)

function Health:setForPlayer(player)
    player:setData(self.name, self.value)
    player.health = self.value
    if DEBUG then
        outputConsole(self.name..": "..self.value.." / "..self.max)
    end
end

function Health:setRandomForPlayer(player)
    self.max = getPedMaxHealth(source)
    self.value = math.random(self.min, self.max)
    player:setData(self.name, self.value)
    player.health = self.value
    if DEBUG then
        outputConsole(self.name..": "..self.value.." / "..self.max)
    end
end