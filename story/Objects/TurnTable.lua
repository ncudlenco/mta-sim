TurnTable = class(SampStoryObjectBase, function(o, params)
    params.description = "the turn table"
    SampStoryObjectBase.init(o, params)
end
)

TurnTable.eModel = {
    Unknown01 = 2099
}