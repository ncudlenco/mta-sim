Plate = class(SampStoryObjectBase, function(o, params)
    params.description = "plate"
    SampStoryObjectBase.init(o, params)
end
)

Plate.eModel = 
{
    Unknown1 = 2812,
    Unknown2 = 2830
}