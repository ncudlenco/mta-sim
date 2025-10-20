Chair = class(SampStoryObjectBase, function(o, params)
    params.description = "chair"
    params.type = 'Chair'

    SampStoryObjectBase.init(o, params)
end
)

Chair.eModel = 
{
    BedroomChair = 2331,
    SolidWoodenChair = 1811,
    RedChair = 2121,
    WhiteChair = 2123
}