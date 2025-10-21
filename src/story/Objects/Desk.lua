Desk = class(SampStoryObjectBase, function(o, params)
    params.description = "desk"
    params.type = 'Desk'
    SampStoryObjectBase.init(o, params)
end
)

Desk.eModel = 
{
    BedroomDesk = 2333,
    GlassTable = 2086
}