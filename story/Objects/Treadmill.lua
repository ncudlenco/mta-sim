TreadMill = class(SampStoryObjectBase, function(o, params)
    params.description = "treadmill"
    params.type = 'TreadMill'

    SampStoryObjectBase.init(o, params)
end
)

TreadMill.eModel = {
    TreadMill1 = 2627
}