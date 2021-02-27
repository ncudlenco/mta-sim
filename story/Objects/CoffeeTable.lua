CoffeeTable = class(SampStoryObjectBase, function(o, params)
    params.description = "coffee table"
    params.type = 'CoffeeTable'

    SampStoryObjectBase.init(o, params)
end
)

CoffeeTable.eModel = 
{
    Unknown01 = 1822
}