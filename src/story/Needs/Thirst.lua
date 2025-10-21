Thirst = class(BaseNeed, function(o, value)
    params = {}
    params.name = "thirst"
    params.min = 1
    params.max = 100
    params.type = BaseNeed.Types.Physiological
    params.value = value or -1
    BaseNeed.init(o, params)
end)