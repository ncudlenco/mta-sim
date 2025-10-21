FlowerPot = class(SampStoryObjectBase, function(o, params)
    params.description = "flower pot"
    params.type = 'FlowerPot'
    SampStoryObjectBase.init(o, params)
end
)

FlowerPot.eModel = 
{
    unknown03 = 2195,
    unknown04 = 949,
    unknown06 = 2240,
}