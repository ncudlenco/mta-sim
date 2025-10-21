Prestige = class(BaseNeed, function(o, value)
    params = {}
    params.name = "prestige"
    params.min = 1
    params.max = 100
    params.type = BaseNeed.Types.Psychological
    params.value = value or -1
    BaseNeed.init(o, params)
end)

function Prestige:setForPlayer(player)
    player:setData(self.name, self.value)
    --setting player respect
    setPedStat(player, 68, self.value)
    if DEBUG then
        outputConsole(self.name..": "..self.value.." / "..self.max)
    end
end

function Prestige:setRandomForPlayer(player)
    self.value = math.random(self.min, self.max)
    player:setData(self.name, self.value)
    --setting player respect
    setPedStat(player, 68, self.value)
    if DEBUG then
        outputConsole(self.name..": "..self.value.." / "..self.max)
    end
end