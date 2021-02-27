Televisor = class(SampStoryObjectBase, function(o, params)
    params.description = "televisor"
    params.type = 'Televisor'
    SampStoryObjectBase.init(o, params)
end
)

Televisor.eModel = 
{
    unknown01 = 2224,
}