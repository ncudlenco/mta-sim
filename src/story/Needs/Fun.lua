Fun = class(BaseNeed, function(o, value)
    params = {}
    params.name = "fun"
    params.min = 1
    params.max = 100
    params.type = BaseNeed.Types.Psychological
    params.value = value or -1
    BaseNeed.init(o, params)
end)