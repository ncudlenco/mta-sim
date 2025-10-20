Money = class(BaseNeed, function(o, value)
    params = {}
    params.name = "money"
    params.min = 1
    params.max = 99999999
    params.type = BaseNeed.Types.Psychological
    params.value = value
    BaseNeed.init(o, params)
end)

function Money:setForPlayer(player)
    player:setData(self.name, self.value)
    player.money = self.value
    if DEBUG then
        outputConsole(self.name..": "..self.value.."$")
    end
end

function Money:setRandomForPlayer(player)
    self.value = math.random(self.min, self.max)
    player:setData(self.name, self.value)
    player.money = self.value
    if DEBUG then
        outputConsole(self.name..": "..self.value.."$")
    end
end