TurnTable = class(SampStoryObjectBase, function(o, params)
    params.description = "turn table"
    params.pluralTemplate = "{count} turn tables"
    params.type = 'TurnTable'

    SampStoryObjectBase.init(o, params)
end
)

TurnTable.eModel = {
    Unknown01 = 2099
}