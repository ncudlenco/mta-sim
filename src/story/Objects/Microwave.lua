Microwave = class(SampStoryObjectBase, function(o, params)
    params.description = "microwave"
    params.type = 'Microwave'

    SampStoryObjectBase.init(o, params)
end
)

Microwave.eModel = 
{
    Unkwown01 = 2149
}