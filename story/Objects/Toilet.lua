Toilet = class(SampStoryObjectBase, function(o, params)
    params.description = "toilet"
    params.type = 'Toilet'

    SampStoryObjectBase.init(o, params)
end
)

Toilet.eModel = 
{
    Unknown1 = 2528,
    Unknown2 = 2521,
    Unknown3 = 2525,
    Unknown4 = 2738,
    Unknown5 = 2514
}