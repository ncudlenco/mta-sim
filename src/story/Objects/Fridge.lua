Fridge = class(SampStoryObjectBase, function(o, params)
    params.description = "fridge"
    params.type = 'Fridge'

    SampStoryObjectBase.init(o, params)
end
)

Fridge.eModel = 
{
    Unkwown01 = 2529
}