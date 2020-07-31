Table = class(SampStoryObjectBase, function(o, params)
    params.description = "table"
    SampStoryObjectBase.init(o, params)
end
)

Table.eModel = 
{
    GlassTable = 2086
}