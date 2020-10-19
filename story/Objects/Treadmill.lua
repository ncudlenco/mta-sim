Treadmill = class(SampStoryObjectBase, function(o, params)
    params.description = "treadmill"
    params.type = 'Treadmill'

    SampStoryObjectBase.init(o, params)
end
)

Treadmill.eModel = {
    Treadmill1 = 2627
}