Plate = class(SampStoryObjectBase, function(o, params)
    params.description = "plate"
    params.type = 'Plate'

    SampStoryObjectBase.init(o, params)
end
)

Plate.eModel = 
{
    Unknown1 = 2812,
    Unknown2 = 2830
}