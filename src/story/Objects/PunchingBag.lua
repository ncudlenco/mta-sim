PunchingBag = class(SampStoryObjectBase, function(o, params)
    params.description = "punching bag"
    params.type = 'PunchingBag'

    SampStoryObjectBase.init(o, params)
end
)

PunchingBag.eModel = {
    PunchingBag1 = 1985
}