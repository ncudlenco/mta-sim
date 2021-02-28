Toilet = class(SampStoryObjectBase, function(o, params)
    params.description = PickRandom({"toilet", "water closet", "toilet bowl"})
    params.type = 'Toilet'

    SampStoryObjectBase.init(o, params)
end
)

Toilet.eModel = 
{
    Unknown1 = 2528,
    Unknown2 = 2521,
    Unknown3 = 2525,
    Unknown5 = 2514
}