GasCooker = class(SampStoryObjectBase, function(o, params)
    params.description = "gas cooker"
    params.type = 'GasCooker'

    SampStoryObjectBase.init(o, params)
end
)

GasCooker.eModel = 
{
    Unkwown01 = 2417
}