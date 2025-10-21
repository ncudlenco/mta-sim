Table = class(SampStoryObjectBase, function(o, params)
    params.description = "table"
    params.type = 'Table'

    SampStoryObjectBase.init(o, params)
end
)

Table.eModel = 
{
    GlassTable = 2086,
    WoodRoundTable = 2109,
    Unknown01 = 2117,
    Unknown02 = 2115
}