Televisor = class(SampStoryObjectBase, function(o, params)
    params.description = PickRandom({"televisor", "TV"})
    params.type = 'Televisor'
    SampStoryObjectBase.init(o, params)
end
)

Televisor.eModel = 
{
    unknown01 = 2224,
}