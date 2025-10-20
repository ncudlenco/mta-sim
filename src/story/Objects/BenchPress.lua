BenchPress = class(SampStoryObjectBase, function(o, params)
    params.description = "bench press"
    params.type = 'BenchPress'

    SampStoryObjectBase.init(o, params)
end
)

BenchPress.eModel = {
    BenchPress1 = 2629
}