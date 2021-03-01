Furniture = class(SampStoryObjectBase, function(o, params)
    params.description = "sofa"
    params.type = 'Furniture'

    if params.modelid == Furniture.eModel.House3LivingRoom1 or params.modelid == Furniture.eModel.House1LivingRoom1 then
        params.description = "sofa"
    elseif (params.modelid == Furniture.eModel.House3Kitchen1 or params.modelid == Furniture.eModel.House10Kitchen1) then
        params.description = "sink"
    elseif params.modelid == Furniture.eModel.House3LivingRoom2 or params.modelid == Furniture.eModel.House1LivingRoom2 then
        params.description = "chair"
    end

    SampStoryObjectBase.init(o, params)
end
)

Furniture.eModel = {
    House3LivingRoom1 = 14491,
    House3Kitchen1 = 14472,
    House10Kitchen1= 2136,
    House1LivingRoom1 = 14543,
    House1LivingRoom2 = 14535
}