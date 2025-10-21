Wardrobe = class(SampStoryObjectBase, function(o, params)
    params.description = "wardrobe"
    params.type = 'Wardrobe'

    SampStoryObjectBase.init(o, params)
end
)

Wardrobe.eModel = 
{
    Unknown1 = 2088,
}