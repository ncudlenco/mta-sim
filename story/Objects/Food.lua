Food = class(SampStoryObjectBase, function(o, params)
    params.description = "food"
    params.posOffset = Vector3(0, 0, 0)
    SampStoryObjectBase.init(o, params)
    o:updateDescription()
    o:updatePositionOffset()
end
)

function Food:updateDescription()
    if self.modelid == Food.eModel.Shawarma then
        self.Description = "a shawarma"
    elseif self.modelid == Food.eModel.SmokedLeg then
        self.Description = "a smoked leg"
    elseif self.modelid == Food.eModel.MilkBottle then
        self.Description = "a milk bottle"
    end
    return self.Description
end

function Food:updatePositionOffset()
    if self.modelid == Food.eModel.Shawarma then
        self.PosOffset = Vector3(0.23, 0.5, 0)
    elseif self.modelid == Food.eModel.SmokedLeg then
        self.Description = "a smoked leg"
    elseif self.modelid == Food.eModel.MilkBottle then
        self.Description = "a milk bottle"
    end
    return self.Description
end

Food.eModel = 
{
    Shawarma = 2769,
    SmokedLeg = 19847,
    MilkBottle = 19570
}