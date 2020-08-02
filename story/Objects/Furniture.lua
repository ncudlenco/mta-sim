Furniture = class(SampStoryObjectBase, function(o, params)
    params.description = "sofa"
    SampStoryObjectBase.init(o, params)
    o:updateDescription()
end
)

function Furniture:updateDescription()
    if self.modelid == Furniture.eModel.House3LivingRoom1 or self.modelid == Furniture.eModel.House1LivingRoom1 then
        self.Description = "sofa"
    elseif (self.modelid == Furniture.eModel.House3Kitchen1 or self.modelid == Furniture.eModel.House10Kitchen1) then
        self.Description = "sink"
    elseif self.modelid == Furniture.eModel.House3LivingRoom2 then
        self.Description = "chair"
    end
    return self.Description
end

Furniture.eModel = {
    House3LivingRoom1 = 14491,
    House3Kitchen1 = 14472,
    House10Kitchen1= 2136,
    House1LivingRoom1 = 14543,
    House1LivingRoom2 = 14535
}