Hunger = class(BaseNeed, function(o, value)
    params = {}
    params.name = "hunger"
    params.min = 1
    params.max = 100
    params.type = BaseNeed.Types.Physiological
    params.value = value or -1
    BaseNeed.init(o, params)
end)